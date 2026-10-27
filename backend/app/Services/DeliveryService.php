<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\DriverStatus;
use App\Enums\OrderStatus;
use App\Exceptions\DomainException;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Order;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Livraisons temps réel (M9 — J97 à J106) : disponibilité du livreur,
 * propositions de courses, acceptation, ramassage, livraison et incidents.
 */
class DeliveryService
{
    public function __construct(
        private readonly OrderService $orders,
        private readonly DriverAvailabilityService $availability,
        private readonly DriverSelectionService $driverSelection,
    ) {}

    /**
     * Bascule la disponibilité du livreur et journalise le changement.
     *
     * @param  array{latitude?: float, longitude?: float}  $location
     */
    public function toggleAvailability(DriverProfile $profile, bool $online, array $location = []): DriverProfile
    {
        // Seul un compte actif peut recevoir des missions (voir
        // DriverAvailabilityService::assertCanAccept) : refuser tôt évite qu'un
        // livreur « validé » se croie en ligne sans jamais être proposé.
        if ($profile->status !== DriverStatus::Active->value) {
            throw new DomainException(
                'delivery.driver_inactive',
                'Votre compte livreur doit être activé par la plateforme avant de passer en ligne.',
                409,
            );
        }

        $wasOnline = (bool) $profile->available;

        if (! $online) {
            $profile->update([
                'available' => false,
                'last_latitude' => null,
                'last_longitude' => null,
                'last_location_at' => null,
                'last_heading' => null,
            ]);
        } else {
            $latitude = $location['latitude'] ?? null;
            $longitude = $location['longitude'] ?? null;
            $hasPosition = $latitude !== null && $longitude !== null;

            $profile->update([
                'available' => true,
                'last_latitude' => $hasPosition ? $latitude : $profile->last_latitude,
                'last_longitude' => $hasPosition ? $longitude : $profile->last_longitude,
                // Sans nouvelle position, on ne rafraîchit pas l'horodatage :
                // une coordonnée périmée ne doit jamais paraître « fraîche ».
                'last_location_at' => $hasPosition ? now() : $profile->last_location_at,
            ]);

            if (! $hasPosition) {
                Log::info('driver.availability.online_without_position', [
                    'driver_profile_id' => $profile->id,
                    'has_previous_position' => $profile->last_latitude !== null
                        && $profile->last_longitude !== null,
                ]);
            }
        }

        $profile->availabilityLogs()->create([
            'was_online' => $wasOnline,
            'to_online' => $online,
            'changed_at' => now(),
        ]);

        return $profile->fresh();
    }

    /**
     * Met à jour la position GPS du livreur (J175).
     *
     * Le cap (`last_heading`) est déduit du déplacement depuis la position
     * précédente, pour orienter le marqueur côté client. Il est conservé si le
     * livreur ne s'est pas déplacé de manière significative.
     *
     * @param  array{latitude: float, longitude: float}  $location
     */
    public function updateLocation(DriverProfile $profile, array $location): DriverProfile
    {
        $heading = $this->headingBetween(
            $profile->last_latitude !== null ? (float) $profile->last_latitude : null,
            $profile->last_longitude !== null ? (float) $profile->last_longitude : null,
            $location['latitude'],
            $location['longitude'],
        );

        $profile->update([
            'last_latitude' => $location['latitude'],
            'last_longitude' => $location['longitude'],
            'last_location_at' => now(),
            'last_heading' => $heading ?? $profile->last_heading,
        ]);

        $this->recordLocations($profile, $location);

        return $profile->fresh();
    }

    /**
     * Journalise le relevé GPS pour chaque course active du livreur
     * (historique de suivi, purgé par `deliveries:purge-locations`).
     *
     * @param  array{latitude: float, longitude: float}  $location
     */
    private function recordLocations(DriverProfile $profile, array $location): void
    {
        $activeDeliveries = $profile->deliveries()
            ->whereIn('status', [
                DeliveryStatus::Assigned,
                DeliveryStatus::EnRoutePickup,
                DeliveryStatus::PickedUp,
                DeliveryStatus::InDelivery,
            ])
            ->get();

        if ($activeDeliveries->isEmpty()) {
            return;
        }

        $recordedAt = now();

        foreach ($activeDeliveries as $delivery) {
            $delivery->locations()->create([
                'driver_profile_id' => $profile->id,
                'latitude' => $location['latitude'],
                'longitude' => $location['longitude'],
                'heading' => $profile->last_heading,
                'recorded_at' => $recordedAt,
            ]);
        }
    }

