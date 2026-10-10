<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\OrderStatus;
use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use App\Exceptions\DomainException;
use App\Models\Address;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\CommissionRate;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Vendor;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Commandes (M5 — J82 à J85).
 *
 * Les montants (sous-total, livraison, commission interne, total) sont
 * recalculés côté serveur : le client n'envoie que les identifiants. Toutes
 * les informations clients sont figées en snapshot (J84).
 */
class OrderService
{
    public function __construct(
        private readonly CartService $cartService,
        private readonly DeliveryPricingService $delivery,
        private readonly CatalogService $catalog,
        private readonly RefundService $refunds,
        private readonly NotificationService $notifications,
        private readonly FinanceService $finance,
        private readonly CashService $cash,
    ) {}

    // ------------------------------------------------------------------ J82
    /**
     * Résumé calculé serveur pour un panier : sous-total, livraison, commission et total.
     *
     * @param  array{address?: Address, addressData?: array<string, mixed>}  $options
     * @return array<string, mixed>
     */
    public function summary(Cart $cart, array $options = []): array
    {
        $this->assertCartOpen($cart);

        $cart->loadMissing('items.product', 'vendor');

        $this->assertVendorSellable($cart->vendor);
        $this->assertItemsOrderable($cart->items);

        $paymentMethod = $this->normalizePaymentMethod($options['payment_method'] ?? 'online');

        $entries = [];
        $subtotal = 0;

        foreach ($cart->items as $item) {
            $unitPrice = (int) $item->product->price;
            $lineSubtotal = $unitPrice * $item->quantity;
            $subtotal += $lineSubtotal;
            $entries[] = [
                'product_id' => $item->product->id,
                'name' => $item->product->name,
                'quantity' => $item->quantity,
                'unit_price' => $unitPrice,
                'subtotal' => $lineSubtotal,
            ];
        }

        $delivery = $this->deliveryQuote($cart, $options);

        $commissionRate = $this->resolveCommissionRate($cart->vendor);
        $breakdown = $this->finance->breakdown($subtotal, (int) $delivery['fee'], $commissionRate);

        return [
            'vendor' => [
                'id' => $cart->vendor->id,
                'business_name' => $cart->vendor->business_name,
            ],
            'items' => $entries,
            'subtotal' => $subtotal,
            'delivery_fee' => $breakdown['delivery_fee'],
            'delivery_zone' => [
                'id' => $delivery['zone_id'],
                'name' => $delivery['rate_snapshot']['zone_name'] ?? null,
                'city' => $delivery['rate_snapshot']['zone_city'] ?? null,
            ],
            'currency' => config('beninfood.currency', 'XOF'),
            'payment_method' => $paymentMethod->value,
            'commission' => [
                'rate' => $commissionRate,
                'amount' => $breakdown['commission_amount'],
                'internal' => true,
            ],
            // Cahier v1.0 : frais de service client (5 %) et part livreur.
            'service_fee' => $breakdown['service_fee'],
            'delivery_commission' => $breakdown['delivery_commission_amount'],
            'total' => $breakdown['total_client'],
        ];
    }

