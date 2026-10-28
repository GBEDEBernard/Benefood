<?php

namespace App\Services;

use App\Enums\ParcelStatus;
use App\Exceptions\DomainException;
use App\Models\DriverProfile;
use App\Models\Parcel;
use App\Models\ParcelAssignment;
use App\Models\ParcelIncident;
use App\Models\ParcelReassignmentRequest;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Réassignation d'un colis déjà récupéré : partage du trajet au prorata,
 * code de remise et libération financière par segment.
 */
class ParcelReassignmentService
{
    public function __construct(
        private readonly DeliveryPricingService $pricing,
        private readonly DriverSelectionService $selection,
        private readonly FinanceService $finance,
        private readonly CashService $cash,
        private readonly NotificationService $notifications,
    ) {}

    /**
     * @return array{assignment: ParcelAssignment, reassignment: ParcelReassignmentRequest, handover_code: string}
     */
    public function reassign(
        Parcel $parcel,
        User $client,
        DriverProfile $newDriver,
        string $reason,
        ?float $latitude = null,
        ?float $longitude = null,
    ): array {
        if ($parcel->user_id !== $client->id) {
            throw new DomainException('parcel.not_found', 'Colis introuvable.', 404);
        }

        if (! in_array($parcel->status, [ParcelStatus::PickedUp, ParcelStatus::InDelivery], true)) {
            throw new DomainException(
                'parcel.reassignment_not_allowed',
                'Le remplacement du livreur est possible après le ramassage et avant la livraison.',
                409,
            );
        }

        $parcel->loadMissing(['driverProfile', 'assignments']);

        $oldDriver = $parcel->driverProfile;

        if ($oldDriver === null) {
            throw new DomainException('parcel.no_driver', 'Aucun livreur à remplacer sur ce colis.', 409);
        }

        if ($oldDriver->id === $newDriver->id) {
            throw new DomainException('parcel.same_driver', 'Choisissez un autre livreur.', 422);
        }

        if ((int) $parcel->reassignment_count >= 2) {
            throw new DomainException(
                'parcel.reassignment_limit',
                'Ce colis a déjà été réassigné deux fois. La porteuse doit intervenir.',
                409,
            );
        }

        $handoverLatitude = $latitude ?? $oldDriver->last_latitude;
        $handoverLongitude = $longitude ?? $oldDriver->last_longitude;

        if ($handoverLatitude === null || $handoverLongitude === null) {
            throw new DomainException(
                'parcel.handover_location_required',
                'La position de remise du colis est indisponible.',
                422,
            );
        }

        $this->selection->assertSelectableAt($newDriver, (float) $handoverLatitude, (float) $handoverLongitude);

        if ($parcel->isCash()) {
            $platformDue = (int) $parcel->platform_amount + (int) $parcel->creation_fee;

            if (! $this->cash->hasFloat($newDriver, $platformDue)) {
                throw new DomainException(
                    'parcel.cash_insufficient_float',
                    'Flottant insuffisant pour reprendre ce colis payé en espèces ('.$platformDue.' F requis).',
                    409,
                );
            }
        }

        return DB::transaction(function () use ($parcel, $client, $newDriver, $reason, $oldDriver, $handoverLatitude, $handoverLongitude): array {
            $current = $parcel->assignments
                ->first(fn (ParcelAssignment $item) => $item->status === ParcelAssignment::STATUS_ACTIVE);

            if ($current === null) {
                $pending = $parcel->assignments
                    ->first(fn (ParcelAssignment $item) => $item->status === ParcelAssignment::STATUS_PENDING_HANDOVER);

                if ($pending !== null) {
                    throw new DomainException(
                        'parcel.handover_required',
                        'Le livreur actuel doit d\'abord confirmer la remise du colis.',
                        409,
                    );
                }

                $current = $this->createInitialAssignment($parcel, $oldDriver);
            }

            $originalBaseFee = (int) $current->base_fee;
            $originalApproachFee = (int) $current->approach_fee;
            $originalGross = (int) $current->gross_amount;
            $originalCommission = (int) $current->commission_amount;
            $originalPartner = (int) $current->partner_amount;
            $originalBasePartner = (int) $current->base_partner_amount;
            $originalApproachPartner = (int) $current->approach_partner_amount;

            $pickup = $parcel->pickup_snapshot ?? [];
            $dropoff = $parcel->dropoff_snapshot ?? [];

            $oldBaseDistance = $this->distance(
                $pickup['latitude'] ?? null,
                $pickup['longitude'] ?? null,
                $handoverLatitude,
                $handoverLongitude,
            ) ?? 0.0;
            $newBaseDistance = $this->distance(
                $handoverLatitude,
                $handoverLongitude,
                $dropoff['latitude'] ?? null,
                $dropoff['longitude'] ?? null,
            ) ?? 0.0;
            $oldApproachDistance = (float) ($current->approach_distance_km ?? 0);
            $newApproachDistance = $this->distance(
                $newDriver->last_latitude,
                $newDriver->last_longitude,
                $handoverLatitude,
                $handoverLongitude,
            ) ?? 0.0;

            $baseTotalDistance = $oldBaseDistance + $newBaseDistance;
            $approachTotalDistance = $oldApproachDistance + $newApproachDistance;

            $oldBaseFee = $baseTotalDistance > 0
                ? (int) round($originalBaseFee * $oldBaseDistance / $baseTotalDistance)
                : 0;
            $oldApproachFee = $approachTotalDistance > 0
                ? (int) round($originalApproachFee * $oldApproachDistance / $approachTotalDistance)
                : $originalApproachFee;

            $oldGross = $oldBaseFee + $oldApproachFee;
            $newGross = max(0, $originalGross - $oldGross);

            $oldCommission = (int) ($originalGross > 0
                ? round($originalCommission * $oldGross / $originalGross)
                : 0);
            $newCommission = max(0, $originalCommission - $oldCommission);

            $oldPartner = max(0, $oldGross - $oldCommission);
            $newPartner = max(0, $newGross - $newCommission);

            $oldBasePartner = (int) ($originalBaseFee > 0
                ? round($originalBasePartner * $oldBaseFee / $originalBaseFee)
                : 0);
            $oldBasePartner = min($oldBasePartner, $oldPartner);
            $oldApproachPartner = max(0, $oldPartner - $oldBasePartner);
            $newBasePartner = max(0, $originalBasePartner - $oldBasePartner);
            $newApproachPartner = max(0, $originalApproachPartner - $oldApproachPartner);

            $current->update([
                'status' => ParcelAssignment::STATUS_REASSIGNED,
                'base_fee' => $oldBaseFee,
                'approach_fee' => $oldApproachFee,
                'gross_amount' => $oldGross,
                'commission_amount' => $oldCommission,
                'partner_amount' => $oldPartner,
                'base_partner_amount' => $oldBasePartner,
                'approach_partner_amount' => $oldApproachPartner,
                'base_distance_km' => round($oldBaseDistance, 3),
                'handover_latitude' => $handoverLatitude,
                'handover_longitude' => $handoverLongitude,
                'completed_at' => now(),
                'notes' => $reason,
            ]);

            $code = Str::upper(Str::random(6));

            $assignment = $parcel->assignments()->create([
                'driver_profile_id' => $newDriver->id,
                'sequence' => ((int) $parcel->assignments()->max('sequence')) + 1,
                'status' => ParcelAssignment::STATUS_PENDING_HANDOVER,
                'base_fee' => max(0, $originalBaseFee - $oldBaseFee),
                'approach_fee' => max(0, $originalApproachFee - $oldApproachFee),
                'gross_amount' => $newGross,
                'commission_amount' => $newCommission,
                'partner_amount' => $newPartner,
                'base_partner_amount' => $newBasePartner,
                'approach_partner_amount' => $newApproachPartner,
                'base_distance_km' => round($newBaseDistance, 3),
                'approach_distance_km' => round($newApproachDistance, 3),
                'handover_latitude' => $handoverLatitude,
                'handover_longitude' => $handoverLongitude,
                'handover_code' => $code,
                'accepted_at' => now(),
            ]);

            $overCredit = max(0, $originalGross - $oldGross);

            if (! $parcel->isCash() && $overCredit > 0) {
                $this->finance->debitPending(
                    $this->finance->walletFor($oldDriver),
                    $overCredit,
                    'parcel_driver_split',
                    $current->id,
                    'Répartition colis réassigné — '.$parcel->reference,
                );
            }

            $parcel->update([
                'driver_profile_id' => $newDriver->id,
                'targeted_driver_profile_id' => null,
                'reassignment_count' => (int) $parcel->reassignment_count + 1,
                'partner_amount' => (int) $parcel->assignments()->sum('partner_amount'),
            ]);

            $incident = ParcelIncident::create([
                'parcel_id' => $parcel->id,
                'reported_by_user_id' => $client->id,
                'driver_profile_id' => $oldDriver->id,
                'type' => 'reassignment',
                'message' => $reason,
                'status' => 'open',
                'metadata' => [
                    'handover_latitude' => $handoverLatitude,
                    'handover_longitude' => $handoverLongitude,
                ],
            ]);

            $reassignment = ParcelReassignmentRequest::create([
                'parcel_id' => $parcel->id,
                'incident_id' => $incident->id,
                'client_id' => $client->id,
                'old_driver_profile_id' => $oldDriver->id,
                'new_driver_profile_id' => $newDriver->id,
                'status' => 'accepted',
                'reason' => $reason,
                'handover_latitude' => $handoverLatitude,
                'handover_longitude' => $handoverLongitude,
                'handover_code' => $code,
                'responded_at' => now(),
            ]);

            $newDriver->loadMissing('user');

            if ($newDriver->user !== null) {
                $this->notifications->notifyEvent('parcel.reassigned', [$newDriver->user], [
                    'reference' => $parcel->reference,
                    'parcel_id' => $parcel->id,
                ]);
            }

            return [
                'assignment' => $assignment->fresh(),
                'reassignment' => $reassignment,
                'handover_code' => $code,
            ];
        });
    }

