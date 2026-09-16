<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Exceptions\DomainException;
use App\Models\Address;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\CommissionRate;
use App\Models\Order;
use App\Models\Vendor;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
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
        $commission = (int) round($subtotal * $commissionRate / 100);

        return [
            'vendor' => [
                'id' => $cart->vendor->id,
                'business_name' => $cart->vendor->business_name,
            ],
            'items' => $entries,
            'subtotal' => $subtotal,
            'delivery_fee' => $delivery['fee'],
            'currency' => config('beninfood.currency', 'XOF'),
            'commission' => [
                'rate' => $commissionRate,
                'amount' => $commission,
                'internal' => true,
            ],
            'total' => $subtotal + $delivery['fee'],
        ];
    }

    // ------------------------------------------------------------------ J83/J84
    /**
     * Crée la commande à partir du panier, dans une transaction.
     *
     * @throws DomainException order.*  si une contrainte n'est pas satisfaite
     */
    public function createFromCart(Cart $cart, Address $address, ?string $notes = null): Order
    {
        $this->assertCartOpen($cart);

        $cart->loadMissing(['items.product', 'vendor']);

        $vendor = $cart->vendor;

        $this->assertVendorSellable($vendor);
        $this->assertItemsOrderable($cart->items);
        $this->assertItemsStocked($cart->items);

        $delivery = $this->deliveryQuote($cart, ['address' => $address]);

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
        $commission = (int) round($subtotal * $commissionRate / 100);
        $deliveryFee = $delivery['fee'];
        $total = $subtotal + $deliveryFee;

        $reference = $this->generateReference();

        return DB::transaction(function () use ($cart, $address, $notes, $delivery, $lines, $subtotal, $commissionRate, $commission, $deliveryFee, $total, $reference) {
            $order = Order::create([
                'reference' => $reference,
                'user_id' => $cart->user_id,
                'vendor_id' => $cart->vendor_id,
                'cart_id' => $cart->id,
                'zone_id' => $delivery['zone_id'],
                'status' => OrderStatus::AwaitingPayment->value,
                'payment_status' => PaymentStatus::Initiated->value,
                'subtotal' => $subtotal,
                'discount' => 0,
                'delivery_fee' => $deliveryFee,
                'total' => $total,
                'address_snapshot' => $this->snapshotAddress($address, $notes),
                'delivery_rate_snapshot' => $delivery['rate_snapshot'],
                'notes' => $notes,
                'payment_deadline_at' => now()->addMinutes((int) config('beninfood.orders.payment_deadline_minutes', 15)),
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
                'payment_fee' => 0,
                'commission_base' => $subtotal,
                'commission_rate' => $commissionRate,
                'commission_amount' => $commission,
                'vendor_amount' => $subtotal - $commission,
                'delivery_partner_amount' => 0,
                'platform_amount' => $commission,
                'total_client' => $total,
            ]);

            $order->payment()->create([
                'reference' => 'PAY-'.Str::upper(Str::random(12)),
                'gateway' => 'kkiapay',
                'amount' => $total,
                'status' => PaymentStatus::Initiated->value,
                'expires_at' => $order->payment_deadline_at,
            ]);

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

        return $order->fresh('statusHistory');
    }

    /** Le vendeur refuse la commande. */
    public function refuseVendorOrder(Order $order, ?string $actorId = null, ?string $reason = null): Order
    {
        $this->assertTransition($order, OrderStatus::Cancelled);

        $from = $order->status;

        $order->update([
            'status' => OrderStatus::Cancelled->value,
            'cancelled_at' => now(),
            'cancelled_by' => $actorId,
            'cancellation_reason' => $reason !== null && $reason !== '' ? $reason : 'Commande refusée par le vendeur.',
        ]);

        $this->logTransition($order, $from, OrderStatus::Cancelled, 'vendor', $actorId, $reason ?? 'refus vendeur');

        $this->restoreStock($order);

        return $order->fresh('statusHistory');
    }

    /** Le client annule sa commande. */
    public function cancelClientOrder(Order $order, ?string $actorId = null, string $reason = 'Annulation client.'): Order
    {
        $this->assertTransition($order, OrderStatus::Cancelled);

        $from = $order->status;

        $order->update([
            'status' => OrderStatus::Cancelled->value,
            'cancelled_at' => now(),
            'cancelled_by' => $actorId,
            'cancellation_reason' => $reason,
        ]);

        $this->logTransition($order, $from, OrderStatus::Cancelled, 'client', $actorId, $reason);

        $this->restoreStock($order);

        if ($order->payment()->exists() && in_array($order->payment->status, [PaymentStatus::Initiated, PaymentStatus::Pending])) {
            $order->payment->update(['status' => PaymentStatus::Cancelled->value]);
        }

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
        ]);

        $this->logTransition($order, OrderStatus::AwaitingPayment, OrderStatus::Paid, 'system', null, 'Paiement confirmé');

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

        $order->update(['status' => OrderStatus::Assigned->value]);

        if ($order->delivery->exists()) {
            $order->delivery->update([
                'driver_profile_id' => $driverProfileId,
                'status' => DeliveryStatus::Assigned->value,
                'assigned_at' => now(),
            ]);
        }

        $this->logTransition($order, $from, OrderStatus::Assigned, 'driver', $actorId, null);

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
        ]);

        if ($order->delivery->exists()) {
            $order->delivery->update([
                'status' => DeliveryStatus::Delivered->value,
                'delivered_at' => now(),
            ]);
        }

        $this->logTransition($order, $from, OrderStatus::Delivered, 'driver', $actorId, null);

        return $order->fresh(['statusHistory', 'delivery']);
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
     * @return array<string, mixed>
     */
    private function snapshotAddress(Address $address, ?string $notes): array
    {
        return [
            'label' => $address->label,
            'full_address' => $address->full_address,
            'landmark' => $address->landmark,
            'city' => $address->city,
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
