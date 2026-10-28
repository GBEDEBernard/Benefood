<?php

namespace App\Services;

use App\Enums\PaymentMethod;
use App\Enums\PaymentPurpose;
use App\Enums\PaymentStatus;
use App\Exceptions\DomainException;
use App\Models\FinancialTransaction;
use App\Models\Order;
use App\Models\Payment;
use App\Models\User;
use App\Services\Payments\PaymentGateway;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Frais d'approche après paiement : le client choisit un livreur une fois la
 * commande payée, règle l'approche en ligne ou en espèces à la livraison, puis
 * le livreur est sollicité.
 */
class ApproachFeeService
{
    public function __construct(
        private readonly DeliveryPricingService $pricing,
        private readonly FinanceService $finance,
        private readonly DriverSelectionService $selection,
        private readonly CashService $cash,
        private readonly PaymentGateway $gateway,
    ) {}

    /**
     * Prépare le supplément d'approche et, pour le cash, l'ajoute au total dû.
     *
     * @return array{status: string, amount: int, payment_id?: string, payload?: array<string, mixed>}
     */
    public function request(Order $order, User $client, \App\Models\DriverProfile $driver, PaymentMethod $method): array
    {
        if ($order->user_id !== $client->id) {
            throw new DomainException('approach.not_found', 'Commande introuvable.', 404);
        }

        if ($order->isCancelled()) {
            throw new DomainException('approach.cancelled', 'Cette commande est annulée.', 422);
        }

        $this->selection->assertSelectableForOrder($order, $client, $driver);

        $order->loadMissing('vendor');

        if ($order->vendor === null) {
            throw new DomainException('approach.vendor_missing', 'Boutique introuvable.', 404);
        }

        $quote = $this->pricing->approachQuote($driver, $order->vendor);
        $fee = (int) $quote['fee'];

        if ($order->approachIsPaid()) {
            if ($order->approach_driver_profile_id !== $driver->id) {
                $order->update(['approach_driver_profile_id' => $driver->id]);
            }

            $this->targetDriver($order->fresh(), $driver);

            return ['status' => 'already_paid', 'amount' => 0];
        }

        if ($order->approach_payment_status === PaymentStatus::Pending
            && $order->approach_payment_method?->isCash()) {
            $order->update(['approach_driver_profile_id' => $driver->id]);

            $this->targetDriver($order->fresh(), $driver);

            return ['status' => 'cash', 'amount' => (int) $order->approach_fee];
        }

        if ($fee === 0) {
            return $this->requestFree($order, $driver, $quote, $method);
        }

        if ($method->isCash()) {
            return $this->requestCash($order, $driver, $quote, $fee);
        }

        return $this->requestOnline($order, $driver, $quote, $fee);
    }

    /**
     * @param  array<string, mixed>  $quote
     * @return array{status: string, amount: int}
     */
    private function requestFree(Order $order, \App\Models\DriverProfile $driver, array $quote, PaymentMethod $method): array
    {
        $order = DB::transaction(function () use ($order, $driver, $quote, $method): Order {
            $locked = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();

            $locked->update([
                'approach_fee' => 0,
                'approach_distance_km' => $quote['distance_km'],
                'approach_pricing_snapshot' => $quote['snapshot'],
                'approach_payment_method' => $method->value,
                'approach_payment_status' => PaymentStatus::Confirmed->value,
                'approach_driver_profile_id' => $driver->id,
                'approach_paid_at' => now(),
            ]);

            return $locked->fresh();
        });

        $this->targetDriver($order, $driver);

        return ['status' => 'free', 'amount' => 0];
    }