    // ------------------------------------------------------------------ J83/J84
    /**
     * Crée la commande à partir du panier, dans une transaction.
     *
     * @throws DomainException order.*  si une contrainte n'est pas satisfaite
     */
    public function createFromCart(Cart $cart, Address $address, ?string $notes = null, string $paymentMethod = 'online'): Order
    {
        $this->assertCartOpen($cart);

        $cart->loadMissing(['items.product', 'vendor']);

        $vendor = $cart->vendor;

        $this->assertVendorSellable($vendor);
        $this->assertItemsOrderable($cart->items);
        $this->assertItemsStocked($cart->items);

        $delivery = $this->deliveryQuote($cart, ['address' => $address]);
        $paymentMethod = $this->normalizePaymentMethod($paymentMethod);

        $subtotal = 0;
        $lines = [];

        foreach ($cart->items as $item) {
            $unitPrice = (int) $item->product->price;
            $lineSubtotal = $unitPrice * $item->quantity;
            $subtotal += $lineSubtotal;
            $lines[] = [
                'product' => $item->product,
                'quantity' => $item->quantity,
                'unit_price' => $unitPrice,
                'subtotal' => $lineSubtotal,
                'name' => $item->product->name,
            ];
        }

        $commissionRate = $this->resolveCommissionRate($vendor);
        $breakdown = $this->finance->breakdown($subtotal, (int) $delivery['fee'], $commissionRate);
        $deliveryFee = $breakdown['delivery_fee'];
        $total = $breakdown['total_client'];

        $reference = $this->generateReference();

        $paymentDeadline = $paymentMethod->isCash() ? null : now()->addMinutes((int) config('beninfood.orders.payment_deadline_minutes', 15));

        return DB::transaction(function () use ($cart, $address, $notes, $delivery, $lines, $subtotal, $commissionRate, $breakdown, $deliveryFee, $total, $reference, $paymentMethod, $paymentDeadline) {
            $order = Order::create([
                'reference' => $reference,
                'user_id' => $cart->user_id,
                'vendor_id' => $cart->vendor_id,
                'cart_id' => $cart->id,
                'zone_id' => $delivery['zone_id'],
                'status' => OrderStatus::AwaitingPayment->value,
                'payment_method' => $paymentMethod->isCash()
                    ? PaymentMethod::Cash->value
                    : PaymentMethod::Online->value,
                'payment_status' => PaymentStatus::Initiated->value,
                'subtotal' => $subtotal,
                'discount' => 0,
                'delivery_fee' => $deliveryFee,
                'total' => $total,
                'address_snapshot' => $this->snapshotAddress($address, $notes),
                'delivery_rate_snapshot' => $delivery['rate_snapshot'],
                'notes' => $notes,
                'payment_deadline_at' => $paymentDeadline,
            ]);

            foreach ($lines as $line) {
                $order->items()->create([
                    'product_id' => $line['product']->id,
                    'name_snapshot' => $line['name'],
                    'unit_price_snapshot' => $line['unit_price'],
                    'quantity' => $line['quantity'],
                    'subtotal' => $line['subtotal'],
                    'variant_label' => null,
                ]);

                $this->catalog->adjustStock($line['product'], -$line['quantity'], 'order', 'order', $order->id);
            }

            $this->logTransition($order, null, OrderStatus::AwaitingPayment, 'system', null, null);

            $order->financials()->create([
                'subtotal' => $subtotal,
                'discount' => 0,
                'delivery_fee' => $deliveryFee,
                'service_fee' => $breakdown['service_fee'],
                'payment_fee' => $breakdown['payment_fee'],
                'commission_base' => $breakdown['commission_base'],
                'commission_rate' => $commissionRate,
                'commission_amount' => $breakdown['commission_amount'],
                'vendor_amount' => $breakdown['vendor_amount'],
                'delivery_commission_rate' => $breakdown['delivery_commission_rate'],
                'delivery_commission_amount' => $breakdown['delivery_commission_amount'],
                'delivery_partner_amount' => $breakdown['delivery_partner_amount'],
                'platform_amount' => $breakdown['platform_amount'],
                'total_client' => $breakdown['total_client'],
            ]);

            if (! $paymentMethod->isCash()) {
                $order->payment()->create([
                    'reference' => 'PAY-'.Str::upper(Str::random(12)),
                    'gateway' => 'kkiapay',
                    'amount' => $total,
                    'status' => PaymentStatus::Initiated->value,
                    'expires_at' => $order->payment_deadline_at,
                ]);
            }

            $this->cartService->markConverted($cart);

            return $order->fresh([
                'items',
                'financials',
                'payment',
                'vendor',
                'statusHistory',
            ]);
        });
    }

