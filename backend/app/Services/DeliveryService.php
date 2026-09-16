<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\DriverStatus;
use App\Exceptions\DomainException;
use App\Models\Delivery;
use App\Models\DriverProfile;
use Illuminate\Database\Eloquent\Collection;

/**
 * Livraisons temps réel (M9 — J97 à J106) : disponibilité du livreur,
 * propositions de courses, acceptation, ramassage, livraison et incidents.
 */
class DeliveryService
{
    public function __construct(private readonly OrderService $orders) {}

    /**
     * Bascule la disponibilité du livreur et journalise le changement.
     *
     * @param  array{latitude?: float, longitude?: float}  $location
     */
    public function toggleAvailability(DriverProfile $profile, bool $online, array $location = []): DriverProfile
    {
        if (! in_array($profile->status, [DriverStatus::Active->value, DriverStatus::Validated->value], true)) {
            throw new DomainException('delivery.driver_inactive', 'Ce livreur ne peut pas accepter de courses.', 409);
        }

        $wasOnline = (bool) $profile->available;

        $profile->update([
            'available' => $online,
            'last_latitude' => $location['latitude'] ?? $profile->last_latitude,
            'last_longitude' => $location['longitude'] ?? $profile->last_longitude,
        ]);

        $profile->availabilityLogs()->create([
            'was_online' => $wasOnline,
            'to_online' => $online,
            'changed_at' => now(),
        ]);

        return $profile->fresh();
    }

    /**
     * Met à jour la position GPS du livreur.
     *
     * @param  array{latitude: float, longitude: float}  $location
     */
    public function updateLocation(DriverProfile $profile, array $location): DriverProfile
    {
        $profile->update([
            'last_latitude' => $location['latitude'],
            'last_longitude' => $location['longitude'],
        ]);

        return $profile->fresh();
    }

    /**
     * Courses en attente d'un livreur (commande prête, course ouverte).
     *
     * @return Collection<int, Delivery>
     */
    public function availableOffers(): Collection
    {
        return Delivery::query()
            ->whereNull('driver_profile_id')
            ->where('status', DeliveryStatus::Assigned->value)
            ->whereHas('order', fn ($query) => $query->where('status', OrderStatus::Ready->value))
            ->with(['order.vendor', 'order.user', 'vendor', 'zone'])
            ->orderByDesc('created_at')
            ->get();
    }

    /**
     * Le livreur accepte une course : assignation + transition ordre → assigned.
     */
    public function acceptOffer(Delivery $delivery, DriverProfile $driver): Delivery
    {
        $this->assertOfferOpen($delivery);

        $this->assertDriverAvailable($driver);

        $delivery->order->load('delivery');
        $this->orders->assignDriver($delivery->order, $driver->id, $driver->user_id);

        $delivery->refresh();

        $delivery->statusHistory()->create([
            'from_status' => DeliveryStatus::Assigned->value,
            'to_status' => DeliveryStatus::Assigned->value,
            'actor' => 'driver',
            'reason' => 'Course acceptée par le livreur',
            'created_at' => now(),
        ]);

        return $delivery->fresh(['order.vendor', 'order.user', 'vendor', 'driverProfile']);
    }

    /**
     * Le livreur décline une course : laissée ouverte pour un autre livreur.
     */
    public function declineOffer(Delivery $delivery, DriverProfile $driver, ?string $reason = null): Delivery
    {
        $this->assertOfferOpen($delivery);

        $delivery->statusHistory()->create([
            'from_status' => DeliveryStatus::Assigned->value,
            'to_status' => DeliveryStatus::Assigned->value,
            'actor' => 'driver',
            'reason' => $reason !== null && $reason !== '' ? 'Course déclinée : '.$reason : 'Course déclinée par le livreur',
            'created_at' => now(),
        ]);

        return $delivery->fresh();
    }

    /**
     * Confirme le ramassage (assigned → picked_up).
     */
    public function markPickedUp(Delivery $delivery, DriverProfile $driver): Delivery
    {
        $this->assertDeliveryOwned($delivery, $driver);

        $delivery->order->load('delivery');
        $this->orders->markPickedUp($delivery->order, $driver->user_id);

        $delivery->refresh();
        $delivery->statusHistory()->create([
            'from_status' => DeliveryStatus::Assigned->value,
            'to_status' => DeliveryStatus::PickedUp->value,
            'actor' => 'driver',
            'reason' => null,
            'created_at' => now(),
        ]);

        return $delivery->fresh(['order.vendor', 'order.user', 'vendor', 'driverProfile']);
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

        return $delivery->fresh(['order.vendor', 'order.user', 'vendor', 'driverProfile']);
    }

    /**
     * Confirme la livraison au client (in_delivery → delivered).
     *
     * @param  array{proof_code?: string, proof_photo?: string}  $proof
     */
    public function markDelivered(Delivery $delivery, DriverProfile $driver, array $proof = []): Delivery
    {
        $this->assertDeliveryOwned($delivery, $driver);

        $code = $proof['proof_code'] ?? null;

        if ($code !== null && $code !== '' && $delivery->proof_code !== null && $code !== $delivery->proof_code) {
            throw new DomainException('delivery.wrong_proof_code', 'Le code de confirmation ne correspond pas.', 422);
        }

        $delivery->order->load('delivery');
        $this->orders->markDelivered($delivery->order, $driver->user_id);

        $delivery->refresh();
        $delivery->update([
            'proof_code' => $delivery->proof_code ?? $code,
            'proof_photo_path' => $proof['proof_photo'] ?? $delivery->proof_photo_path,
        ]);

        $delivery->statusHistory()->create([
            'from_status' => DeliveryStatus::InDelivery->value,
            'to_status' => DeliveryStatus::Delivered->value,
            'actor' => 'driver',
            'reason' => null,
            'created_at' => now(),
        ]);

        return $delivery->fresh(['order.vendor', 'order.user', 'vendor', 'driverProfile']);
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

    private function assertOfferOpen(Delivery $delivery): void
    {
        if ($delivery->driver_profile_id !== null) {
            throw new DomainException('delivery.already_taken', 'Cette course a déjà été prise.', 409);
        }

        if ($delivery->status !== DeliveryStatus::Assigned || ! $delivery->order?->isReady()) {
            throw new DomainException('delivery.not_open', 'Cette course n\'est plus disponible.', 409);
        }
    }

    private function assertDriverAvailable(DriverProfile $driver): void
    {
        if (! (bool) $driver->available) {
            throw new DomainException('delivery.driver_offline', 'Activez votre disponibilité avant d\'accepter une course.', 409);
        }

        if ($driver->status !== DriverStatus::Active->value) {
            throw new DomainException('delivery.driver_inactive', 'Ce livreur ne peut pas accepter de courses.', 409);
        }
    }

    private function assertDeliveryOwned(Delivery $delivery, DriverProfile $driver): void
    {
        if ($delivery->driver_profile_id !== $driver->id) {
            throw new DomainException('delivery.not_owned', 'Cette course ne vous appartient pas.', 404);
        }
    }
}
