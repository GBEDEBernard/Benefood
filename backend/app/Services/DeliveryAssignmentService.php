<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Exceptions\DomainException;
use App\Models\Delivery;
use App\Models\DeliveryAssignment;
use App\Models\DeliveryIncident;
use App\Models\DeliveryReassignmentRequest;
use App\Models\DriverProfile;
use App\Models\Order;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Découpage financier des livraisons lorsqu'un livreur est remplacé.
 *
 * Une seule course existe côté client (`Delivery`), mais chaque livreur
 * possède un segment (`DeliveryAssignment`) avec ses distances, sa part de
 * base et sa part d'approche. Les montants restent figés : le client ne paie
 * jamais deux fois les frais d'approche, la plateforme absorbe le surplus.
 */
class DeliveryAssignmentService
{
    public function __construct(
        private readonly DeliveryPricingService $pricing,
        private readonly DriverSelectionService $selection,
        private readonly FinanceService $finance,
        private readonly NotificationService $notifications,
        private readonly CashService $cash,
    ) {}

    /** Crée le segment initial quand un livreur accepte la course. */
    public function start(Delivery $delivery, DriverProfile $driver, ?string $notes = null): DeliveryAssignment
    {
        $delivery->loadMissing('order.financials', 'assignments');

        $existing = $delivery->assignments
            ->first(fn (DeliveryAssignment $item) => in_array($item->status, [
                DeliveryAssignment::STATUS_ACTIVE,
                DeliveryAssignment::STATUS_PENDING_HANDOVER,
            ], true));

        if ($existing !== null) {
            return $existing;
        }

        $order = $delivery->order;

        return DB::transaction(function () use ($delivery, $driver, $notes, $order): DeliveryAssignment {
            $financials = $order?->financials;
            $baseFee = (int) ($order?->delivery_fee ?? $delivery->fee ?? 0);
            $approachFee = (int) ($order?->approach_fee ?? 0);
            $gross = $baseFee + $approachFee;
            $commission = (int) ($financials?->delivery_commission_amount ?? 0);
            $partner = max(0, $gross - $commission);
            $basePartner = (int) ($financials?->base_partner_amount ?? ($gross > 0 ? round($partner * $baseFee / $gross) : 0));
            $approachPartner = max(0, $partner - $basePartner);

            $sequence = ((int) $delivery->assignments()->max('sequence')) + 1;
            $baseDistance = $this->baseDistance($delivery, $order);

            $assignment = $delivery->assignments()->create([
                'order_id' => $delivery->order_id,
                'driver_profile_id' => $driver->id,
                'sequence' => $sequence,
                'status' => DeliveryAssignment::STATUS_ACTIVE,
                'base_fee' => $baseFee,
                'approach_fee' => $approachFee,
                'gross_amount' => $gross,
                'commission_amount' => $commission,
                'partner_amount' => $partner,
                'base_partner_amount' => $basePartner,
                'approach_partner_amount' => $approachPartner,
                'base_distance_km' => $baseDistance,
                'approach_distance_km' => $order?->approach_distance_km,
                'accepted_at' => now(),
                'handover_latitude' => $delivery->pickup_latitude,
                'handover_longitude' => $delivery->pickup_longitude,
                'notes' => $notes,
            ]);

            $delivery->update([
                'fee' => $gross,
                'partner_amount' => $partner,
            ]);

            $this->finance->creditDriverForDelivery($order, $driver);

            return $assignment->fresh();
        });
    }

    /**
     * Libère une course acceptée avant tout ramassage : le segment est annulé
     * et le séquestre du livreur est contre-passé. Aucun frais n'est dû.
     */
    public function cancelBeforePickup(Delivery $delivery, DriverProfile $driver, string $reason): void
    {
        $delivery->loadMissing('order', 'assignments');

        $assignment = $delivery->assignments->first(
            fn (DeliveryAssignment $item) => $item->driver_profile_id === $driver->id
                && $item->status === DeliveryAssignment::STATUS_ACTIVE,
        );

        DB::transaction(function () use ($delivery, $driver, $reason, $assignment): void {
            if ($assignment !== null) {
                $assignment->update([
                    'status' => DeliveryAssignment::STATUS_CANCELLED,
                    'completed_at' => now(),
                    'notes' => $reason,
                ]);

                if (! $delivery->order?->payment_method?->isCash()) {
                    $this->finance->debitPending(
                        $this->finance->walletFor($driver),
                        (int) $assignment->gross_amount,
                        'order_driver_release',
                        $assignment->id,
                        'Course libérée avant collecte — '.$delivery->order?->reference,
                    );
                }
            }

            $delivery->update([
                'driver_profile_id' => null,
                'targeted_driver_profile_id' => null,
                'status' => DeliveryStatus::Assigned->value,
                'assigned_at' => null,
            ]);
        });
    }

