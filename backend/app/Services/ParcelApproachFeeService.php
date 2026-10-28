<?php

namespace App\Services;

use App\Enums\PaymentMethod;
use App\Enums\PaymentPurpose;
use App\Enums\PaymentStatus;
use App\Exceptions\DomainException;
use App\Models\DriverProfile;
use App\Models\Parcel;
use App\Models\Payment;
use App\Models\User;
use App\Services\Payments\PaymentGateway;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Frais d'approche d'un colis : le client choisit un livreur après paiement,
 * règle l'approche en ligne ou en espèces, puis le livreur est sollicité.
 */
class ParcelApproachFeeService
{
    public function __construct(
        private readonly DeliveryPricingService $pricing,
        private readonly FinanceService $finance,
        private readonly DriverSelectionService $selection,
        private readonly CashService $cash,
        private readonly PaymentGateway $gateway,
    ) {}

    /**
     * @return array{status: string, amount: int, payment_id?: string, payload?: array<string, mixed>}
     */
    public function request(Parcel $parcel, User $client, DriverProfile $driver, PaymentMethod $method): array
    {
        if ($parcel->user_id !== $client->id) {
            throw new DomainException('approach.not_found', 'Colis introuvable.', 404);
        }

        if ($parcel->isCancelled() || $parcel->isDelivered()) {
            throw new DomainException('approach.closed', 'Ce colis est déjà clôturé.', 422);
        }

        if ($parcel->status->value !== 'paid' || $parcel->driver_profile_id !== null) {
            throw new DomainException(
                'approach.parcel_not_open',
                'Le livreur ne peut être choisi qu\'avant l\'affectation du colis.',
                409,
            );
        }

        $this->selection->assertSelectableForParcel($parcel, $client, $driver);

        $pickup = $parcel->pickup_snapshot ?? [];
        $quote = $this->pricing->approachQuoteForPoint(
            $driver,
            isset($pickup['latitude']) ? (float) $pickup['latitude'] : null,
            isset($pickup['longitude']) ? (float) $pickup['longitude'] : null,
        );
        $fee = (int) $quote['fee'];

        if ($parcel->approachIsPaid()) {
            if ($parcel->approach_driver_profile_id !== $driver->id) {
                $parcel->update(['approach_driver_profile_id' => $driver->id]);
            }

            $this->targetDriver($parcel->fresh(), $driver);

            return ['status' => 'already_paid', 'amount' => 0];
        }

        if ($parcel->approach_payment_status === PaymentStatus::Pending
            && $parcel->approach_payment_method?->isCash()) {
            $parcel->update(['approach_driver_profile_id' => $driver->id]);

            $this->targetDriver($parcel->fresh(), $driver);

            return ['status' => 'cash', 'amount' => (int) $parcel->approach_fee];
        }

        if ($fee === 0) {
            $parcel = DB::transaction(function () use ($parcel, $driver, $quote, $method): Parcel {
                $locked = Parcel::query()->whereKey($parcel->id)->lockForUpdate()->firstOrFail();

                $locked->update([
                    'approach_fee' => 0,
                    'approach_distance_km' => $quote['distance_km'],
                    'approach_pricing_snapshot' => $quote['snapshot'],
                    'approach_commission_amount' => 0,
                    'approach_partner_amount' => 0,
                    'approach_payment_method' => $method->value,
                    'approach_payment_status' => PaymentStatus::Confirmed->value,
                    'approach_driver_profile_id' => $driver->id,
                    'approach_paid_at' => now(),
                ]);

                return $locked->fresh();
            });

            $this->targetDriver($parcel, $driver);

            return ['status' => 'free', 'amount' => 0];
        }

        if ($method->isCash()) {
            return $this->requestCash($parcel, $driver, $quote, $fee);
        }

        return $this->requestOnline($parcel, $driver, $quote, $fee);
    }

    /**
     * @param  array<string, mixed>  $quote
     * @return array{status: string, amount: int}
     */
    private function requestCash(Parcel $parcel, DriverProfile $driver, array $quote, int $fee): array
    {
        if ($parcel->approach_payment_status === PaymentStatus::Pending
            && $parcel->approach_driver_profile_id === $driver->id
            && (int) $parcel->approach_fee === $fee) {
            return ['status' => 'cash', 'amount' => $fee];
        }

        if (in_array($parcel->approach_payment_status, [PaymentStatus::Initiated, PaymentStatus::Pending], true)) {
            throw new DomainException(
                'approach.already_pending',
                'Un paiement d\'approche est déjà en cours sur ce colis.',
                409,
            );
        }

        $parcel = DB::transaction(function () use ($parcel, $driver, $quote, $fee): Parcel {
            $locked = Parcel::query()->whereKey($parcel->id)->lockForUpdate()->firstOrFail();

            $locked->update([
                'approach_fee' => $fee,
                'approach_distance_km' => $quote['distance_km'],
                'approach_pricing_snapshot' => $quote['snapshot'],
                'approach_payment_method' => PaymentMethod::Cash->value,
                'approach_payment_status' => PaymentStatus::Pending->value,
                'approach_driver_profile_id' => $driver->id,
            ]);

            $this->applyApproachToParcel($locked->fresh(), $fee);

            return $locked->fresh();
        });

        $this->targetDriver($parcel, $driver);

        return ['status' => 'cash', 'amount' => $fee];
    }