    /**
     * @param  array<string, mixed>  $quote
     * @return array{status: string, amount: int, payment_id?: string, payload?: array<string, mixed>}
     */
    private function requestCash(Order $order, \App\Models\DriverProfile $driver, array $quote, int $fee): array
    {
        if ($order->approach_payment_status === PaymentStatus::Pending
            && $order->approach_driver_profile_id === $driver->id
            && (int) $order->approach_fee === $fee) {
            return ['status' => 'cash', 'amount' => $fee];
        }

        if (in_array($order->approach_payment_status, [PaymentStatus::Initiated, PaymentStatus::Pending], true)) {
            throw new DomainException(
                'approach.already_pending',
                'Un paiement d\'approche est déjà en cours sur cette commande.',
                409,
            );
        }

        $order = DB::transaction(function () use ($order, $driver, $quote, $fee): Order {
            $locked = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();

            $locked->update([
                'approach_fee' => $fee,
                'approach_distance_km' => $quote['distance_km'],
                'approach_pricing_snapshot' => $quote['snapshot'],
                'approach_payment_method' => PaymentMethod::Cash->value,
                'approach_payment_status' => PaymentStatus::Pending->value,
                'approach_driver_profile_id' => $driver->id,
            ]);

            $this->applyApproachToFinancials($locked->fresh(), $fee);

            return $locked->fresh(['financials', 'delivery']);
        });

        $this->targetDriver($order, $driver);

        return ['status' => 'cash', 'amount' => $fee];
    }

    /**
     * @param  array<string, mixed>  $quote
     * @return array{status: string, amount: int, payment_id?: string, payload?: array<string, mixed>}
     */
    private function requestOnline(Order $order, \App\Models\DriverProfile $driver, array $quote, int $fee): array
    {
        if ($fee === 0) {
            $order = DB::transaction(function () use ($order, $driver, $quote): Order {
                $locked = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();

                $locked->update([
                    'approach_fee' => 0,
                    'approach_distance_km' => $quote['distance_km'],
                    'approach_pricing_snapshot' => $quote['snapshot'],
                    'approach_payment_method' => PaymentMethod::Online->value,
                    'approach_payment_status' => PaymentStatus::Confirmed->value,
                    'approach_driver_profile_id' => $driver->id,
                    'approach_paid_at' => now(),
                ]);

                return $locked->fresh();
            });

            $this->targetDriver($order, $driver);

            return ['status' => 'free', 'amount' => 0];
        }

        $payment = DB::transaction(function () use ($order, $driver, $quote, $fee): Payment {
            $locked = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();

            Payment::query()
                ->where('order_id', $locked->id)
                ->where('purpose', PaymentPurpose::OrderApproach->value)
                ->whereIn('status', [PaymentStatus::Initiated->value, PaymentStatus::Pending->value])
                ->update(['status' => PaymentStatus::Expired->value]);

            $locked->update([
                'approach_fee' => $fee,
                'approach_distance_km' => $quote['distance_km'],
                'approach_pricing_snapshot' => $quote['snapshot'],
                'approach_payment_method' => PaymentMethod::Online->value,
                'approach_payment_status' => PaymentStatus::Initiated->value,
                'approach_driver_profile_id' => $driver->id,
            ]);

            return $locked->approachPayment()->create([
                'reference' => 'APP-'.strtoupper(\Illuminate\Support\Str::random(12)),
                'purpose' => PaymentPurpose::OrderApproach->value,
                'gateway' => 'fedapay',
                'amount' => $fee,
                'status' => PaymentStatus::Initiated->value,
                'expires_at' => now()->addMinutes(15),
            ]);
        });

        $payload = $this->gateway->createApproachPayment($order->fresh(), $payment);

        if (($payload['status'] ?? null) === 'failed') {
            $payment->update(['status' => PaymentStatus::Failed->value, 'payload' => $payload]);
            $order->update(['approach_payment_status' => PaymentStatus::Failed->value]);

            throw new DomainException(
                'approach.gateway_error',
                (string) ($payload['message'] ?? 'Le paiement d\'approche n\'a pas pu être préparé. Réessayez.'),
                422,
            );
        }

        $payment->update([
            'gateway_txn_id' => $payload['transaction_id'] ?? null,
            'payload' => $payload,
        ]);

        return [
            'status' => 'online',
            'amount' => $fee,
            'payment_id' => $payment->id,
            'payload' => $payload,
        ];
    }