    /**
     * Remplace un livreur avant tout ramassage (incident sur le trajet vers la
     * boutique). Le nouveau segment repart du point de collecte, sans code de
     * remise : le colis n'a pas encore changé de mains.
     */
    public function reassignBeforePickup(
        Delivery $delivery,
        DriverProfile $newDriver,
        string $reason,
        ?DeliveryIncident $incident = null,
    ): DeliveryAssignment {
        $delivery->loadMissing('order.financials', 'assignments', 'driverProfile');

        if ($delivery->reassignment_count >= 2) {
            throw new DomainException(
                'delivery.reassignment_limit',
                'Cette course a déjà été réassignée deux fois. La porteuse doit intervenir.',
                409,
            );
        }

        $oldDriver = $delivery->driverProfile;

        if ($oldDriver === null) {
            throw new DomainException('delivery.no_driver', 'Aucun livreur à remplacer sur cette course.', 409);
        }

        if ($oldDriver->id === $newDriver->id) {
            throw new DomainException('delivery.same_driver', 'Choisissez un autre livreur.', 422);
        }

        $order = $delivery->order;

        if ($order?->payment_method?->isCash() && ! $this->cash->hasCoverage($newDriver, $order)) {
            throw new DomainException(
                'cash.insufficient_float',
                'Flottant insuffisant pour reprendre cette commande payée en espèces ('.(int) $order->total.' F requis).',
                409,
            );
        }

        $pickupLatitude = $delivery->pickup_latitude;
        $pickupLongitude = $delivery->pickup_longitude;

        if ($pickupLatitude === null || $pickupLongitude === null) {
            throw new DomainException(
                'delivery.pickup_location_required',
                'La position du point de collecte est indisponible.',
                422,
            );
        }

        $this->selection->assertSelectableAt($newDriver, (float) $pickupLatitude, (float) $pickupLongitude);

        return DB::transaction(function () use ($delivery, $newDriver, $reason, $incident, $oldDriver, $pickupLatitude, $pickupLongitude): DeliveryAssignment {
            $current = $delivery->assignments
                ->first(fn (DeliveryAssignment $item) => $item->driver_profile_id === $oldDriver->id
                    && $item->status === DeliveryAssignment::STATUS_ACTIVE);

            if ($current !== null) {
                $current->update([
                    'status' => DeliveryAssignment::STATUS_CANCELLED,
                    'completed_at' => now(),
                    'notes' => $reason,
                ]);

                if (! $delivery->order?->payment_method?->isCash()) {
                    $this->finance->debitPending(
                        $this->finance->walletFor($oldDriver),
                        (int) $current->gross_amount,
                        'order_driver_release',
                        $current->id,
                        'Course réassignée avant collecte — '.$delivery->order?->reference,
                    );
                }
            }

            $delivery->unsetRelation('assignments');
            $delivery->update([
                'driver_profile_id' => $newDriver->id,
                'targeted_driver_profile_id' => null,
                'status' => DeliveryStatus::Assigned->value,
                'assigned_at' => now(),
                'reassignment_count' => (int) $delivery->reassignment_count + 1,
            ]);

            $assignment = $this->start($delivery->fresh('assignments'), $newDriver, $reason);

            DeliveryReassignmentRequest::create([
                'delivery_id' => $delivery->id,
                'order_id' => $delivery->order_id,
                'incident_id' => $incident?->id,
                'client_id' => $delivery->order?->user_id,
                'old_driver_profile_id' => $oldDriver->id,
                'new_driver_profile_id' => $newDriver->id,
                'status' => 'accepted',
                'reason' => $reason,
                'handover_latitude' => $pickupLatitude,
                'handover_longitude' => $pickupLongitude,
                'responded_at' => now(),
            ]);

            $newDriver->loadMissing('user');

            if ($newDriver->user !== null) {
                $this->notifications->notifyEvent('delivery.reassigned', [$newDriver->user], [
                    'reference' => $delivery->order?->reference,
                    'order_id' => $delivery->order_id,
                    'delivery_id' => $delivery->id,
                ]);
            }

            return $assignment->fresh();
        });
    }