    public function reportIncident(Parcel $parcel, DriverProfile $driver, string $message, string $type = 'other'): Parcel
    {
        $this->assertOwned($parcel, $driver);

        if (in_array($parcel->status, [ParcelStatus::Delivered, ParcelStatus::Cancelled, ParcelStatus::Refunded], true)) {
            throw new DomainException('parcel.already_closed', 'Ce colis est déjà terminé.', 422);
        }

        ParcelIncident::create([
            'parcel_id' => $parcel->id,
            'reported_by_user_id' => $driver->user_id,
            'driver_profile_id' => $driver->id,
            'type' => $type,
            'message' => $message,
            'status' => 'open',
        ]);

        $parcel->statusHistory()->create([
            'from_status' => $parcel->status->value,
            'to_status' => $parcel->status->value,
            'actor_type' => 'driver',
            'actor_id' => $driver->user_id,
            'reason' => 'Incident : '.$message,
            'created_at' => now(),
        ]);

        return $parcel->fresh();
    }

    public function confirmHandover(Parcel $parcel, DriverProfile $driver, string $code): ParcelAssignment
    {
        $this->assertOwned($parcel, $driver);

        $assignment = $parcel->assignments()
            ->where('driver_profile_id', $driver->id)
            ->where('status', ParcelAssignment::STATUS_PENDING_HANDOVER)
            ->latest('sequence')
            ->first();

        if ($assignment === null) {
            throw new DomainException('parcel.handover_not_expected', 'Aucune remise en attente pour ce colis.', 409);
        }

        if (trim($code) === '' || strtoupper(trim($code)) !== strtoupper((string) $assignment->handover_code)) {
            throw new DomainException('parcel.invalid_handover_code', 'Code de remise incorrect.', 422);
        }

        $assignment->update([
            'status' => ParcelAssignment::STATUS_ACTIVE,
            'handover_confirmed_at' => now(),
        ]);

        if (! $parcel->isCash()) {
            $this->finance->creditParcelAssignment($assignment->fresh('driverProfile'));
        }

        ParcelIncident::query()
            ->where('parcel_id', $parcel->id)
            ->where('status', 'open')
            ->update(['status' => 'resolved']);

        ParcelReassignmentRequest::query()
            ->where('parcel_id', $parcel->id)
            ->where('new_driver_profile_id', $driver->id)
            ->where('status', 'accepted')
            ->latest()
            ->first()
            ?->update(['completed_at' => now()]);

        return $assignment->fresh();
    }