    // ------------------------------------------------------------------ J85
    /** Le vendeur valide la commande (awaiting_payment/paid → accepted). */
    public function acceptVendorOrder(Order $order, ?string $actorId = null): Order
    {
        $this->assertTransition($order, OrderStatus::Accepted);

        $from = $order->status;

        $order->update([
            'status' => OrderStatus::Accepted->value,
            'accepted_at' => now(),
            'vendor_acceptance_deadline_at' => null,
        ]);

        $this->logTransition($order, $from, OrderStatus::Accepted, 'vendor', $actorId, null);

        $this->notifications->notifyEvent('order.accepted', [$order->user], [
            'reference' => $order->reference,
            'order_id' => $order->id,
            'image_url' => $this->firstItemImageUrl($order),
        ]);

        return $order->fresh('statusHistory');
    }

    /** Le vendeur refuse la commande (awaiting_payment/paid → cancelled, motif obligatoire). */
    public function refuseVendorOrder(Order $order, ?string $actorId = null, ?string $reason = null): Order
    {
        $this->assertVendorRefusable($order);
        $reason = $this->requireCancellationReason($reason);
        $statusBefore = $order->status;

        $this->markCancelled($order, $actorId, $reason, 'vendor');

        $this->restoreStock($order);

        $this->refunds->handleOrderCancellation($order, 'vendor', $actorId, $reason, $statusBefore);

        return $order->fresh('statusHistory');
    }

    /** Le client annule sa commande (motif obligatoire). */
    public function cancelClientOrder(Order $order, ?string $actorId = null, ?string $reason = null): Order
    {
        $this->assertCancellationAllowed($order, 'client');
        $reason = $this->requireCancellationReason($reason, 'Annulation par le client.');
        $statusBefore = $order->status;

        $this->markCancelled($order, $actorId, $reason, 'client');

        $this->restoreStock($order);

        $this->refunds->handleOrderCancellation($order, 'client', $actorId, $reason, $statusBefore);

        return $order->fresh('statusHistory');
    }

    /** Le vendeur annule une commande acceptée ou en préparation (motif obligatoire). */
    public function cancelVendorOrder(Order $order, ?string $actorId = null, ?string $reason = null): Order
    {
        $this->assertCancellationAllowed($order, 'vendor');
        $reason = $this->requireCancellationReason($reason, 'Annulation par le vendeur.');
        $statusBefore = $order->status;

        $this->markCancelled($order, $actorId, $reason, 'vendor');

        $this->restoreStock($order);

        $this->refunds->handleOrderCancellation($order, 'vendor', $actorId, $reason, $statusBefore);

        return $order->fresh('statusHistory');
    }

    /** La porteuse annule une commande (tous statuts, motif obligatoire, remboursement décidé). */
    public function cancelByPorteuse(Order $order, ?string $actorId = null, ?string $reason = null, ?int $refundOverride = null): Order
    {
        $this->assertCancellationAllowed($order, 'porteuse');
        $reason = $this->requireCancellationReason($reason, 'Annulation par la porteuse.');
        $statusBefore = $order->status;

        $this->markCancelled($order, $actorId, $reason, 'porteuse');

        $this->restoreStock($order);

        $this->refunds->handleOrderCancellation($order, 'porteuse', $actorId, $reason, $statusBefore, $refundOverride);

        return $order->fresh('statusHistory');
    }

    /** Confirme le paiement et transitionne la commande (awaiting_payment → paid). */
    public function confirmPayment(Order $order, int $amount): Order
    {
        if (! $order->isAwaitingPayment()) {
            throw new DomainException('order.payment_not_expected', 'Cette commande n\'attend pas de paiement.', 422);
        }

        $order->update([
            'payment_status' => PaymentStatus::Confirmed->value,
            'status' => OrderStatus::Paid->value,
            'vendor_acceptance_deadline_at' => now()->addMinutes((int) config('beninfood.orders.vendor_acceptance_minutes', 5)),
        ]);

        $this->logTransition($order, OrderStatus::AwaitingPayment, OrderStatus::Paid, 'system', null, 'Paiement confirmé');

        // Cahier v1.0 : répartition interne — part vendeur créditée en attente.
        $this->finance->distributeOrderPayment($order);

        $this->notifications->notifyEvent('order.paid', [$order->vendor?->user], [
            'reference' => $order->reference,
            'order_id' => $order->id,
            'items_count' => (int) $order->items()->count(),
            'image_url' => $this->firstItemImageUrl($order),
            'total' => $order->total,
        ]);

        return $order->fresh(['payment', 'statusHistory']);
    }

