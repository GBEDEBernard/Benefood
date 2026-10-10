<?php

namespace App\Services;

use App\Enums\ParcelStatus;
use App\Enums\PaymentStatus;
use App\Exceptions\DomainException;
use App\Models\DriverProfile;
use App\Models\Parcel;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Service colis (cahier de conception v1.0, phase 3) : création, tarification
 * par distance, validation du paiement, attribution à un livreur et libération
 * des fonds (80 % livreur / 20 % plateforme).
 */
class ParcelService
{
    public function __construct(
        private readonly ParcelPricingService $pricing,
        private readonly DeliveryPricingService $delivery,
        private readonly FinanceService $finance,
        private readonly NotificationService $notifications,
    ) {}

    /**
     * Devis d'un colis A → B (distance + répartition).
     *
     * @param  array<string, mixed>  $pickup
     * @param  array<string, mixed>  $dropoff
     * @return array<string, mixed>
     */
    public function quote(array $pickup, array $dropoff): array
    {
        $distance = $this->delivery->distanceKm(
            $pickup['latitude'] ?? null,
            $pickup['longitude'] ?? null,
            $dropoff['latitude'] ?? null,
            $dropoff['longitude'] ?? null,
        );

        return $this->pricing->quote($distance);
    }

    /**
     * Crée un colis et son paiement en attente.
     *
     * @param  array<string, mixed>  $pickup
     * @param  array<string, mixed>  $dropoff
     */
    public function create(User $client, array $pickup, array $dropoff, ?string $description = null): Parcel
    {
        $breakdown = $this->quote($pickup, $dropoff);

        return DB::transaction(function () use ($client, $pickup, $dropoff, $description, $breakdown): Parcel {
            /** @var Parcel $parcel */
            $parcel = Parcel::create([
                'reference' => $this->generateReference(),
                'user_id' => $client->id,
                'status' => ParcelStatus::AwaitingPayment->value,
                'payment_status' => PaymentStatus::Initiated->value,
                'currency' => config('beninfood.currency', 'XOF'),
                'description' => $description,
                'pickup_snapshot' => $pickup,
                'dropoff_snapshot' => $dropoff,
                'distance_km' => $breakdown['distance_km'],
                'delivery_fee' => $breakdown['delivery_fee'],
                'commission_rate' => $breakdown['commission_rate'],
                'commission_amount' => $breakdown['commission_amount'],
                'partner_amount' => $breakdown['partner_amount'],
                'platform_amount' => $breakdown['platform_amount'],
                'payment_deadline_at' => now()->addMinutes((int) config('beninfood.orders.payment_deadline_minutes', 15)),
            ]);

            $parcel->payment()->create([
                'reference' => 'PAY-'.Str::upper(Str::random(12)),
                'gateway' => 'kkiapay',
                'amount' => $breakdown['delivery_fee'],
                'status' => PaymentStatus::Initiated->value,
                'expires_at' => $parcel->payment_deadline_at,
            ]);

            $this->logTransition($parcel, null, ParcelStatus::AwaitingPayment, 'system', null, null);

            return $parcel->fresh(['payment']);
        });
    }

    /** Confirme le paiement du colis (awaiting_payment → paid). */
    public function confirmPayment(Parcel $parcel, int $amount): Parcel
    {
        if (! $parcel->status->isAwaitingPayment()) {
            throw new DomainException('parcel.payment_not_expected', 'Ce colis n\'attend pas de paiement.', 422);
        }

        $parcel->update([
            'status' => ParcelStatus::Paid->value,
            'payment_status' => PaymentStatus::Confirmed->value,
        ]);

        $parcel->payment?->update([
            'status' => PaymentStatus::Confirmed->value,
            'paid_at' => now(),
        ]);

        $this->logTransition($parcel, ParcelStatus::AwaitingPayment, ParcelStatus::Paid, 'system', null, 'Paiement confirmé');

        return $parcel->fresh(['payment', 'statusHistory']);
    }

    /** Un livreur accepte le colis (paid → assigned) et sa part est séquestrée. */
    public function assignDriver(Parcel $parcel, DriverProfile $driver, ?string $actorId = null): Parcel
    {
        $this->assertTransition($parcel, ParcelStatus::Assigned);

        $from = $parcel->status;

        $parcel->update([
            'status' => ParcelStatus::Assigned->value,
            'driver_profile_id' => $driver->id,
            'assigned_at' => now(),
        ]);

        $this->finance->creditPending(
            $this->finance->walletFor($driver),
            (int) $parcel->partner_amount,
            'parcel_driver_credit',
            $parcel->id,
            'Part livreur colis (en attente) — '.$parcel->reference,
        );

        $this->logTransition($parcel, $from, ParcelStatus::Assigned, 'driver', $actorId, null);

        return $parcel->fresh(['driverProfile.user', 'statusHistory']);
    }

    public function markPickedUp(Parcel $parcel, ?string $actorId = null): Parcel
    {
        return $this->transition($parcel, ParcelStatus::PickedUp, 'driver', $actorId, ['picked_up_at' => now()]);
    }

    public function markInDelivery(Parcel $parcel, ?string $actorId = null): Parcel
    {
        return $this->transition($parcel, ParcelStatus::InDelivery, 'driver', $actorId);
    }