    /**
     * Remplace le livreur en cours de livraison. L'ancien segment est figé au
     * prorata de la distance parcourue, le nouveau reçoit le reste.
     */
    public function reassign(
        Delivery $delivery,
        DriverProfile $newDriver,
        float $handoverLatitude,
        float $handoverLongitude,
        string $reason,
        ?DeliveryIncident $incident = null,
    ): DeliveryAssignment {
        $delivery->loadMissing('order.financials', 'assignments', 'driverProfile');

        if ($delivery->reassignment_count >= 2) {
            throw new DomainException(
                'delivery.reassignment_limit',
                'Cette course a déjà été réassignée deux fois. La porteuse doit intervenir.',
                409,
            );
        }

        $oldDriver = $delivery->driverProfile;

        if ($oldDriver === null) {
            throw new DomainException('delivery.no_driver', 'Aucun livreur à remplacer sur cette course.', 409);
        }

        if ($oldDriver->id === $newDriver->id) {
            throw new DomainException('delivery.same_driver', 'Choisissez un autre livreur.', 422);
        }

        $order = $delivery->order;

        if ($order?->payment_method?->isCash() && ! $this->cash->hasCoverage($newDriver, $order)) {
            throw new DomainException(
                'cash.insufficient_float',
                'Flottant insuffisant pour reprendre cette commande payée en espèces ('.(int) $order->total.' F requis).',
                409,
            );
        }

        $this->selection->assertSelectableAt($newDriver, $handoverLatitude, $handoverLongitude);

        return DB::transaction(function () use ($delivery, $newDriver, $handoverLatitude, $handoverLongitude, $reason, $incident, $oldDriver): DeliveryAssignment {
            $current = $delivery->assignments
                ->first(fn (DeliveryAssignment $item) => in_array($item->status, [
                    DeliveryAssignment::STATUS_ACTIVE,
                    DeliveryAssignment::STATUS_PENDING_HANDOVER,
                ], true));

            if ($current === null) {
                $current = $this->start($delivery, $oldDriver);
            }

            $originalBaseFee = (int) $current->base_fee;
            $originalApproachFee = (int) $current->approach_fee;
            $originalGross = (int) $current->gross_amount;
            $originalCommission = (int) $current->commission_amount;
            $originalPartner = (int) $current->partner_amount;
            $originalBasePartner = (int) $current->base_partner_amount;
            $originalApproachPartner = (int) $current->approach_partner_amount;

            $order = $delivery->order;
            $dropoff = $this->dropoffPoint($order);
            $newBaseDistance = $this->distance($handoverLatitude, $handoverLongitude, $dropoff['latitude'] ?? null, $dropoff['longitude'] ?? null);
            $previousHandoverLatitude = $current->handover_latitude ?? $delivery->pickup_latitude;
            $previousHandoverLongitude = $current->handover_longitude ?? $delivery->pickup_longitude;
            $oldBaseDistance = $this->distance($previousHandoverLatitude, $previousHandoverLongitude, $handoverLatitude, $handoverLongitude);

            if ($oldBaseDistance === null) {
                $oldBaseDistance = (float) ($current->base_distance_km ?? 0);
            }

            if ($newBaseDistance === null) {
                $newBaseDistance = 0.0;
            }

            $newApproachDistance = $this->distance(
                $newDriver->last_latitude,
                $newDriver->last_longitude,
                $handoverLatitude,
                $handoverLongitude,
            ) ?? 0.0;
            $oldApproachDistance = (float) ($current->approach_distance_km ?? 0);

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
                'status' => DeliveryAssignment::STATUS_REASSIGNED,
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

            $assignment = $delivery->assignments()->create([
                'order_id' => $delivery->order_id,
                'driver_profile_id' => $newDriver->id,
                'sequence' => ((int) $delivery->assignments()->max('sequence')) + 1,
                'status' => DeliveryAssignment::STATUS_PENDING_HANDOVER,
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

            if ($overCredit > 0) {
                $this->finance->debitPending(
                    $this->finance->walletFor($oldDriver),
                    $overCredit,
                    'order_driver_split',
                    $current->id,
                    'Répartition course réassignée — '.$order->reference,
                );
            }

            $delivery->update([
                'driver_profile_id' => $newDriver->id,
                'targeted_driver_profile_id' => null,
                'reassignment_count' => (int) $delivery->reassignment_count + 1,
                'partner_amount' => (int) $delivery->assignments()->sum('partner_amount'),
            ]);

            DeliveryReassignmentRequest::create([
                'delivery_id' => $delivery->id,
                'order_id' => $delivery->order_id,
                'incident_id' => $incident?->id,
                'client_id' => $order->user_id,
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
                $this->notifications->notifyEvent('delivery.reassigned', [$newDriver->user], [
                    'reference' => $order->reference,
                    'order_id' => $order->id,
                    'delivery_id' => $delivery->id,
                    'handover_code' => $code,
                ]);
            }

            return $assignment->fresh();
        });
    }

    /** Le nouveau livreur confirme la remise avec le code communiqué. */
    public function confirmHandover(DeliveryAssignment $assignment, DriverProfile $driver, string $code): DeliveryAssignment
    {
        if ($assignment->driver_profile_id !== $driver->id) {
            throw new DomainException('delivery.not_owned', 'Ce segment ne vous appartient pas.', 404);
        }

        if ($assignment->status !== DeliveryAssignment::STATUS_PENDING_HANDOVER) {
            throw new DomainException('delivery.handover_not_expected', 'Aucune remise en attente pour ce segment.', 409);
        }

        if (trim($code) === '' || strtoupper(trim($code)) !== strtoupper((string) $assignment->handover_code)) {
            throw new DomainException('delivery.invalid_handover_code', 'Code de remise incorrect.', 422);
        }

        $assignment->update([
            'status' => DeliveryAssignment::STATUS_ACTIVE,
            'handover_confirmed_at' => now(),
        ]);

        $delivery = $assignment->delivery;
        $delivery?->loadMissing('order.financials');

        if ($delivery?->order !== null) {
            $this->finance->creditDriverForDelivery($delivery->order, $driver);
        }

        DeliveryReassignmentRequest::query()
            ->where('delivery_id', $assignment->delivery_id)
            ->where('new_driver_profile_id', $driver->id)
            ->where('status', 'accepted')
            ->latest()
            ->first()
            ?->update(['completed_at' => now()]);

        return $assignment->fresh();
    }

    /** Clôt le segment actif après livraison. */
    public function completeActive(Delivery $delivery): void
    {
        $delivery->loadMissing('order.financials', 'assignments.driverProfile');

        $pending = $delivery->assignments
            ->where('status', DeliveryAssignment::STATUS_PENDING_HANDOVER);

        foreach ($pending as $assignment) {
            $assignment->update([
                'status' => DeliveryAssignment::STATUS_ACTIVE,
                'handover_confirmed_at' => now(),
            ]);

            if ($delivery->order !== null && $assignment->driverProfile !== null) {
                $this->finance->creditDriverForDelivery($delivery->order, $assignment->driverProfile);
            }
        }

        $delivery->assignments()
            ->where('status', DeliveryAssignment::STATUS_ACTIVE)
            ->update([
                'status' => DeliveryAssignment::STATUS_COMPLETED,
                'completed_at' => now(),
            ]);
    }

    private function baseDistance(Delivery $delivery, ?Order $order): ?float
    {
        $snapshot = $delivery->order?->delivery_rate_snapshot ?? $order?->delivery_rate_snapshot;

        if (is_array($snapshot) && isset($snapshot['distance_km'])) {
            return (float) $snapshot['distance_km'];
        }

        $dropoff = $this->dropoffPoint($order);

        return $this->distance(
            $delivery->pickup_latitude,
            $delivery->pickup_longitude,
            $dropoff['latitude'] ?? null,
            $dropoff['longitude'] ?? null,
        );
    }

    /** @return array{latitude: mixed, longitude: mixed} */
    private function dropoffPoint(?Order $order): array
    {
        $address = $order?->address_snapshot ?? [];

        return [
            'latitude' => $address['latitude'] ?? null,
            'longitude' => $address['longitude'] ?? null,
        ];
    }

    private function distance(mixed $lat1, mixed $lng1, mixed $lat2, mixed $lng2): ?float
    {
        return $this->pricing->distanceKm($lat1, $lng1, $lat2, $lng2);
    }
}
