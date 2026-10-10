<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Exceptions\DomainException;
use App\Models\DriverFloatTransaction;
use App\Models\DriverProfile;
use App\Models\Order;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Paiement à la livraison (cash) — cahier de conception v1.0.
 *
 * Le livreur dispose d'un flottant prépayé (prepaid_balance) qui garantit le
 * montant auprès de la plateforme. À la livraison :
 *   1. le flottant du livreur est débité du total encaissé auprès du client ;
 *   2. la part vendeur (revenu) est créditée sur son wallet disponible ;
 *   3. la part livreur (séquestrée à l'assignation) est libérée ;
 *   4. la commande est marquée payée et livrée (pas d'attente 30 min).
 */
class CashService
{
    public function __construct(private readonly FinanceService $finance) {}

    /** Le livreur peut-il porter cette commande cash (flottant suffisant) ? */
    public function hasCoverage(DriverProfile $driver, Order $order): bool
    {
        return (int) $driver->prepaid_balance >= (int) $order->total;
    }

    /** Recharge le flottant du livreur (entrée d'argent dédiée). */
    public function topUp(DriverProfile $driver, int $amount, ?string $actorId = null, ?string $referenceType = null, ?string $referenceId = null): DriverProfile
    {
        if ($amount <= 0) {
            throw new DomainException('cash.invalid_topup', 'Le montant de recharge doit être positif.', 422);
        }

        $driver = DB::transaction(function () use ($driver, $amount, $actorId, $referenceType, $referenceId) {
            $driver->refresh();
            $driver->increment('prepaid_balance', $amount);

            $driver->floatTransactions()->create([
                'type' => 'credit',
                'amount' => $amount,
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
                'description' => 'Recharge du flottant ('.$actorId.')',
                'created_at' => now(),
            ]);

            return $driver;
        });

        return $driver->fresh('floatTransactions');
    }

    /**
     * Règle une commande cash à la livraison. Idempotent (une seule fois par
     * commande, marqué par delivery_confirmed_at).
     */
    public function settle(Order $order, DriverProfile $driver): Order
    {
        if (! $order->payment_method?->isCash()) {
            throw new DomainException('cash.not_cash_order', 'Cette commande n\'est pas une commande payée en espèces.', 422);
        }

        if ($order->status !== OrderStatus::Delivered) {
            throw new DomainException('cash.not_delivered', 'La commande doit être livrée avant le règlement en espèces.', 422);
        }

        if ($order->delivery_confirmed_at !== null) {
            return $order->fresh(['statusHistory', 'delivery']);
        }

        if (! $this->hasCoverage($driver, $order)) {
            throw new DomainException(
                'cash.insufficient_float',
                'Flottant insuffisant pour encaisser cette commande ('.(int) $order->total.' F requis).',
                409,
            );
        }

        $order->loadMissing('financials', 'vendor', 'delivery.driverProfile');

        return DB::transaction(function () use ($order, $driver) {
            $driver->refresh();
            $driver->decrement('prepaid_balance', (int) $order->total);
            $driver->floatTransactions()->create([
                'type' => 'debit',
                'amount' => (int) $order->total,
                'reference_type' => 'order_cash_settle',
                'reference_id' => $order->id,
                'description' => 'Encaissement commande '.$order->reference,
                'created_at' => now(),
            ]);

            if ($order->vendor !== null && (int) $order->financials?->vendor_amount > 0) {
                $this->finance->creditAvailable(
                    $this->finance->walletFor($order->vendor),
                    (int) $order->financials->vendor_amount,
                    'order_cash_vendor',
                    $order->id,
                    'Paiement cash — part vendeur '.$order->reference,
                );
            }

            $this->finance->releasePending(
                $this->finance->walletFor($driver),
                (int) ($order->financials?->delivery_partner_amount ?? 0),
                'order_driver_release',
                $order->id,
                'Paiement cash — part livreur '.$order->reference,
            );

            $order->update([
                'payment_status' => PaymentStatus::Confirmed->value,
                'delivery_confirmed_at' => now(),
                'auto_confirm_at' => null,
            ]);

            $order->statusHistory()->create([
                'from_status' => OrderStatus::Delivered->value,
                'to_status' => OrderStatus::Delivered->value,
                'actor_type' => 'driver',
                'actor_id' => $driver->user_id,
                'reason' => 'Règlement cash reçu (flottant débité de '.(int) $order->total.' F)',
                'created_at' => now(),
            ]);

            return $order->fresh(['statusHistory', 'delivery']);
        });
    }

    /** Historique des mouvements de flottant d'un livreur. @return \Illuminate\Database\Eloquent\Collection<int, DriverFloatTransaction> */
    public function history(DriverProfile $driver): Collection
    {
        return $driver->floatTransactions()
            ->orderByDesc('created_at')
            ->limit(50)
            ->get();
    }
}