    /**
     * @param  array<string, mixed>  $quote
     * @return array{status: string, amount: int, payment_id?: string, payload?: array<string, mixed>}
     */
    private function requestOnline(Parcel $parcel, DriverProfile $driver, array $quote, int $fee): array
    {
        $payment = DB::transaction(function () use ($parcel, $driver, $quote, $fee): Payment {
            $locked = Parcel::query()->whereKey($parcel->id)->lockForUpdate()->firstOrFail();

            Payment::query()
                ->where('parcel_id', $locked->id)
                ->where('purpose', PaymentPurpose::ParcelApproach->value)
                ->whereIn('status', [PaymentStatus::Initiated->value, PaymentStatus::Pending->value])
                ->update(['status' => PaymentStatus::Expired->value]);

            $locked->update([
                'approach_fee' => 0,
                'approach_distance_km' => $quote['distance_km'],
                'approach_pricing_snapshot' => $quote['snapshot'],
                'approach_payment_method' => PaymentMethod::Online->value,
                'approach_payment_status' => PaymentStatus::Initiated->value,
                'approach_driver_profile_id' => $driver->id,
            ]);

            return $locked->approachPayment()->create([
                'reference' => 'APP-'.Str::upper(Str::random(12)),
                'purpose' => PaymentPurpose::ParcelApproach->value,
                'gateway' => 'fedapay',
                'amount' => $fee,
                'status' => PaymentStatus::Initiated->value,
                'expires_at' => now()->addMinutes(15),
            ]);
        });

        $payload = $this->gateway->createApproachPayment($parcel->fresh(), $payment);

        if (($payload['status'] ?? null) === 'failed') {
            $payment->update(['status' => PaymentStatus::Failed->value, 'payload' => $payload]);
            $parcel->update(['approach_payment_status' => PaymentStatus::Failed->value]);

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

    /** Applique l'approche aux totaux et à la ventilation du colis. */
    public function applyApproachToParcel(Parcel $parcel, int $fee): void
    {
        $rate = (int) $parcel->commission_rate;
        $baseCommission = (int) $parcel->commission_amount;
        $basePartner = (int) $parcel->delivery_fee - $baseCommission;
        $approachCommission = (int) round($fee * $rate / 100);
        $approachPartner = $fee - $approachCommission;

        $parcel->update([
            'approach_fee' => $fee,
            'approach_commission_amount' => $approachCommission,
            'approach_partner_amount' => $approachPartner,
            'partner_amount' => max(0, $basePartner + $approachPartner),
            'platform_amount' => $baseCommission + $approachCommission,
        ]);
    }

    /** Règle une approche colis payée en ligne. */
    public function settleOnline(Parcel $parcel, Payment $payment): void
    {
        $parcel = DB::transaction(function () use ($parcel, $payment): Parcel {
            $locked = Parcel::query()->whereKey($parcel->id)->lockForUpdate()->firstOrFail();

            if ($locked->approachIsPaid()) {
                return $locked;
            }

            $this->applyApproachToParcel($locked, (int) $payment->amount);

            $locked->update([
                'approach_payment_status' => PaymentStatus::Confirmed->value,
                'approach_paid_at' => now(),
            ]);

            if ((int) $payment->amount > 0) {
                $this->finance->recordParcelApproachPayment($locked, (int) $payment->amount);
            }

            return $locked->fresh();
        });

        $driver = $parcel->approach_driver_profile_id !== null
            ? DriverProfile::find($parcel->approach_driver_profile_id)
            : null;

        if ($driver !== null) {
            $this->targetDriver($parcel, $driver);
        }
    }

    private function targetDriver(Parcel $parcel, DriverProfile $driver): void
    {
        $parcel->loadMissing('user');

        if ($parcel->user === null) {
            return;
        }

        try {
            $this->selection->requestForParcel($parcel, $parcel->user, $driver->id);
        } catch (\Throwable $exception) {
            Log::warning('Parcel approach paid but driver targeting failed', [
                'parcel_id' => $parcel->id,
                'driver_id' => $driver->id,
                'error' => $exception->getMessage(),
            ]);

            $parcel->update(['approach_driver_profile_id' => null]);
        }
    }
}