    // ------------------------------------------------------------------ J97-J106
    /** Le vendeur passe la commande en préparation (accepted → preparing). */
    public function markPreparing(Order $order, ?string $actorId = null): Order
    {
        $this->assertTransition($order, OrderStatus::Preparing);

        $from = $order->status;

        $order->update(['status' => OrderStatus::Preparing->value]);

        $this->logTransition($order, $from, OrderStatus::Preparing, 'vendor', $actorId, null);

        return $order->fresh('statusHistory');
    }

    /** Le vendeur signale la commande prête (preparing → ready) et ouvre une course. */
    public function markReady(Order $order, ?string $actorId = null): Order
    {
        $this->assertTransition($order, OrderStatus::Ready);

        $from = $order->status;

        DB::transaction(function () use ($order, $from, $actorId): void {
            $order->update(['status' => OrderStatus::Ready->value]);

            $this->logTransition($order, $from, OrderStatus::Ready, 'vendor', $actorId, null);

            if ($order->delivery()->doesntExist()) {
                $order->delivery()->create([
                    'driver_profile_id' => null,
                    'vendor_id' => $order->vendor_id,
                    'zone_id' => $order->zone_id,
                    'status' => DeliveryStatus::Assigned->value,
                    'fee' => $order->delivery_fee,
                    'partner_amount' => 0,
                    'assigned_at' => now(),
                ]);
            }
        });

        return $order->fresh(['statusHistory', 'delivery']);
    }

    /** Un livreur accepte la course (ready → assigned). */
    public function assignDriver(Order $order, string $driverProfileId, ?string $actorId = null): Order
    {
        $this->assertTransition($order, OrderStatus::Assigned);

        $from = $order->status;

        // Cahier v1.0 (cash) : le livreur doit avoir un flottant suffisant pour
        // garantir l'encaissement avant de se voir proposer/accepter la course.
        $driver = DriverProfile::find($driverProfileId);

        if ($order->payment_method?->isCash() && ($driver === null || ! $this->cash->hasCoverage($driver, $order->fresh()))) {
            throw new DomainException(
                'cash.insufficient_float',
                'Flottant insuffisant pour accepter cette commande payée en espèces ('.(int) $order->total.' F requis).',
                409,
            );
        }

        $order->update(['status' => OrderStatus::Assigned->value]);

        if ($order->delivery->exists()) {
            $order->delivery->update([
                'driver_profile_id' => $driverProfileId,
                'status' => DeliveryStatus::Assigned->value,
                'assigned_at' => now(),
            ]);
        }

        $this->logTransition($order, $from, OrderStatus::Assigned, 'driver', $actorId, null);

        // Le livreur n'est connu qu'à l'assignation : on crédite sa part en attente.
        if ($driver !== null) {
            $this->finance->creditDriverForDelivery($order, $driver);
        }

        return $order->fresh(['statusHistory', 'delivery']);
    }

    /** Le livreur récupère le colis (assigned → picked_up). */
    public function markPickedUp(Order $order, ?string $actorId = null): Order
    {
        $this->assertTransition($order, OrderStatus::PickedUp);

        $from = $order->status;

        $order->update(['status' => OrderStatus::PickedUp->value]);

        if ($order->delivery->exists()) {
            $order->delivery->update([
                'status' => DeliveryStatus::PickedUp->value,
                'picked_up_at' => now(),
            ]);
        }

        $this->logTransition($order, $from, OrderStatus::PickedUp, 'driver', $actorId, null);

        return $order->fresh(['statusHistory', 'delivery']);
    }

    /** Le livreur démarre la course vers le client (picked_up → in_delivery). */
    public function markInDelivery(Order $order, ?string $actorId = null): Order
    {
        $this->assertTransition($order, OrderStatus::InDelivery);

        $from = $order->status;

        $order->update(['status' => OrderStatus::InDelivery->value]);

        if ($order->delivery->exists()) {
            $order->delivery->update(['status' => DeliveryStatus::InDelivery->value]);
        }

        $this->logTransition($order, $from, OrderStatus::InDelivery, 'driver', $actorId, null);

        return $order->fresh(['statusHistory', 'delivery']);
    }