    /** Clôt les segments après livraison (remise implicite si nécessaire). */
    public function completeAssignments(Parcel $parcel): void
    {
        $parcel->loadMissing('assignments.driverProfile');

        foreach ($parcel->assignments->where('status', ParcelAssignment::STATUS_PENDING_HANDOVER) as $assignment) {
            $assignment->update([
                'status' => ParcelAssignment::STATUS_ACTIVE,
                'handover_confirmed_at' => now(),
            ]);

            if (! $parcel->isCash()) {
                $this->finance->creditParcelAssignment($assignment->fresh('driverProfile'));
            }
        }

        $parcel->assignments()
            ->where('status', ParcelAssignment::STATUS_ACTIVE)
            ->update([
                'status' => ParcelAssignment::STATUS_COMPLETED,
                'completed_at' => now(),
            ]);

        ParcelIncident::query()
            ->where('parcel_id', $parcel->id)
            ->where('status', 'open')
            ->update(['status' => 'resolved']);
    }

    private function createInitialAssignment(Parcel $parcel, DriverProfile $driver): ParcelAssignment
    {
        $baseFee = (int) $parcel->delivery_fee;
        $approachFee = (int) $parcel->approach_fee;
        $gross = $baseFee + $approachFee;
        $commission = (int) $parcel->commission_amount + (int) $parcel->approach_commission_amount;
        $partner = max(0, (int) $parcel->partner_amount);
        $approachPartner = min($partner, max(0, (int) $parcel->approach_partner_amount));
        $basePartner = max(0, $partner - $approachPartner);

        return $parcel->assignments()->create([
            'driver_profile_id' => $driver->id,
            'sequence' => ((int) $parcel->assignments()->max('sequence')) + 1,
            'status' => ParcelAssignment::STATUS_ACTIVE,
            'base_fee' => $baseFee,
            'approach_fee' => $approachFee,
            'gross_amount' => $gross,
            'commission_amount' => $commission,
            'partner_amount' => $partner,
            'base_partner_amount' => $basePartner,
            'approach_partner_amount' => $approachPartner,
            'base_distance_km' => $parcel->distance_km,
            'approach_distance_km' => $parcel->approach_distance_km,
            'accepted_at' => $parcel->assigned_at ?? now(),
        ]);
    }

    private function assertOwned(Parcel $parcel, DriverProfile $driver): void
    {
        if ($parcel->driver_profile_id !== $driver->id) {
            throw new DomainException('parcel.not_owned', 'Ce colis ne vous appartient pas.', 404);
        }
    }

    private function distance(mixed $lat1, mixed $lng1, mixed $lat2, mixed $lng2): ?float
    {
        return $this->pricing->distanceKm($lat1, $lng1, $lat2, $lng2);
    }
}