    /**
     * Cap en degrés (0 = Nord) entre deux positions, ou `null` si le déplacement
     * est trop faible pour être significatif (< ~5 m).
     */
    private function headingBetween(?float $fromLat, ?float $fromLng, float $toLat, float $toLng): ?float
    {
        if ($fromLat === null || $fromLng === null) {
            return null;
        }

        $dLat = $toLat - $fromLat;
        $dLng = $toLng - $fromLng;
        if (abs($dLat) < 0.000045 && abs($dLng) < 0.000045) {
            return null;
        }

        $fromLatRad = deg2rad($fromLat);
        $toLatRad = deg2rad($toLat);
        $dLngRad = deg2rad($dLng);

        $y = sin($dLngRad) * cos($toLatRad);
        $x = cos($fromLatRad) * sin($toLatRad) - sin($fromLatRad) * cos($toLatRad) * cos($dLngRad);

        return round((rad2deg(atan2($y, $x)) + 360) % 360, 2);
    }

    /**
     * Courses en attente d'un livreur (commande prête, course ouverte).
     *
     * @return Collection<int, Delivery>
     */
    public function availableOffers(?DriverProfile $driver = null): Collection
    {
        $this->driverSelection->expireStale();

        return Delivery::query()
            ->whereNull('driver_profile_id')
            ->where('status', DeliveryStatus::Assigned->value)
            ->whereHas('order', fn ($query) => $query->where('status', OrderStatus::Ready->value))
            ->when($driver !== null, fn ($query) => $query->where(function ($inner) use ($driver): void {
                $inner->whereNull('targeted_driver_profile_id')
                    ->orWhere('targeted_driver_profile_id', $driver->id);
            }))
            ->with(['order.vendor', 'order.user', 'order.financials', 'vendor', 'zone'])
            ->orderByDesc('created_at')
            ->get();
    }

    /**
     * Le livreur accepte une course : assignation + transition ordre → assigned.
     */
    public function acceptOffer(Delivery $delivery, DriverProfile $driver): Delivery
    {
        return DB::transaction(function () use ($delivery, $driver): Delivery {
            $lockedDelivery = Delivery::query()->whereKey($delivery->id)->lockForUpdate()->firstOrFail();
            $lockedDelivery->load('order');

            $lockedDriver = DriverProfile::query()->whereKey($driver->id)->lockForUpdate()->firstOrFail();

            $this->assertOfferOpen($lockedDelivery, $lockedDriver);
            $this->availability->assertCanAccept($lockedDriver);

            /** @var Order $order */
            $order = Order::query()->whereKey($lockedDelivery->order_id)->lockForUpdate()->firstOrFail();
            $lockedDelivery->setRelation('order', $order);

            // Seconde vérification avec la commande verrouillée : évite qu'une
            // annulation ou une affectation concurrente passe entre-temps.
            $this->assertOfferOpen($lockedDelivery, $lockedDriver);

            $this->orders->assignDriver($order, $lockedDriver->id, $lockedDriver->user_id);
            $this->driverSelection->markAccepted($order, $lockedDriver);

            $lockedDelivery->refresh();

            $lockedDelivery->statusHistory()->create([
                'from_status' => DeliveryStatus::Assigned->value,
                'to_status' => DeliveryStatus::Assigned->value,
                'actor' => 'driver',
                'reason' => 'Course acceptée par le livreur',
                'created_at' => now(),
            ]);

            return $lockedDelivery->fresh(['order.vendor', 'order.user', 'order.financials', 'vendor', 'driverProfile.user']);
        });
    }