    /** Le livreur confirme la livraison (in_delivery → delivered). */
    public function markDelivered(Order $order, ?string $actorId = null): Order
    {
        $this->assertTransition($order, OrderStatus::Delivered);

        $from = $order->status;

        $order->update([
            'status' => OrderStatus::Delivered->value,
            'delivered_at' => now(),
            'auto_confirm_at' => now()->addMinutes((int) config('beninfood.orders.delivery_auto_confirm_minutes', 30)),
        ]);

        if ($order->delivery->exists()) {
            $order->delivery->update([
                'status' => DeliveryStatus::Delivered->value,
                'delivered_at' => now(),
            ]);
        }

        $this->logTransition($order, $from, OrderStatus::Delivered, 'driver', $actorId, null);

        // Cahier v1.0 : le séquestre est libéré à la confirmation du client
        // (ou automatiquement après le délai) — cf. confirmDelivery().
        // Commande cash : le livreur encaisse sur place, le règlement est
        // immédiat (flottant débité, parts vendeur/livreur payées).
        if ($order->payment_method?->isCash() && $order->delivery?->driverProfile) {
            $this->cash->settle($order->fresh('financials'), $order->delivery->driverProfile);
        }

        $this->notifications->notifyEvent('order.delivered', [$order->user], [
            'reference' => $order->reference,
            'order_id' => $order->id,
            'image_url' => $this->firstItemImageUrl($order),
        ]);

        return $order->fresh(['statusHistory', 'delivery']);
    }

    /**
     * Confirme la réception par le client (ou automatiquement) : libère les
     * séquestres vendeur et livreur. Idempotent.
     */
    public function confirmDelivery(Order $order, string $actorType = 'client', ?string $actorId = null): Order
    {
        if ($order->status !== OrderStatus::Delivered) {
            throw new DomainException('order.not_delivered', 'Cette commande n\'est pas livrée.', 422);
        }

        if ($order->delivery_confirmed_at !== null) {
            return $order->fresh(['statusHistory', 'delivery']);
        }

        if ($order->disputed_at !== null) {
            throw new DomainException('order.disputed', 'Un litige est en cours sur cette commande.', 409);
        }

        $order->update([
            'delivery_confirmed_at' => now(),
            'auto_confirm_at' => null,
        ]);

        $this->logTransition($order, OrderStatus::Delivered, OrderStatus::Delivered, $actorType, $actorId, 'Réception confirmée');

        $this->finance->releaseOrderFunds($order);

        return $order->fresh(['statusHistory', 'delivery']);
    }

    /**
     * Ouvre un litige : bloque la libération des soldes jusqu'à décision.
     */
    public function openDispute(Order $order, string $actorType, ?string $actorId, string $reason): Order
    {
        if (! in_array($order->status, [OrderStatus::InDelivery, OrderStatus::Delivered], true)) {
            throw new DomainException('order.cannot_dispute', 'Un litige ne peut être ouvert que sur une commande en livraison ou livrée.', 409);
        }

        if ($order->disputed_at !== null) {
            throw new DomainException('order.already_disputed', 'Un litige est déjà ouvert sur cette commande.', 409);
        }

        $from = $order->status;

        $order->update([
            'status' => OrderStatus::Disputed->value,
            'disputed_at' => now(),
            'dispute_reason' => $reason,
            'auto_confirm_at' => null,
        ]);

        $this->logTransition($order, $from, OrderStatus::Disputed, $actorType, $actorId, $reason);

        return $order->fresh(['statusHistory', 'delivery']);
    }

