<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\JournalEntryType;
use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Enums\RefundStatus;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\Refund;
use App\Services\Payments\PaymentGateway;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Détermination et exécution des remboursements (J120, J121, J16 §4.6).
 *
 * Un remboursement est déterminé automatiquement lors d'une annulation
 * après paiement, puis exécuté via la passerelle FedaPay quand elle est
 * configurée en mode automatique (sinon trace manuelle par la porteuse).
 */
class RefundService
{
    public function __construct(
        private readonly FinancialJournalService $journal,
        private readonly NotificationService $notifications,
    ) {}

    // ----------------------------------------------------------------- J120
    /**
     * Détermine le type et le montant de remboursement (total / partiel / nul).
     *
     * Le statut passé correspond à celui de la commande au moment de
     * l'annulation (avant passage à `cancelled`).
     *
     * @return array{type: string, amount: int, fees: int}
     */
    public function determineRefund(Order $order, string $actorType, ?int $overrideAmount = null, ?OrderStatus $statusAtCancellation = null): array
    {
        $total = (int) $order->total;

        if ($order->payment_status !== PaymentStatus::Confirmed) {
            return ['type' => 'none', 'amount' => 0, 'fees' => 0];
        }

        if ($actorType === 'vendor') {
            return ['type' => 'total', 'amount' => $total, 'fees' => 0];
        }

        if ($overrideAmount !== null && $actorType === 'porteuse') {
            $capped = max(0, min($total, $overrideAmount));

            return [
                'type' => $capped <= 0 ? 'none' : ($capped >= $total ? 'total' : 'partial'),
                'amount' => $capped,
                'fees' => $total - $capped,
            ];
        }

        $preparationFee = (int) config('beninfood.cancel.preparation_fee', 0);
        $assignmentFee = (int) config('beninfood.cancel.assignment_fee', 0);

        $status = $statusAtCancellation ?? $order->status;

        $refundAmount = match (true) {
            $status === OrderStatus::AwaitingPayment => $total,
            $status === OrderStatus::Paid => $total,
            $status === OrderStatus::Accepted => $total,
            in_array($status, [OrderStatus::Preparing, OrderStatus::Ready], true) => max(0, $total - $preparationFee),
            $status === OrderStatus::Assigned => max(0, $total - $assignmentFee),
            default => 0,
        };

        $fees = $total - $refundAmount;

        return [
            'type' => $refundAmount <= 0 ? 'none' : ($fees > 0 ? 'partial' : 'total'),
            'amount' => $refundAmount,
            'fees' => $fees,
        ];
    }

    // ----------------------------------------------------------------- J121
    /**
     * Crée un remboursement pour une commande annulée puis tente de l'exécuter
     * via la passerelle (mode auto) ou le laisse en statut pending (mode manuel).
     */
    public function handleOrderCancellation(
        Order $order,
        string $actorType,
        ?string $actorId,
        string $reason,
        ?OrderStatus $statusAtCancellation = null,
        ?int $overrideAmount = null,
    ): ?Refund {
        $decision = $this->determineRefund($order, $actorType, $overrideAmount, $statusAtCancellation);

        if ($decision['type'] === 'none') {
            $this->notifyCancellation($order, null, $actorType);

            return null;
        }

        $refund = $this->createPendingRefund($order, $decision['amount'], $reason, $actorId);

        $this->journal->recordReversalForCancellation($order, $actorId);

        $auto = $this->shouldAutoExecute()
            && $order->payment !== null
            && $order->payment->status === PaymentStatus::Confirmed;

        if ($auto) {
            $refund = $this->executeRefund($refund, $actorId);
        }

        $this->notifyCancellation($order, $refund, $actorType);

        return $refund;
    }

    /**
     * Exécute un remboursement (mode manuel par la porteuse, J121 §5).
     */
    public function executeRefund(Refund $refund, ?string $actorId = null, bool $forceGateway = false): Refund
    {
        if ($refund->status === RefundStatus::Executed) {
            return $refund->fresh();
        }

        return DB::transaction(function () use ($refund, $actorId, $forceGateway) {
            $order = $refund->order;
            $payment = $refund->payment;
            $providerRefundId = null;

            $useGateway = $forceGateway || $this->shouldAutoExecute();

            if ($useGateway) {
                try {
                    $gateway = app(PaymentGateway::class);
                    $result = $gateway->refund($payment, $refund->amount, $refund->reason);
                    if ($result['ok'] ?? false) {
                        $providerRefundId = $result['refund_id'] ?? null;
                    }
                } catch (\Throwable $e) {
                    Log::warning('Refund gateway failed', ['error' => $e->getMessage()]);
                }
            }

            $refund->update([
                'status' => RefundStatus::Executed->value,
                'gateway_refund_id' => $providerRefundId,
                'executed_at' => now(),
                'executed_by' => $actorId,
            ]);

            if ($payment !== null) {
                $payment->update(['status' => PaymentStatus::Refunded->value]);
            }

            $order->update([
                'status' => OrderStatus::Refunded->value,
                'payment_status' => PaymentStatus::Refunded->value,
            ]);

            $order->statusHistory()->create([
                'from_status' => OrderStatus::Cancelled->value,
                'to_status' => OrderStatus::Refunded->value,
                'actor_type' => 'system',
                'actor_id' => $actorId,
                'reason' => 'Remboursement exécuté',
                'created_at' => now(),
            ]);

            $this->journal->record([
                'entry_type' => JournalEntryType::Refund,
                'reference_type' => 'refund',
                'reference_id' => $refund->id,
                'credit' => $refund->amount,
                'participant' => $order->user_id,
                'actor' => $actorId,
            ]);

            try {
                $this->notifications->notifyEvent('order.refunded', [$order->user, $order->vendor?->user], [
                    'reference' => $order->reference,
                    'amount' => $refund->amount,
                ]);
            } catch (\Throwable $e) {
                Log::warning('Refund notification failed', ['error' => $e->getMessage()]);
            }

            return $refund->fresh();
        });
    }