    /**
     * Le livreur décline une course : la demande ciblée est close et la course
     * est laissée ouverte pour un autre livreur.
     */
    public function declineOffer(Delivery $delivery, DriverProfile $driver, ?string $reason = null): Delivery
    {
        return DB::transaction(function () use ($delivery, $driver, $reason): Delivery {
            $lockedDelivery = Delivery::query()->whereKey($delivery->id)->lockForUpdate()->firstOrFail();
            $lockedDelivery->load('order');

            $lockedDriver = DriverProfile::query()->whereKey($driver->id)->lockForUpdate()->firstOrFail();

            $this->assertOfferOpen($lockedDelivery, $lockedDriver);

            $this->driverSelection->markRefused($lockedDelivery->order, $lockedDriver, $reason);

            $lockedDelivery->update(['targeted_driver_profile_id' => null]);

            $lockedDelivery->statusHistory()->create([
                'from_status' => DeliveryStatus::Assigned->value,
                'to_status' => DeliveryStatus::Assigned->value,
                'actor' => 'driver',
                'reason' => $reason !== null && $reason !== '' ? 'Course déclinée : '.$reason : 'Course déclinée par le livreur',
                'created_at' => now(),
            ]);

            return $lockedDelivery->fresh();
        });
    }

    /**
     * Le livreur démarre le trajet vers le point de collecte
     * (assigned → en_route_pickup). La commande reste au statut « assigned »
     * jusqu'à la confirmation effective du ramassage.
     */
    public function markEnRoutePickup(Delivery $delivery, DriverProfile $driver): Delivery
    {
        $this->assertDeliveryOwned($delivery, $driver);

        if ($delivery->status !== DeliveryStatus::Assigned) {
            throw new DomainException(
                'delivery.invalid_transition',
                'Cette course ne peut plus être démarrée vers la collecte.',
                409,
            );
        }

        $delivery->update(['status' => DeliveryStatus::EnRoutePickup->value]);
        $delivery->statusHistory()->create([
            'from_status' => DeliveryStatus::Assigned->value,
            'to_status' => DeliveryStatus::EnRoutePickup->value,
            'actor' => 'driver',
            'reason' => 'Trajet vers le point de collecte démarré',
            'created_at' => now(),
        ]);

        return $delivery->fresh(['order.vendor', 'order.user', 'order.financials', 'vendor', 'driverProfile.user']);
    }

    /**
     * Confirme le ramassage (assigned ou en_route_pickup → picked_up).
     */
    public function markPickedUp(Delivery $delivery, DriverProfile $driver): Delivery
    {
        $this->assertDeliveryOwned($delivery, $driver);

        if (! in_array($delivery->status, [DeliveryStatus::Assigned, DeliveryStatus::EnRoutePickup], true)) {
            throw new DomainException(
                'delivery.invalid_transition',
                'Cette course ne peut plus être marquée comme récupérée.',
                409,
            );
        }

        $from = $delivery->status;

        $delivery->order->load('delivery');
        $this->orders->markPickedUp($delivery->order, $driver->user_id);

        $delivery->refresh();
        $delivery->statusHistory()->create([
            'from_status' => $from->value,
            'to_status' => DeliveryStatus::PickedUp->value,
            'actor' => 'driver',
            'reason' => null,
            'created_at' => now(),
        ]);

        return $delivery->fresh(['order.vendor', 'order.user', 'order.financials', 'vendor', 'driverProfile.user']);
    }

    /**
     * Démarre la course vers le client (picked_up → in_delivery).
     */
    public function markInDelivery(Delivery $delivery, DriverProfile $driver): Delivery
    {
        $this->assertDeliveryOwned($delivery, $driver);

        $delivery->order->load('delivery');
        $this->orders->markInDelivery($delivery->order, $driver->user_id);

        $delivery->refresh();
        $delivery->statusHistory()->create([
            'from_status' => DeliveryStatus::PickedUp->value,
            'to_status' => DeliveryStatus::InDelivery->value,
            'actor' => 'driver',
            'reason' => null,
            'created_at' => now(),
        ]);

        return $delivery->fresh(['order.vendor', 'order.user', 'order.financials', 'vendor', 'driverProfile.user']);
    }