    /**
     * Décision du back-office sur un litige : libération (« release ») ou
     * remboursement (« refund »).
     */
    public function resolveDispute(Order $order, string $resolution, ?string $actorId = null, ?int $refundAmount = null): Order
    {
        if ($order->status !== OrderStatus::Disputed) {
            throw new DomainException('order.not_disputed', 'Cette commande n\'est pas en litige.', 422);
        }

        if (! in_array($resolution, ['release', 'refund'], true)) {
            throw new DomainException('order.invalid_resolution', 'Décision de litige inconnue.', 422);
        }

        if ($resolution === 'release') {
            $order->update([
                'status' => OrderStatus::Delivered->value,
                'disputed_at' => null,
                'dispute_reason' => null,
                'dispute_resolution' => 'release',
                'delivery_confirmed_at' => now(),
            ]);

            $this->logTransition($order, OrderStatus::Disputed, OrderStatus::Delivered, 'porteuse', $actorId, 'Litige résolu : fonds libérés');

            $this->finance->releaseOrderFunds($order);

            return $order->fresh(['statusHistory', 'delivery']);
        }

        // Remboursement intégral ou partiel : contre-passe les séquestres.
        $statusBefore = OrderStatus::Delivered;

        $order->update(['dispute_resolution' => 'refund']);

        $this->finance->reverseOrderDistribution($order, $actorId);

        $order->update([
            'status' => OrderStatus::Cancelled->value,
            'cancelled_at' => now(),
            'cancelled_by' => $actorId,
            'cancellation_reason' => 'Litige résolu : remboursement',
        ]);

        $this->logTransition($order, OrderStatus::Disputed, OrderStatus::Cancelled, 'porteuse', $actorId, 'Litige résolu : remboursement');

        $this->refunds->handleOrderCancellation($order, 'porteuse', $actorId, 'Litige résolu : remboursement', $statusBefore, $refundAmount);

        return $order->fresh(['statusHistory', 'delivery', 'refunds']);
    }

    /**
     * Auto-confirme les livraisons non confirmées dont le délai est écoulé.
     *
     * @return int Nombre de commandes confirmées
     */
    public function autoConfirmDeliveries(): int
    {
        $orders = Order::query()
            ->where('status', OrderStatus::Delivered->value)
            ->whereNull('delivery_confirmed_at')
            ->whereNull('disputed_at')
            ->whereNotNull('auto_confirm_at')
            ->where('auto_confirm_at', '<=', now())
            ->get();

        foreach ($orders as $order) {
            $this->confirmDelivery($order, 'system');
        }

        return $orders->count();
    }

    /**
     * Expire les commandes non payées au-delà de leur délai.
     *
     * @return int Nombre de commandes expirées
     */
    public function expireUnpaidOrders(): int
    {
        $orders = Order::query()
            ->where('status', OrderStatus::AwaitingPayment->value)
            ->where('payment_deadline_at', '<', now())
            ->get();

        foreach ($orders as $order) {
            $this->assertCancellationAllowed($order, 'system');

            $order->update([
                'status' => OrderStatus::Cancelled->value,
                'payment_status' => PaymentStatus::Expired->value,
                'cancelled_at' => now(),
                'cancellation_reason' => 'Paiement non reçu avant la date limite.',
            ]);

            $this->logTransition($order, OrderStatus::AwaitingPayment, OrderStatus::Cancelled, 'system', null, 'paiement expiré');

            if ($order->payment()->exists()) {
                $order->payment->update(['status' => PaymentStatus::Expired->value]);
            }

            $this->restoreStock($order);
        }

        return $orders->count();
    }

    // -----------------------------------------------------------------------
    /**
     * Récupère le taux de commission applicable (surcharge vendeur, taux actif, défaut).
     */
    public function resolveCommissionRate(Vendor $vendor): int
    {
        if (($exceptionRate = $vendor->settings?->commission_exception_rate) !== null) {
            return (int) $exceptionRate;
        }

        $rate = CommissionRate::query()
            ->where('is_active', true)
            ->where(fn ($q) => $q->whereNull('effective_to')->orWhere('effective_to', '>=', now()))
            ->orderByDesc('effective_from')
            ->first();

        return $rate !== null ? (int) $rate->rate : (int) config('beninfood.commission.default_rate', 10);
    }