    private function createPendingRefund(Order $order, int $amount, string $reason, ?string $actorId): Refund
    {
        return Refund::create([
            'order_id' => $order->id,
            'payment_id' => $order->payment?->id,
            'amount' => $amount,
            'reason' => $reason,
            'status' => RefundStatus::Pending->value,
            'executed_by' => $actorId,
        ]);
    }

    // ------------------------------------------------------- J120/J121 (colis)

    /**
     * Annulation d'un colis payé en ligne : crée le remboursement client du
     * montant encaissé et l'exécute automatiquement si la passerelle est en
     * mode auto. Les séquestres internes sont contre-passés par ParcelService.
     */
    public function handleParcelCancellation(Parcel $parcel, string $actorType, ?string $actorId, string $reason): ?Refund
    {
        $payment = $parcel->payment;

        if ($parcel->isCash()
            || $payment === null
            || $payment->status !== PaymentStatus::Confirmed
            || $parcel->payment_status === PaymentStatus::Refunded) {
            return null;
        }

        $refund = $this->createPendingParcelRefund($parcel, $parcel->totalAmount(), $reason, $actorId);

        if ($this->shouldAutoExecute()) {
            return $this->executeParcelRefund($refund, $actorId);
        }

        $this->notifications->notifyEvent('parcel.refund_initiated', [$parcel->user], [
            'reference' => $parcel->reference,
            'amount' => $refund->amount,
        ]);

        return $refund;
    }

    /**
     * Exécute le remboursement d'un colis (mode auto ou manuel par la porteuse).
     */
    public function executeParcelRefund(Refund $refund, ?string $actorId = null, bool $forceGateway = false): Refund
    {
        if ($refund->status === RefundStatus::Executed) {
            return $refund->fresh();
        }

        return DB::transaction(function () use ($refund, $actorId, $forceGateway) {
            $parcel = $refund->parcel;
            $payment = $refund->payment;
            $providerRefundId = null;

            $useGateway = $forceGateway || $this->shouldAutoExecute();

            if ($useGateway && $payment !== null) {
                try {
                    $result = app(PaymentGateway::class)->refund($payment, $refund->amount, $refund->reason);
                    if ($result['ok'] ?? false) {
                        $providerRefundId = $result['refund_id'] ?? null;
                    }
                } catch (\Throwable $e) {
                    Log::warning('Parcel refund gateway failed', ['error' => $e->getMessage()]);
                }
            }

            $refund->update([
                'status' => RefundStatus::Executed->value,
                'gateway_refund_id' => $providerRefundId,
                'executed_at' => now(),
                'executed_by' => $actorId,
            ]);

            if ($payment !== null) {
                $payment->update(['status' => PaymentStatus::Refunded->value]);
            }

            if ($parcel !== null) {
                $parcel->update(['payment_status' => PaymentStatus::Refunded->value]);

                $this->notifications->notifyEvent('parcel.refunded', [$parcel->user], [
                    'reference' => $parcel->reference,
                    'amount' => $refund->amount,
                ]);
            }

            return $refund->fresh();
        });
    }

    private function createPendingParcelRefund(Parcel $parcel, int $amount, string $reason, ?string $actorId): Refund
    {
        return Refund::create([
            'parcel_id' => $parcel->id,
            'payment_id' => $parcel->payment?->id,
            'amount' => $amount,
            'reason' => $reason,
            'status' => RefundStatus::Pending->value,
            'executed_by' => $actorId,
        ]);
    }

    /** Exécution automatique via la passerelle si activée et configurée. */
    private function shouldAutoExecute(): bool
    {
        return (bool) config('beninfood.refunds.automatic_execution', false)
            && (bool) config('fedapay.enabled', false);
    }

    private function notifyCancellation(Order $order, ?Refund $refund, string $actorType): void
    {
        $reference = $order->reference;
        $data = ['order_id' => $order->id, 'reference' => $reference];

        $delivery = $order->delivery()->with('driverProfile.user')->first();

        if ($delivery !== null
            && $delivery->status !== DeliveryStatus::Delivered
            && $delivery->driverProfile?->user !== null) {
            $this->notifications->notifyEvent('delivery.cancelled', [$delivery->driverProfile->user], $data + [
                'delivery_id' => $delivery->id,
            ]);
        }

        $this->notifications->notifyEvent('order.cancelled', [$order->user, $order->vendor?->user], $data);

        if ($refund !== null && $refund->status === RefundStatus::Pending) {
            $this->notifications->notifyEvent('order.refund_initiated', [$order->user], $data + ['amount' => $refund->amount]);
        }
    }
}