    /**
     * Confirme la livraison au client (in_delivery → delivered).
     *
     * Le code de confirmation fourni par le client est obligatoire : sans lui,
     * aucun fonds n'est libéré.
     *
     * @param  array{proof_code?: string, proof_photo?: string}  $proof
     */
    public function markDelivered(Delivery $delivery, DriverProfile $driver, array $proof = []): Delivery
    {
        $this->assertDeliveryOwned($delivery, $driver);

        $code = trim((string) ($proof['proof_code'] ?? ''));

        if ($code === '') {
            throw new DomainException(
                'delivery.confirmation_code_required',
                'Saisissez le code de confirmation fourni par le client.',
                422,
            );
        }

        $delivery->order->load('delivery');
        $this->orders->markDelivered($delivery->order, $code, $driver->user_id);

        $delivery->refresh();
        $delivery->update([
            'proof_photo_path' => $proof['proof_photo'] ?? $delivery->proof_photo_path,
        ]);

        // Fin de course : on efface la dernière position partagée (protection des
        // données de localisation — le client ne doit plus voir le livreur).
        $driver->update([
            'last_latitude' => null,
            'last_longitude' => null,
            'last_location_at' => null,
            'last_heading' => null,
        ]);

        $delivery->statusHistory()->create([
            'from_status' => DeliveryStatus::InDelivery->value,
            'to_status' => DeliveryStatus::Delivered->value,
            'actor' => 'driver',
            'reason' => null,
            'created_at' => now(),
        ]);

        return $delivery->fresh(['order.vendor', 'order.user', 'order.financials', 'vendor', 'driverProfile.user']);
    }

    /**
     * Signale un incident sur une course en cours.
     */
    public function reportIncident(Delivery $delivery, DriverProfile $driver, string $message): Delivery
    {
        if ($delivery->driver_profile_id !== $driver->id) {
            throw new DomainException('delivery.not_owned', 'Cette course ne vous appartient pas.', 404);
        }

        if (in_array($delivery->status, [DeliveryStatus::Delivered, DeliveryStatus::Cancelled], true)) {
            throw new DomainException('delivery.already_closed', 'Cette course est déjà terminée.', 422);
        }

        $delivery->statusHistory()->create([
            'from_status' => $delivery->status->value,
            'to_status' => $delivery->status->value,
            'actor' => 'driver',
            'reason' => 'Incident : '.$message,
            'created_at' => now(),
        ]);

        return $delivery->fresh();
    }

    /**
     * Historique des courses du livreur (actives + terminées).
     *
     * @return Collection<int, Delivery>
     */
    public function driverDeliveries(DriverProfile $driver): Collection
    {
        return Delivery::query()
            ->where('driver_profile_id', $driver->id)
            ->with(['order.vendor', 'order.user', 'vendor', 'statusHistory'])
            ->orderByDesc('created_at')
            ->get();
    }

    private function assertOfferOpen(Delivery $delivery, ?DriverProfile $driver = null): void
    {
        if ($delivery->driver_profile_id !== null) {
            throw new DomainException('delivery.already_taken', 'Cette course a déjà été prise.', 409);
        }

        if ($delivery->targeted_driver_profile_id !== null && $driver !== null && $delivery->targeted_driver_profile_id !== $driver->id) {
            throw new DomainException('delivery.reserved', 'Cette course est réservée à un autre livreur.', 409);
        }

        if ($delivery->status !== DeliveryStatus::Assigned || ! $delivery->order?->isReady()) {
            throw new DomainException('delivery.not_open', 'Cette course n\'est plus disponible.', 409);
        }
    }

    private function assertDeliveryOwned(Delivery $delivery, DriverProfile $driver): void
    {
        if ($delivery->driver_profile_id !== $driver->id) {
            throw new DomainException('delivery.not_owned', 'Cette course ne vous appartient pas.', 404);
        }
    }
}