    // -----------------------------------------------------------------------
    /**
     * @param  array{address?: Address, addressData?: array<string, mixed>}  $options
     * @return array{fee: int, zone_id: string|null, rate_snapshot: array<string, mixed>}
     */
    private function deliveryQuote(Cart $cart, array $options): array
    {
        $addressData = $this->extractAddressData($options);

        try {
            $quote = $this->delivery->quoteForVendor($cart->vendor, $addressData);

            return [
                'fee' => $quote['delivery_fee'],
                'zone_id' => $quote['zone']->id,
                'rate_snapshot' => $this->delivery->snapshotForOrder($quote),
            ];
        } catch (DomainException $e) {
            throw new DomainException('order.'.$e->errorCode, $e->getMessage(), $e->status);
        }
    }

    /**
     * @param  array{address?: Address, addressData?: array<string, mixed>}  $options
     * @return array{city: ?string, area: ?string, address_text: ?string, latitude: float|string|null, longitude: float|string|null}
     */
    private function extractAddressData(array $options): array
    {
        if (isset($options['address']) && $options['address'] instanceof Address) {
            return $options['address']->toHierarchy();
        }

        $data = $options['addressData'] ?? [];

        return [
            'city' => $data['city'] ?? null,
            'area' => $data['area'] ?? null,
            'address_text' => $data['address_text'] ?? null,
            'latitude' => $data['latitude'] ?? null,
            'longitude' => $data['longitude'] ?? null,
        ];
    }

    /**
     * Normalise le mode de paiement (online | cash) — cahier v1.0.
     */
    private function normalizePaymentMethod(string $value): PaymentMethod
    {
        return PaymentMethod::tryFrom($value) ?? PaymentMethod::Online;
    }

    /**
     * @return array<string, mixed>
     */
    private function snapshotAddress(Address $address, ?string $notes): array
    {
        return [
            'label' => $address->label,
            'full_address' => $address->full_address,
            'landmark' => $address->landmark,
            'city' => $address->city,
            'area' => $address->area,
            'latitude' => $address->latitude,
            'longitude' => $address->longitude,
            'zone_id' => $address->zone_id,
            'notes' => $notes,
        ];
    }

    private function assertCartOpen(Cart $cart): void
    {
        if (! $cart->isOpen()) {
            throw new DomainException('order.cart_closed', 'Le panier est fermé ou expiré.', 422);
        }
    }

    private function assertVendorSellable(Vendor $vendor): void
    {
        if (! $vendor->isOpenNow()) {
            throw new DomainException('order.vendor_closed', 'Cette boutique est actuellement fermée.', 422);
        }
    }

    /**
     * @param  Collection<int, CartItem>  $items
     */
    private function assertItemsOrderable($items): void
    {
        foreach ($items as $item) {
            if (! $item->product->isOrderable()) {
                throw new DomainException('order.product_unavailable', 'Un article du panier n\'est plus disponible ('.$item->product->name.').', 422);
            }
        }
    }

    /**
     * @param  Collection<int, CartItem>  $items
     */
    private function assertItemsStocked($items): void
    {
        foreach ($items as $item) {
            if ($item->product->stock_qty !== null && $item->product->stock_qty < $item->quantity) {
                throw new DomainException('order.insufficient_stock', 'Stock insuffisant pour '.$item->product->name.'.', 422);
            }
        }
    }

    /** Matrice des annulations par acteur et par statut (J12 §3). */
    private const CANCELLATION_MATRIX = [
        'client' => ['draft', 'awaiting_payment', 'paid', 'accepted', 'preparing', 'ready', 'assigned'],
        'vendor' => ['paid', 'accepted', 'preparing', 'ready'],
        'porteuse' => ['draft', 'awaiting_payment', 'paid', 'accepted', 'preparing', 'ready', 'assigned', 'picked_up', 'in_delivery', 'delivered'],
        'system' => ['awaiting_payment'],
    ];

    private function assertCancellationAllowed(Order $order, string $actorType): void
    {
        $allowed = self::CANCELLATION_MATRIX[$actorType] ?? [];

        if (! in_array($order->status->value, $allowed, true)) {
            throw new DomainException('order.cannot_cancel', 'Cette commande ne peut pas être annulée à ce stade.', 409);
        }
    }