    /**
     * Applique le supplément d'approche au total de la commande et à sa
     * ventilation financière (livraison, commission livreur, plateforme).
     */
    public function applyApproachToFinancials(Order $order, int $fee): void
    {
        $order->loadMissing('financials', 'delivery');
        $financials = $order->financials;

        if ($financials === null) {
            return;
        }

        $breakdown = $this->finance->breakdown(
            (int) $financials->subtotal,
            (int) $financials->delivery_fee,
            (int) $financials->commission_rate,
            $fee,
        );

        $order->update(['total' => $breakdown['total_client']]);

        $financials->update([
            'approach_fee' => $breakdown['approach_fee'],
            'delivery_total' => $breakdown['delivery_total'],
            'payment_fee' => $breakdown['payment_fee'],
            'delivery_commission_amount' => $breakdown['delivery_commission_amount'],
            'delivery_partner_amount' => $breakdown['delivery_partner_amount'],
            'base_partner_amount' => $breakdown['base_partner_amount'],
            'approach_partner_amount' => $breakdown['approach_partner_amount'],
            'platform_amount' => $breakdown['platform_amount'],
            'total_client' => $breakdown['total_client'],
        ]);

        $delivery = $order->delivery;

        if ($delivery !== null && $delivery->driver_profile_id === null) {
            $delivery->update([
                'fee' => $breakdown['delivery_total'],
                'partner_amount' => $breakdown['delivery_partner_amount'],
                'targeted_driver_profile_id' => $order->approach_driver_profile_id,
            ]);
        }
    }

    /** Règle un supplément d'approche payé en ligne. */
    public function settleOnline(Order $order, Payment $payment): void
    {
        $order = DB::transaction(function () use ($order, $payment): Order {
            $locked = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();

            if ($locked->approachIsPaid()) {
                return $locked;
            }

            $fee = (int) $locked->approach_fee;

            $this->applyApproachToFinancials($locked, $fee);

            $locked->update([
                'approach_payment_status' => PaymentStatus::Confirmed->value,
                'approach_paid_at' => now(),
            ]);

            if ($fee > 0) {
                FinancialTransaction::create([
                    'payment_id' => $payment->id,
                    'order_id' => $locked->id,
                    'type' => 'approach_payment',
                    'amount' => $fee,
                    'currency' => $payment->currency ?? 'XOF',
                    'description' => 'Frais d\'approche reçus via fedapay',
                    'meta' => is_array($payment->payload) ? $payment->payload : null,
                ]);

                $this->finance->recordApproachPayment($locked, $fee);
            }

            return $locked->fresh();
        });

        $driver = $order->approach_driver_profile_id !== null
            ? \App\Models\DriverProfile::find($order->approach_driver_profile_id)
            : null;

        if ($driver !== null) {
            $this->targetDriver($order, $driver);
        }
    }

    /** Encaissement cash de l'approche sur une commande payée en ligne. */
    public function settleCash(Order $order, \App\Models\DriverProfile $driver): void
    {
        if (! $order->approach_payment_method?->isCash()
            || $order->approachIsPaid()
            || ! $order->hasApproachFee()) {
            return;
        }

        if (! $this->cash->hasFloat($driver, (int) $order->approach_fee)) {
            throw new DomainException(
                'approach.cash_insufficient_float',
                'Flottant insuffisant pour encaisser les frais d\'approche ('.(int) $order->approach_fee.' F requis).',
                409,
            );
        }

        $this->cash->debitFloat(
            $driver,
            (int) $order->approach_fee,
            'order_approach_cash',
            $order->id,
            'Frais d\'approche cash — '.$order->reference,
        );

        $order->update([
            'approach_payment_status' => PaymentStatus::Confirmed->value,
            'approach_paid_at' => now(),
        ]);
    }

    private function targetDriver(Order $order, \App\Models\DriverProfile $driver): void
    {
        $order->loadMissing('user');

        if ($order->user === null) {
            return;
        }

        try {
            $this->selection->requestForOrder($order, $order->user, $driver->id);
        } catch (\Throwable $exception) {
            Log::warning('Approach paid but driver targeting failed', [
                'order_id' => $order->id,
                'driver_id' => $driver->id,
                'error' => $exception->getMessage(),
            ]);

            $order->update(['approach_driver_profile_id' => null]);
        }
    }
}