    /** Livraison confirmée : la part livreur devient retirable. */
    public function markDelivered(Parcel $parcel, ?string $actorId = null): Parcel
    {
        $parcel = $this->transition($parcel, ParcelStatus::Delivered, 'driver', $actorId, ['delivered_at' => now()]);

        $driver = $parcel->driverProfile;

        if ($driver !== null) {
            $this->finance->releasePending(
                $this->finance->walletFor($driver),
                (int) $parcel->partner_amount,
                'parcel_driver_release',
                $parcel->id,
                'Libération part livreur colis — '.$parcel->reference,
            );
        }

        $this->notifications->notifyEvent('order.delivered', [$parcel->user], [
            'reference' => $parcel->reference,
            'order_id' => $parcel->id,
        ]);

        return $parcel->fresh(['driverProfile.user', 'statusHistory']);
    }

    /** Annule un colis (rembourse si payé) et contre-passe les séquestres. */
    public function cancel(Parcel $parcel, string $actorType, ?string $actorId, string $reason): Parcel
    {
        $allowed = [ParcelStatus::AwaitingPayment, ParcelStatus::Paid, ParcelStatus::Assigned];

        if (! in_array($parcel->status, $allowed, true)) {
            throw new DomainException('parcel.cannot_cancel', 'Ce colis ne peut pas être annulé à ce stade.', 409);
        }

        $from = $parcel->status;

        $parcel->update([
            'status' => ParcelStatus::Cancelled->value,
            'cancelled_at' => now(),
            'cancellation_reason' => $reason,
        ]);

        $driver = $parcel->driverProfile;

        if ($driver !== null && $parcel->partner_amount > 0) {
            $this->finance->debitPending(
                $this->finance->walletFor($driver),
                (int) $parcel->partner_amount,
                'parcel_driver_reversal',
                $parcel->id,
                'Annulation colis — '.$parcel->reference,
            );
        }

        $this->logTransition($parcel, $from, ParcelStatus::Cancelled, $actorType, $actorId, $reason);

        return $parcel->fresh(['statusHistory']);
    }

    /** Colis payés en attente d'un livreur. @return Collection<int, Parcel> */
    public function availableOffers(): Collection
    {
        return Parcel::query()
            ->whereNull('driver_profile_id')
            ->where('status', ParcelStatus::Paid->value)
            ->orderByDesc('created_at')
            ->get();
    }

    /** Colis du livreur. @return Collection<int, Parcel> */
    public function driverParcels(DriverProfile $driver): Collection
    {
        return Parcel::query()
            ->where('driver_profile_id', $driver->id)
            ->orderByDesc('created_at')
            ->get();
    }

    /** Expire les colis non payés. @return int */
    public function expireUnpaidParcels(): int
    {
        $parcels = Parcel::query()
            ->where('status', ParcelStatus::AwaitingPayment->value)
            ->where('payment_deadline_at', '<', now())
            ->get();

        foreach ($parcels as $parcel) {
            $parcel->update([
                'status' => ParcelStatus::Cancelled->value,
                'payment_status' => PaymentStatus::Expired->value,
                'cancelled_at' => now(),
                'cancellation_reason' => 'Paiement non reçu avant la date limite.',
            ]);

            $parcel->payment?->update(['status' => PaymentStatus::Expired->value]);

            $this->logTransition($parcel, ParcelStatus::AwaitingPayment, ParcelStatus::Cancelled, 'system', null, 'paiement expiré');
        }

        return $parcels->count();
    }

    /** @param array<string, mixed> $extra */
    private function transition(Parcel $parcel, ParcelStatus $target, string $actorType, ?string $actorId, array $extra = []): Parcel
    {
        $this->assertTransition($parcel, $target);

        $from = $parcel->status;

        $parcel->update(array_merge(['status' => $target->value], $extra));

        $this->logTransition($parcel, $from, $target, $actorType, $actorId, null);

        return $parcel->fresh(['statusHistory']);
    }

    private function assertTransition(Parcel $parcel, ParcelStatus $target): void
    {
        $allowed = [
            ParcelStatus::Paid->value => [ParcelStatus::Assigned->value, ParcelStatus::Cancelled->value],
            ParcelStatus::Assigned->value => [ParcelStatus::PickedUp->value, ParcelStatus::Cancelled->value],
            ParcelStatus::PickedUp->value => [ParcelStatus::InDelivery->value, ParcelStatus::Cancelled->value],
            ParcelStatus::InDelivery->value => [ParcelStatus::Delivered->value, ParcelStatus::Cancelled->value],
        ];

        if (! in_array($target->value, $allowed[$parcel->status->value] ?? [], true)) {
            throw new DomainException('parcel.invalid_transition', 'Transition de statut non autorisée ('.$parcel->status->value.' → '.$target->value.').', 409);
        }
    }

    private function logTransition(Parcel $parcel, ?ParcelStatus $from, ParcelStatus $to, ?string $actorType, ?string $actorId, ?string $reason): void
    {
        $parcel->statusHistory()->create([
            'from_status' => $from?->value,
            'to_status' => $to->value,
            'actor_type' => $actorType,
            'actor_id' => $actorId,
            'reason' => $reason,
            'created_at' => now(),
        ]);
    }

    private function generateReference(): string
    {
        do {
            $reference = 'COL-'.now()->format('ymd').'-'.Str::upper(Str::random(6));
        } while (Parcel::where('reference', $reference)->exists());

        return $reference;
    }
}