    private function requireCancellationReason(?string $reason): string
    {
        $reason = trim((string) $reason);

        if ($reason === '') {
            throw new DomainException('order.reason_required', 'Le motif de l\'annulation est obligatoire.', 422);
        }

        return $reason;
    }

    private function markCancelled(Order $order, ?string $actorId, ?string $reason, string $actorType): void
    {
        $from = $order->status;

        $order->update([
            'status' => OrderStatus::Cancelled->value,
            'cancelled_at' => now(),
            'cancelled_by' => $actorId,
            'cancellation_reason' => $reason,
        ]);

        $this->logTransition($order, $from, OrderStatus::Cancelled, $actorType, $actorId, $reason);

        // Contre-passe les séquestres non encore libérés (commande payée annulée).
        $this->finance->reverseOrderDistribution($order, $actorId);

        if ($order->payment()->exists() && in_array($order->payment->status, [PaymentStatus::Initiated, PaymentStatus::Pending], true)) {
            $order->payment->update(['status' => PaymentStatus::Cancelled->value]);
        }
    }

    private function assertVendorRefusable(Order $order): void
    {
        if (! in_array($order->status->value, [OrderStatus::AwaitingPayment->value, OrderStatus::Paid->value], true)) {
            throw new DomainException('order.cannot_cancel', 'Cette commande ne peut pas être annulée à ce stade.', 409);
        }
    }

    private function assertTransition(Order $order, OrderStatus $target): void
    {
        $allowed = [
            OrderStatus::AwaitingPayment->value => [OrderStatus::Accepted->value, OrderStatus::Cancelled->value],
            OrderStatus::Paid->value => [OrderStatus::Accepted->value, OrderStatus::Cancelled->value],
            OrderStatus::Accepted->value => [OrderStatus::Preparing->value, OrderStatus::Cancelled->value],
            OrderStatus::Preparing->value => [OrderStatus::Ready->value, OrderStatus::Cancelled->value],
            OrderStatus::Ready->value => [OrderStatus::Assigned->value, OrderStatus::Cancelled->value],
            OrderStatus::Assigned->value => [OrderStatus::PickedUp->value, OrderStatus::Cancelled->value],
            OrderStatus::PickedUp->value => [OrderStatus::InDelivery->value, OrderStatus::Cancelled->value],
            OrderStatus::InDelivery->value => [OrderStatus::Delivered->value, OrderStatus::Cancelled->value],
            OrderStatus::Delivered->value => [OrderStatus::Refunded->value],
        ];

        $from = $order->status->value;

        if (! in_array($target->value, $allowed[$from] ?? [], true)) {
            throw new DomainException('order.invalid_transition', 'Transition de statut non autorisée ('.$from.' → '.$target->value.').', 409);
        }
    }

    private function logTransition(Order $order, ?OrderStatus $from, OrderStatus $to, ?string $actorType, ?string $actorId, ?string $reason): void
    {
        $order->statusHistory()->create([
            'from_status' => $from?->value,
            'to_status' => $to->value,
            'actor_type' => $actorType,
            'actor_id' => $actorId,
            'reason' => $reason,
            'created_at' => now(),
        ]);
    }

    /** Photo du premier article de la commande (aperçu notification). */
    private function firstItemImageUrl(Order $order): ?string
    {
        $item = $order->items()->with('product')->first();

        $path = $item?->product?->image_main;

        if ($path === null || $path === '') {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        return Storage::disk('public')->url($path);
    }

    /** Restaure le stock des articles déduits lors de la création. */
    private function restoreStock(Order $order): void
    {
        foreach ($order->items as $item) {
            if ($item->product_id !== null) {
                $this->catalog->adjustStock($item->product, $item->quantity, 'order_cancelled', 'order', $order->id);
            }
        }
    }

    private function generateReference(): string
    {
        do {
            $reference = 'BEN-'.now()->format('ymd').'-'.Str::upper(Str::random(6));
        } while (Order::where('reference', $reference)->exists());

        return $reference;
    }
}
