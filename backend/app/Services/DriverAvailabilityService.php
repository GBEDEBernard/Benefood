<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\DriverStatus;
use App\Enums\ParcelStatus;
use App\Exceptions\DomainException;
use App\Models\DriverProfile;

/**
 * Règles communes d'acceptation d'une course (commande ou colis) : compte
 * en ligne, statut actif et nombre de missions simultanées.
 */
class DriverAvailabilityService
{
    public function __construct(private readonly PlatformPricingSettings $settings) {}

    /**
     * Statuts d'une livraison qui immobilisent le livreur.
     *
     * @var array<int, string>
     */
    public const ACTIVE_DELIVERY_STATUSES = [
        DeliveryStatus::Assigned->value,
        DeliveryStatus::EnRoutePickup->value,
        DeliveryStatus::PickedUp->value,
        DeliveryStatus::InDelivery->value,
    ];

    /**
     * Statuts d'un colis qui immobilisent le livreur.
     *
     * @var array<int, string>
     */
    public const ACTIVE_PARCEL_STATUSES = [
        ParcelStatus::Assigned->value,
        ParcelStatus::EnRoutePickup->value,
        ParcelStatus::PickedUp->value,
        ParcelStatus::InDelivery->value,
    ];

    public function maxActiveMissions(): int
    {
        return max(1, $this->settings->get('driver_max_active_missions'));
    }

    public function activeMissionsCount(DriverProfile $driver): int
    {
        $deliveries = $driver->deliveries()
            ->whereIn('status', self::ACTIVE_DELIVERY_STATUSES)
            ->count();

        $parcels = $driver->parcels()
            ->whereIn('status', self::ACTIVE_PARCEL_STATUSES)
            ->count();

        return $deliveries + $parcels;
    }

    public function hasCapacity(DriverProfile $driver): bool
    {
        return $this->activeMissionsCount($driver) < $this->maxActiveMissions();
    }

    /**
     * Vérifie qu'un livreur peut prendre une nouvelle mission.
     */
    public function assertCanAccept(DriverProfile $driver, bool $requireOnline = true): void
    {
        if ($requireOnline && ! (bool) $driver->available) {
            throw new DomainException('delivery.driver_offline', 'Activez votre disponibilité avant d\'accepter une course.', 409);
        }

        if ($driver->status !== DriverStatus::Active->value) {
            throw new DomainException('delivery.driver_inactive', 'Ce livreur ne peut pas accepter de courses.', 409);
        }

        $maxActive = $this->maxActiveMissions();

        if ($this->activeMissionsCount($driver) >= $maxActive) {
            throw new DomainException(
                'delivery.max_active_missions',
                "Vous avez déjà {$maxActive} mission(s) en cours. Terminez-en une avant d'en accepter une nouvelle.",
                409,
            );
        }
    }
}
