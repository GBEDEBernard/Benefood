<?php

namespace App\Services;

use App\Enums\FavoriteDriverStatus;
use App\Exceptions\DomainException;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\FavoriteDriver;
use App\Models\Parcel;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Database\Eloquent\Collection;

/**
 * Livreurs favoris (cahier v1.0) : un client ou une boutique peut ajouter les
 * livreurs qui lui ont déjà livré, avec l'accord du livreur. Les favoris
 * acceptés peuvent ensuite être visés pour une commande ou un colis.
 */
class FavoriteDriverService
{
    public function __construct(private readonly NotificationService $notifications) {}

    /**
     * Livreurs ayant déjà livré (ou accepté) une commande/colis de ce client ou
     * de cette boutique, hors favoris déjà enregistrés.
     *
     * @return Collection<int, DriverProfile>
     */
    public function candidatesFor(User $owner): Collection
    {
        $pastIds = $this->pastDriverProfileIds($owner);

        if ($pastIds === []) {
            return new Collection;
        }

        $known = $owner->favoriteDrivers()->pluck('driver_profile_id')->all();
        $remaining = array_values(array_diff($pastIds, $known));

        if ($remaining === []) {
            return new Collection;
        }

        return DriverProfile::query()
            ->whereIn('id', $remaining)
            ->with('user')
            ->get()
            ->sortBy(fn (DriverProfile $driver) => (string) $driver->user?->name)
            ->values();
    }

    /** @return Collection<int, FavoriteDriver> */
    public function listFor(User $owner): Collection
    {
        return $owner->favoriteDrivers()
            ->with('driver.user')
            ->latest('requested_at')
            ->get();
    }

    /**
     * Demande d'ajout d'un livreur en favori (statut « en attente »).
     */
    public function request(User $owner, DriverProfile $driver): FavoriteDriver
    {
        $favorite = $owner->favoriteDrivers()->firstOrNew(['driver_profile_id' => $driver->id]);

        if ($favorite->exists && $favorite->status === FavoriteDriverStatus::Accepted) {
            return $favorite->load('driver.user');
        }

        $favorite->fill([
            'status' => FavoriteDriverStatus::Pending->value,
            'requested_at' => $favorite->requested_at ?? now(),
            'responded_at' => null,
        ])->save();

        if ($driver->user !== null) {
            $this->notifications->notifyEvent('driver.favorite.requested', [$driver->user], [
                'reference' => $owner->name,
                'favorite_id' => $favorite->id,
            ]);
        }

        return $favorite->fresh(['driver.user']);
    }

    public function remove(User $owner, DriverProfile $driver): void
    {
        $owner->favoriteDrivers()->where('driver_profile_id', $driver->id)->delete();
    }

    /** @return Collection<int, FavoriteDriver> */
    public function listForDriver(DriverProfile $driver): Collection
    {
        return $driver->favoriteRequests()
            ->with(['owner', 'driver.user'])
            ->latest('requested_at')
            ->get();
    }

    public function accept(FavoriteDriver $favorite, DriverProfile $driver): FavoriteDriver
    {
        $this->assertOwnedByDriver($favorite, $driver);
        $this->assertPending($favorite);

        $favorite->update([
            'status' => FavoriteDriverStatus::Accepted->value,
            'responded_at' => now(),
        ]);

        if ($favorite->owner !== null) {
            $this->notifications->notifyEvent('driver.favorite.accepted', [$favorite->owner], [
                'reference' => (string) $driver->user?->name,
                'favorite_id' => $favorite->id,
            ]);
        }

        return $favorite->fresh(['owner', 'driver.user']);
    }

    public function decline(FavoriteDriver $favorite, DriverProfile $driver): FavoriteDriver
    {
        $this->assertOwnedByDriver($favorite, $driver);
        $this->assertPending($favorite);

        $favorite->update([
            'status' => FavoriteDriverStatus::Declined->value,
            'responded_at' => now(),
        ]);

        return $favorite->fresh(['owner', 'driver.user']);
    }

    /**
     * Vérifie qu'un livreur est bien un favori accepté de ce client/vendeur.
     */
    public function acceptedDriverFor(User $owner, string $driverProfileId): DriverProfile
    {
        $favorite = $owner->favoriteDrivers()
            ->where('driver_profile_id', $driverProfileId)
            ->where('status', FavoriteDriverStatus::Accepted->value)
            ->first();

        if ($favorite === null) {
            throw new DomainException('favorite.not_accepted', 'Ce livreur n\'a pas accepté de vous suivre.', 409);
        }

        $driver = DriverProfile::find($driverProfileId);

        if ($driver === null) {
            throw new DomainException('favorite.driver_not_found', 'Livreur introuvable.', 404);
        }

        return $driver;
    }

    /**
     * @return array<int, string>
     */
    private function pastDriverProfileIds(User $owner): array
    {
        $vendorId = Vendor::query()->where('user_id', $owner->id)->value('id');

        $fromOrders = Delivery::query()
            ->whereNotNull('driver_profile_id')
            ->whereHas('order', function ($query) use ($owner, $vendorId): void {
                $query->where(function ($inner) use ($owner, $vendorId): void {
                    $inner->where('user_id', $owner->id);

                    if ($vendorId !== null) {
                        $inner->orWhere('vendor_id', $vendorId);
                    }
                });
            })
            ->pluck('driver_profile_id');

        $fromParcels = Parcel::query()
            ->where('user_id', $owner->id)
            ->whereNotNull('driver_profile_id')
            ->pluck('driver_profile_id');

        return array_values(array_unique(
            $fromOrders->merge($fromParcels)->filter()->all()
        ));
    }

    private function assertOwnedByDriver(FavoriteDriver $favorite, DriverProfile $driver): void
    {
        if ($favorite->driver_profile_id !== $driver->id) {
            throw new DomainException('favorite.not_owned', 'Cette demande ne vous concerne pas.', 404);
        }
    }

    private function assertPending(FavoriteDriver $favorite): void
    {
        if ($favorite->status !== FavoriteDriverStatus::Pending) {
            throw new DomainException('favorite.not_pending', 'Cette demande a déjà été traitée.', 409);
        }
    }
}
