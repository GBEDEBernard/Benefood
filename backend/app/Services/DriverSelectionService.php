<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\DriverAssignmentRequestStatus;
use App\Enums\DriverStatus;
use App\Enums\OrderStatus;
use App\Enums\ParcelStatus;
use App\Exceptions\DomainException;
use App\Http\Resources\DriverAssignmentRequestResource;
use App\Models\Cart;
use App\Models\DriverAssignmentRequest;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * Sélection d'un livreur proche pour une commande ou un colis : recherche
 * géographique, demande explicite au livreur, expiration et intégration avec
 * les offres existantes.
 */
class DriverSelectionService
{
    public function __construct(
        private readonly DeliveryPricingService $distances,
        private readonly DriverAvailabilityService $availability,
        private readonly RoutingService $routing,
        private readonly NotificationService $notifications,
    ) {}

    /**
     * Livreurs disponibles autour du point de collecte, avec distances et ETA
     * routières (livreur → commerce, commerce → client).
     *
     * @return array<string, mixed>
     */
    public function nearbyForOrder(Order $order, User $client, ?float $radiusKm = null): array
    {
        return $this->nearby($order, $client, $radiusKm);
    }

    /**
     * @return array<string, mixed>
     */
    public function nearbyForParcel(Parcel $parcel, User $client, ?float $radiusKm = null): array
    {
        return $this->nearby($parcel, $client, $radiusKm);
    }

    /**
     * Livreurs proches du commerce avant la création de la commande (checkout) :
     * le client voit les frais d'approche avant de payer.
     *
     * @param  array<string, mixed>  $addressData
     * @return array<string, mixed>
     */
    public function nearbyForCheckout(Cart $cart, User $client, array $addressData, ?float $radiusKm = null): array
    {
        if ($cart->user_id !== $client->id) {
            throw new DomainException('driver_selection.not_found', 'Panier introuvable.', 404);
        }

        $cart->loadMissing('vendor');
        $vendor = $cart->vendor;

        if ($vendor === null) {
            throw new DomainException('driver_selection.vendor_missing', 'Boutique introuvable.', 404);
        }

        $context = [
            'reference' => 'checkout',
            'vendor' => $vendor,
            'pickup' => [
                'name' => $vendor->business_name,
                'latitude' => $vendor->pickup_latitude ?? $vendor->latitude,
                'longitude' => $vendor->pickup_longitude ?? $vendor->longitude,
                'address' => $vendor->pickup_address ?? $vendor->address,
                'landmark' => $vendor->pickup_landmark,
                'city' => $vendor->city,
            ],
            'dropoff' => [
                'name' => $addressData['label'] ?? null,
                'latitude' => $addressData['latitude'] ?? null,
                'longitude' => $addressData['longitude'] ?? null,
                'address' => $addressData['full_address'] ?? $addressData['address_text'] ?? null,
                'landmark' => $addressData['landmark'] ?? null,
                'city' => $addressData['city'] ?? null,
            ],
        ];

        $this->assertCoordinates($context);
        [$candidates, $radius] = $this->search(
            $context['pickup'],
            $this->requestedRadius($radiusKm),
            $this->maxRadius(),
        );

        return [
            'pickup' => $context['pickup'],
            'dropoff' => $context['dropoff'],
            'trip' => $this->trip($context),
            'radius_km' => round($radius, 2),
            'drivers' => $this->decorateDrivers($candidates, $context),
        ];
    }

    /**
     * Livreurs proches du point de remise lors d'une réassignation en cours de
     * livraison. Le livreur actuel est exclu.
     *
     * @return array<string, mixed>
     */
    public function nearbyForReassignment(
        Order $order,
        User $client,
        float $latitude,
        float $longitude,
        ?float $radiusKm = null,
    ): array {
        $this->assertOwnedBy($order, $client);
        $order->loadMissing(['vendor', 'delivery.driverProfile']);

        if (! in_array($order->status, [OrderStatus::PickedUp, OrderStatus::InDelivery], true)) {
            throw new DomainException(
                'driver_selection.not_available',
                'Le remplacement du livreur est possible uniquement après le ramassage et avant la livraison.',
                409,
            );
        }

        if ($order->delivery?->driver_profile_id === null) {
            throw new DomainException('driver_selection.no_driver', 'Aucun livreur à remplacer sur cette course.', 409);
        }

        $context = $this->context($order);
        $context['pickup'] = [
            'name' => 'Point de remise',
            'latitude' => $latitude,
            'longitude' => $longitude,
            'address' => null,
            'landmark' => null,
            'city' => $context['dropoff']['city'] ?? null,
        ];
        $context['vendor'] = $order->vendor;

        $this->assertCoordinates($context);
        [$candidates, $radius] = $this->search(
            $context['pickup'],
            $this->requestedRadius($radiusKm),
            $this->maxRadius(),
        );

        $currentDriverId = $order->delivery?->driver_profile_id;
        $candidates = $candidates
            ->reject(fn (DriverProfile $driver) => $driver->id === $currentDriverId)
            ->values();

        return [
            'pickup' => $context['pickup'],
            'dropoff' => $context['dropoff'],
            'trip' => $this->trip($context),
            'radius_km' => round($radius, 2),
            'drivers' => $this->decorateDrivers($candidates, $context),
        ];
    }

    /**
     * Enregistre une demande explicite du client pour un livreur proche.
     */
    public function requestForOrder(Order $order, User $client, string $driverProfileId): DriverAssignmentRequest
    {
        return $this->requestDriver($order, $client, $driverProfileId);
    }

    public function requestForParcel(Parcel $parcel, User $client, string $driverProfileId): DriverAssignmentRequest
    {
        return $this->requestDriver($parcel, $client, $driverProfileId);
    }

    /**
     * Affectation automatique : la plateforme sollicite le livreur disponible
     * le plus proche, qui doit accepter comme pour une demande manuelle.
     */
    public function autoAssignForOrder(Order $order, User $client): DriverAssignmentRequest
    {
        return $this->autoAssign($order, $client);
    }

    public function autoAssignForParcel(Parcel $parcel, User $client): DriverAssignmentRequest
    {
        return $this->autoAssign($parcel, $client);
    }

    /**
     * Annule la demande encore en attente. Retourne `null` s'il n'y en a pas.
     */
    public function cancelForOrder(Order $order, User $client): ?DriverAssignmentRequest
    {
        return $this->cancelPending($order, $client);
    }

    public function cancelForParcel(Parcel $parcel, User $client): ?DriverAssignmentRequest
    {
        return $this->cancelPending($parcel, $client);
    }

    /**
     * La commande est prête : la demande devient actionnable et son délai de
     * réponse démarre. Le ciblage de la course est déjà posé par `markReady`.
     */
    public function markOfferedForOrder(Order $order): ?DriverAssignmentRequest
    {
        if ($order->preferred_driver_profile_id === null) {
            return null;
        }

        return DB::transaction(function () use ($order): ?DriverAssignmentRequest {
            $request = DriverAssignmentRequest::query()
                ->where('assignable_type', Order::class)
                ->where('assignable_id', $order->id)
                ->where('driver_profile_id', $order->preferred_driver_profile_id)
                ->where('status', DriverAssignmentRequestStatus::Pending->value)
                ->lockForUpdate()
                ->first();

            if ($request === null || $request->offered_at !== null) {
                return $request;
            }

            $deliveryTarget = $order->delivery()->value('targeted_driver_profile_id');

            if ($deliveryTarget === null) {
                $order->delivery()->update([
                    'targeted_driver_profile_id' => $request->driver_profile_id,
                ]);
            } elseif ($deliveryTarget !== $request->driver_profile_id) {
                // Le vendeur a ciblé un autre livreur : la demande du client
                // n'est plus cohérente, on la clôt proprement.
                $request->update([
                    'status' => DriverAssignmentRequestStatus::Cancelled->value,
                    'responded_at' => now(),
                ]);
                $order->update(['preferred_driver_profile_id' => null]);

                return $request->fresh();
            }

            $ttl = $this->requestTtlSeconds();

            $request->update([
                'offered_at' => now(),
                'expires_at' => now()->addSeconds($ttl),
            ]);

            return $request->fresh();
        });
    }

    /**
     * La demande liée est acceptée (appelé dans la transaction d'acceptation).
     */
    public function markAccepted(Order|Parcel $assignable, DriverProfile $driver): void
    {
        $request = DriverAssignmentRequest::query()
            ->where('assignable_type', $assignable::class)
            ->where('assignable_id', $assignable->id)
            ->where('driver_profile_id', $driver->id)
            ->where('status', DriverAssignmentRequestStatus::Pending->value)
            ->lockForUpdate()
            ->first();

        if ($request === null) {
            return;
        }

        $request->update([
            'status' => DriverAssignmentRequestStatus::Accepted->value,
            'responded_at' => now(),
        ]);
    }

    /**
     * Le livreur refuse : la demande est close et le ciblage est retiré pour
     * que les autres livreurs puissent prendre la course.
     */
    public function markRefused(Order|Parcel $assignable, DriverProfile $driver, ?string $reason = null): void
    {
        $request = DriverAssignmentRequest::query()
            ->where('assignable_type', $assignable::class)
            ->where('assignable_id', $assignable->id)
            ->where('driver_profile_id', $driver->id)
            ->where('status', DriverAssignmentRequestStatus::Pending->value)
            ->lockForUpdate()
            ->first();

        if ($request !== null) {
            $request->update([
                'status' => DriverAssignmentRequestStatus::Refused->value,
                'responded_at' => now(),
                'refusal_reason' => $reason,
            ]);
        }

        $this->clearTarget($assignable, $driver->id);
    }

    /**
     * Expire les demandes dont le délai est dépassé et libère le ciblage.
     * Retourne le nombre de demandes expirées.
     */
    public function expireStale(Order|Parcel|null $assignable = null): int
    {
        $query = DriverAssignmentRequest::query()
            ->where('status', DriverAssignmentRequestStatus::Pending->value)
            ->whereNotNull('expires_at')
            ->where('expires_at', '<=', now());

        if ($assignable !== null) {
            $query->where('assignable_type', $assignable::class)
                ->where('assignable_id', $assignable->id);
        }

        $ids = $query->pluck('id');
        $expired = 0;

        foreach ($ids as $id) {
            $didExpire = DB::transaction(function () use ($id): bool {
                $request = DriverAssignmentRequest::query()->whereKey($id)->lockForUpdate()->first();

                if ($request === null
                    || $request->status !== DriverAssignmentRequestStatus::Pending
                    || $request->expires_at === null
                    || $request->expires_at->isFuture()) {
                    return false;
                }

                $request->update([
                    'status' => DriverAssignmentRequestStatus::Expired->value,
                    'responded_at' => now(),
                ]);

                $assignable = $this->lockAssignable($request->assignable_type, $request->assignable_id);

                if ($assignable !== null) {
                    $this->clearTarget($assignable, $request->driver_profile_id);
                }

                return true;
            });

            if ($didExpire) {
                $expired++;
            }
        }

        return $expired;
    }

    /**
     * Dernière demande (quel que soit son statut) pour une commande/colis.
     */
    public function latestRequest(Order|Parcel $assignable): ?DriverAssignmentRequest
    {
        $request = $assignable->driverAssignmentRequest()->with('driverProfile.user')->first();

        if ($request !== null) {
            $this->expireStale($assignable);
            $request->refresh();
        }

        return $request;
    }

    /**
     * @return array<string, mixed>
     */
    private function nearby(Order|Parcel $assignable, User $client, ?float $radiusKm): array
    {
        $this->assertOwnedBy($assignable, $client);
        $this->expireStale($assignable);
        $this->assertEligible($assignable);

        $context = $this->context($assignable);
        $this->assertCoordinates($context);

        $maxRadius = $this->maxRadius();
        $requestedRadius = $this->requestedRadius($radiusKm);

        [$candidates, $radius] = $this->search($context['pickup'], $requestedRadius, $maxRadius);

        $drivers = $this->decorateDrivers($candidates, $context);
        $latest = $assignable->driverAssignmentRequest()->with('driverProfile.user')->first();
        $diagnostics = $this->diagnostics($context['pickup'], $maxRadius);

        $logContext = [
            'reference' => $context['reference'],
            'radius_km' => round($radius, 2),
            'expanded' => $radius > $requestedRadius,
            'drivers' => count($drivers),
        ] + $diagnostics;

        if ($drivers === []) {
            Log::warning('driver_selection.nearby.empty', $logContext);
        } else {
            Log::info('driver_selection.nearby.found', $logContext);
        }

        return [
            'pickup' => $context['pickup'],
            'dropoff' => $context['dropoff'],
            'trip' => $this->trip($context),
            'radius_km' => round($radius, 2),
            'requested_radius_km' => round($requestedRadius, 2),
            'max_radius_km' => round($maxRadius, 2),
            'expanded' => $radius > $requestedRadius,
            'drivers' => $drivers,
            'diagnostics' => $diagnostics,
            'request' => $latest !== null
                ? (new DriverAssignmentRequestResource($latest))->resolve()
                : null,
        ];
    }

    /**
     * Recherche élargie par paliers : rayon initial puis extension progressive
     * jusqu'au maximum configuré.
     *
     * @param  array<string, mixed>  $pickup
     * @return array{0: Collection<int, DriverProfile>, 1: float}
     */
    private function search(array $pickup, float $requestedRadius, float $maxRadius): array
    {
        $radius = $requestedRadius;

        while (true) {
            $candidates = $this->eligibleDrivers($pickup, $radius);

            if ($candidates->isNotEmpty() || $radius >= $maxRadius) {
                return [$candidates, $radius];
            }

            $radius = min($maxRadius, $radius * 1.5);
        }
    }

    /**
     * Compteurs de disponibilité (aucune donnée personnelle) : ils permettent
     * de distinguer « aucun livreur », « GPS absent » et « GPS périmé ».
     *
     * @param  array<string, mixed>  $pickup
     * @return array<string, int|float>
     */
    private function diagnostics(array $pickup, float $maxRadius): array
    {
        $freshSince = now()->subSeconds($this->locationMaxAgeSeconds());

        $online = DriverProfile::query()
            ->where('available', true)
            ->where('status', DriverStatus::Active->value)
            ->get(['id', 'last_latitude', 'last_longitude', 'last_location_at']);

        $withoutPosition = 0;
        $stalePosition = 0;
        $freshPosition = 0;
        $withinMaxRadius = 0;

        foreach ($online as $driver) {
            if ($driver->last_latitude === null || $driver->last_longitude === null) {
                $withoutPosition++;

                continue;
            }

            if ($driver->last_location_at === null || $driver->last_location_at->lt($freshSince)) {
                $stalePosition++;

                continue;
            }

            $freshPosition++;

            $distance = $this->distances->distanceKm(
                $driver->last_latitude,
                $driver->last_longitude,
                $pickup['latitude'],
                $pickup['longitude'],
            );

            if ($distance !== null && $distance <= $maxRadius) {
                $withinMaxRadius++;
            }
        }

        return [
            'online_drivers' => $online->count(),
            'with_position' => $freshPosition + $stalePosition,
            'fresh_position' => $freshPosition,
            'stale_position' => $stalePosition,
            'without_position' => $withoutPosition,
            'within_max_radius' => $withinMaxRadius,
            'max_radius_km' => round($maxRadius, 2),
            'location_max_age_s' => $this->locationMaxAgeSeconds(),
        ];
    }

    /**
     * Trajet routier du point de collecte vers l'adresse du client.
     *
     * @param  array<string, mixed>  $context
     * @return array{distance_km: float, duration_s: int}|null
     */
    private function trip(array $context): ?array
    {
        if (($context['dropoff'] ?? null) === null) {
            return null;
        }

        $route = $this->routing->plan([$context['pickup'], $context['dropoff']]);
        $leg = $route['legs'][0] ?? null;

        if ($leg === null) {
            return null;
        }

        return [
            'distance_km' => round((int) $leg['distance_m'] / 1000, 2),
            'duration_s' => $this->routing->etaSeconds((int) $leg['duration_s']),
        ];
    }

    private function requestedRadius(?float $radiusKm): float
    {
        $configuredRadius = max(0.5, (float) config('beninfood.driver_selection.radius_km', 5));
        $maxRadius = $this->maxRadius();

        return $radiusKm !== null ? min($maxRadius, max(0.5, $radiusKm)) : $configuredRadius;
    }

    private function maxRadius(): float
    {
        $configuredRadius = max(0.5, (float) config('beninfood.driver_selection.radius_km', 5));

        return max($configuredRadius, (float) config('beninfood.driver_selection.max_radius_km', 15));
    }

    private function autoAssign(Order|Parcel $assignable, User $client): DriverAssignmentRequest
    {
        $this->assertOwnedBy($assignable, $client);
        $this->expireStale($assignable);
        $this->assertEligible($assignable);

        $context = $this->context($assignable);
        $this->assertCoordinates($context);

        $configuredRadius = max(0.5, (float) config('beninfood.driver_selection.radius_km', 3));
        $maxRadius = max($configuredRadius, (float) config('beninfood.driver_selection.max_radius_km', 15));

        [$candidates] = $this->search($context['pickup'], $configuredRadius, $maxRadius);
        $driver = $candidates->first();

        if ($driver === null) {
            Log::warning('driver_selection.auto.none', [
                'reference' => $context['reference'],
                'radius_km' => round($maxRadius, 2),
            ]);

            throw new DomainException(
                'driver_selection.no_driver_available',
                'Aucun livreur disponible pour le moment. Nous vous préviendrons dès qu\'un livreur se connecte.',
                409,
            );
        }

        Log::info('driver_selection.auto.requested', [
            'reference' => $context['reference'],
            'driver_profile_id' => $driver->id,
        ]);

        return $this->requestDriver($assignable, $client, $driver->id);
    }

    private function requestDriver(Order|Parcel $assignable, User $client, string $driverProfileId): DriverAssignmentRequest
    {
        $this->assertOwnedBy($assignable, $client);
        $this->expireStale($assignable);

        $actionable = false;
        $driverUser = null;

        $request = DB::transaction(function () use ($assignable, $client, $driverProfileId, &$actionable, &$driverUser): DriverAssignmentRequest {
            $locked = $this->lockAssignable($assignable::class, $assignable->id);

            if ($locked === null) {
                throw new DomainException('driver_selection.not_found', 'Commande ou colis introuvable.', 404);
            }

            $this->assertEligible($locked);
            $context = $this->context($locked);
            $this->assertCoordinates($context);

            $driver = DriverProfile::query()->whereKey($driverProfileId)->lockForUpdate()->first();

            if ($driver === null) {
                throw new DomainException('driver_selection.driver_not_found', 'Livreur introuvable.', 404);
            }

            $this->assertDriverSelectable($driver, $context['pickup']);

            // Une seule demande active : la précédente est annulée, puis le
            // ciblage existant est remplacé par le nouveau livreur.
            DriverAssignmentRequest::query()
                ->where('assignable_type', $locked::class)
                ->where('assignable_id', $locked->id)
                ->where('status', DriverAssignmentRequestStatus::Pending->value)
                ->lockForUpdate()
                ->get()
                ->each(fn (DriverAssignmentRequest $pending) => $pending->update([
                    'status' => DriverAssignmentRequestStatus::Cancelled->value,
                    'responded_at' => now(),
                ]));

            $actionable = $this->isActionable($locked);
            $ttl = $this->requestTtlSeconds();

            $request = DriverAssignmentRequest::create([
                'assignable_type' => $locked::class,
                'assignable_id' => $locked->id,
                'client_id' => $client->id,
                'driver_profile_id' => $driver->id,
                'status' => DriverAssignmentRequestStatus::Pending->value,
                'offered_at' => $actionable ? now() : null,
                'expires_at' => $actionable ? now()->addSeconds($ttl) : null,
            ]);

            $this->applyTarget($locked, $driver->id);
            $driver->loadMissing('user');
            $driverUser = $driver->user;

            return $request->fresh(['driverProfile.user']);
        });

        if ($actionable && $driverUser !== null) {
            $this->notifyOffer($assignable, $request);
        }

        return $request;
    }

    private function cancelPending(Order|Parcel $assignable, User $client): ?DriverAssignmentRequest
    {
        $this->assertOwnedBy($assignable, $client);
        $this->expireStale($assignable);

        return DB::transaction(function () use ($assignable): ?DriverAssignmentRequest {
            $locked = $this->lockAssignable($assignable::class, $assignable->id);

            if ($locked === null) {
                throw new DomainException('driver_selection.not_found', 'Commande ou colis introuvable.', 404);
            }

            $request = DriverAssignmentRequest::query()
                ->where('assignable_type', $locked::class)
                ->where('assignable_id', $locked->id)
                ->where('status', DriverAssignmentRequestStatus::Pending->value)
                ->lockForUpdate()
                ->first();

            if ($request === null) {
                return null;
            }

            $request->update([
                'status' => DriverAssignmentRequestStatus::Cancelled->value,
                'responded_at' => now(),
            ]);

            $this->clearTarget($locked, $request->driver_profile_id);

            return $request->fresh();
        });
    }

    /**
     * @param  Collection<int, DriverProfile>  $candidates
     * @param  array<string, mixed>  $context
     * @return array<int, array<string, mixed>>
     */
    private function decorateDrivers(Collection $candidates, array $context): array
    {
        $drivers = [];

        foreach ($candidates as $driver) {
            $points = [
                ['latitude' => (float) $driver->last_latitude, 'longitude' => (float) $driver->last_longitude],
                $context['pickup'],
            ];

            if ($context['dropoff'] !== null) {
                $points[] = $context['dropoff'];
            }

            $route = $this->routing->plan($points);
            $toPickup = $route['legs'][0] ?? ['distance_m' => 0, 'duration_s' => 0];
            $pickupToDropoff = $route['legs'][1] ?? null;
            $etaToPickup = $this->routing->etaSeconds((int) $toPickup['duration_s']);
            $distanceToPickupKm = (int) $toPickup['distance_m'] / 1000;
            $pickupToDropoffKm = $pickupToDropoff !== null
                ? (int) $pickupToDropoff['distance_m'] / 1000
                : null;
            $etaToDropoff = $pickupToDropoff !== null
                ? $this->routing->etaSeconds((int) $pickupToDropoff['duration_s'])
                : null;

            $approach = isset($context['vendor'])
                ? $this->distances->approachQuote($driver, $context['vendor'])
                : null;

            $drivers[] = [
                'id' => $driver->id,
                'name' => $driver->user?->name,
                'avatar_url' => $this->mediaUrl($driver->user?->avatar_path),
                'vehicle' => $driver->vehicle,
                'rating' => $driver->rating !== null ? (float) $driver->rating : null,
                'completed_deliveries' => (int) $driver->completed_deliveries_count
                    + (int) $driver->completed_parcels_count,
                'distance_to_pickup_km' => round($distanceToPickupKm, 2),
                'eta_to_pickup_s' => $etaToPickup,
                'pickup_to_dropoff_km' => $pickupToDropoffKm !== null ? round($pickupToDropoffKm, 2) : null,
                'eta_to_dropoff_s' => $etaToDropoff,
                'distance_to_dropoff_km' => $pickupToDropoffKm !== null
                    ? round($distanceToPickupKm + $pickupToDropoffKm, 2)
                    : null,
                'eta_total_s' => $etaToDropoff !== null ? $etaToPickup + $etaToDropoff : null,
                'approach_fee' => $approach['fee'] ?? null,
                'approach_distance_km' => $approach['distance_km'] ?? null,
                'approach_billable_km' => $approach['billable_km'] ?? null,
                'position' => [
                    'latitude' => round((float) $driver->last_latitude, 3),
                    'longitude' => round((float) $driver->last_longitude, 3),
                    'heading' => $driver->last_heading !== null ? (float) $driver->last_heading : null,
                    'last_location_at' => $driver->last_location_at?->toIso8601String(),
                    'age_seconds' => $driver->last_location_at !== null
                        ? max(0, (int) $driver->last_location_at->diffInSeconds(now()))
                        : null,
                ],
            ];
        }

        usort($drivers, fn (array $a, array $b): int => $a['distance_to_pickup_km'] <=> $b['distance_to_pickup_km']);

        return $drivers;
    }

    /**
     * @param  array<string, mixed>  $pickup
     * @return Collection<int, DriverProfile>
     */
    private function eligibleDrivers(array $pickup, float $radiusKm): Collection
    {
        $latitude = (float) $pickup['latitude'];
        $longitude = (float) $pickup['longitude'];
        $latDelta = $radiusKm / 110.574;
        $lngDelta = $radiusKm / (111.320 * max(0.01, cos(deg2rad($latitude))));
        $freshSince = now()->subSeconds($this->locationMaxAgeSeconds());
        $maxActive = $this->availability->maxActiveMissions();

        $drivers = DriverProfile::query()
            ->where('available', true)
            ->where('status', DriverStatus::Active->value)
            ->whereNotNull('last_latitude')
            ->whereNotNull('last_longitude')
            ->where('last_location_at', '>=', $freshSince)
            ->whereBetween('last_latitude', [$latitude - $latDelta, $latitude + $latDelta])
            ->whereBetween('last_longitude', [$longitude - $lngDelta, $longitude + $lngDelta])
            ->with('user')
            ->withCount([
                'deliveries as active_deliveries_count' => fn ($query) => $query->whereIn('status', DriverAvailabilityService::ACTIVE_DELIVERY_STATUSES),
                'parcels as active_parcels_count' => fn ($query) => $query->whereIn('status', DriverAvailabilityService::ACTIVE_PARCEL_STATUSES),
                'deliveries as completed_deliveries_count' => fn ($query) => $query->where('status', DeliveryStatus::Delivered->value),
                'parcels as completed_parcels_count' => fn ($query) => $query->where('status', ParcelStatus::Delivered->value),
            ])
            ->limit(80)
            ->get();

        return $drivers
            ->filter(function (DriverProfile $driver) use ($pickup, $radiusKm, $maxActive): bool {
                $distance = $this->distances->distanceKm(
                    $driver->last_latitude,
                    $driver->last_longitude,
                    $pickup['latitude'],
                    $pickup['longitude'],
                );

                if ($distance === null || $distance > $radiusKm) {
                    return false;
                }

                $active = (int) $driver->active_deliveries_count + (int) $driver->active_parcels_count;

                return $active < $maxActive;
            })
            ->sortBy(fn (DriverProfile $driver): float => (float) $this->distances->distanceKm(
                $driver->last_latitude,
                $driver->last_longitude,
                $pickup['latitude'],
                $pickup['longitude'],
            ))
            ->take(max(1, (int) config('beninfood.driver_selection.max_candidates', 15)))
            ->values();
    }

    /**
     * Vérifie qu'un livreur peut prendre un point donné (checkout ou remise
     * lors d'une réassignation).
     */
    public function assertSelectableAt(DriverProfile $driver, float $latitude, float $longitude): void
    {
        $this->assertDriverSelectable($driver, [
            'latitude' => $latitude,
            'longitude' => $longitude,
        ]);
    }

    private function assertDriverSelectable(DriverProfile $driver, array $pickup): void
    {
        if ((bool) $driver->available === false
            || $driver->status !== DriverStatus::Active->value
            || $driver->last_latitude === null
            || $driver->last_longitude === null
            || $driver->last_location_at === null
            || $driver->last_location_at->lt(now()->subSeconds($this->locationMaxAgeSeconds()))) {
            throw new DomainException(
                'driver_selection.driver_unavailable',
                'Ce livreur n\'est plus disponible ou sa position n\'est plus à jour.',
                409,
            );
        }

        $distance = $this->distances->distanceKm(
            $driver->last_latitude,
            $driver->last_longitude,
            $pickup['latitude'],
            $pickup['longitude'],
        );
        $maxRadius = (float) config('beninfood.driver_selection.max_radius_km', 15);

        if ($distance === null || $distance > $maxRadius) {
            throw new DomainException(
                'driver_selection.driver_too_far',
                'Ce livreur est trop éloigné du point de collecte.',
                409,
            );
        }

        $this->availability->assertCanAccept($driver);
    }

    /**
     * @return array{reference: string, pickup: array<string, mixed>, dropoff: array<string, mixed>|null}
     */
    private function context(Order|Parcel $assignable): array
    {
        if ($assignable instanceof Order) {
            $assignable->loadMissing(['vendor', 'delivery']);
            $vendor = $assignable->vendor;
            $address = $assignable->address_snapshot ?? [];

            return [
                'reference' => $assignable->reference,
                'vendor' => $vendor,
                'pickup' => [
                    'name' => $vendor?->business_name,
                    'latitude' => $vendor?->pickup_latitude ?? $vendor?->latitude,
                    'longitude' => $vendor?->pickup_longitude ?? $vendor?->longitude,
                    'address' => $vendor?->pickup_address ?? $vendor?->address,
                    'landmark' => $vendor?->pickup_landmark,
                    'city' => $vendor?->city,
                ],
                'dropoff' => [
                    'name' => $address['label'] ?? null,
                    'latitude' => $address['latitude'] ?? null,
                    'longitude' => $address['longitude'] ?? null,
                    'address' => $address['full_address'] ?? $address['address_text'] ?? null,
                    'landmark' => $address['landmark'] ?? null,
                    'city' => $address['city'] ?? null,
                ],
            ];
        }

        $pickup = $assignable->pickup_snapshot ?? [];
        $dropoff = $assignable->dropoff_snapshot ?? [];

        return [
            'reference' => $assignable->reference,
            'pickup' => [
                'name' => $pickup['label'] ?? null,
                'latitude' => $pickup['latitude'] ?? null,
                'longitude' => $pickup['longitude'] ?? null,
                'address' => $pickup['address_text'] ?? $pickup['label'] ?? null,
                'landmark' => $pickup['landmark'] ?? null,
                'city' => $pickup['city'] ?? null,
            ],
            'dropoff' => [
                'name' => $dropoff['label'] ?? null,
                'latitude' => $dropoff['latitude'] ?? null,
                'longitude' => $dropoff['longitude'] ?? null,
                'address' => $dropoff['address_text'] ?? $dropoff['label'] ?? null,
                'landmark' => $dropoff['landmark'] ?? null,
                'city' => $dropoff['city'] ?? null,
            ],
        ];
    }

    private function assertEligible(Order|Parcel $assignable): void
    {
        if ($assignable instanceof Order) {
            if (! in_array($assignable->status, [OrderStatus::Paid, OrderStatus::Accepted, OrderStatus::Preparing, OrderStatus::Ready], true)) {
                throw new DomainException(
                    'driver_selection.not_available',
                    'La sélection d\'un livreur est ouverte après le paiement et avant l\'affectation.',
                    409,
                );
            }

            $driverId = $assignable->delivery()->value('driver_profile_id');

            if ($driverId !== null) {
                throw new DomainException('driver_selection.already_assigned', 'Un livreur est déjà affecté à cette commande.', 409);
            }

            return;
        }

        if ($assignable->status !== ParcelStatus::Paid || $assignable->driver_profile_id !== null) {
            throw new DomainException(
                'driver_selection.not_available',
                'La sélection d\'un livreur est ouverte après le paiement et avant l\'affectation.',
                409,
            );
        }
    }

    private function assertOwnedBy(Order|Parcel $assignable, User $client): void
    {
        if ($assignable->user_id !== $client->id) {
            throw new DomainException('driver_selection.not_found', 'Commande ou colis introuvable.', 404);
        }
    }

    /**
     * @param  array<string, mixed>  $context
     */
    private function assertCoordinates(array $context): void
    {
        if ($context['pickup']['latitude'] === null || $context['pickup']['longitude'] === null) {
            throw new DomainException(
                'driver_selection.pickup_unavailable',
                'La position du point de collecte est indisponible.',
                422,
            );
        }

        if ($context['dropoff'] === null
            || $context['dropoff']['latitude'] === null
            || $context['dropoff']['longitude'] === null) {
            throw new DomainException(
                'driver_selection.dropoff_unavailable',
                'La position de l\'adresse de livraison est indisponible.',
                422,
            );
        }
    }

    private function isActionable(Order|Parcel $assignable): bool
    {
        return $assignable instanceof Parcel
            ? $assignable->status === ParcelStatus::Paid
            : $assignable->status === OrderStatus::Ready && $assignable->delivery()->exists();
    }

    private function applyTarget(Order|Parcel $assignable, string $driverProfileId): void
    {
        if ($assignable instanceof Order) {
            $assignable->update(['preferred_driver_profile_id' => $driverProfileId]);

            $delivery = $assignable->delivery()->first();

            if ($delivery !== null && $delivery->driver_profile_id === null) {
                $delivery->update(['targeted_driver_profile_id' => $driverProfileId]);
            }

            return;
        }

        $assignable->update(['targeted_driver_profile_id' => $driverProfileId]);
    }

    private function clearTarget(Order|Parcel $assignable, string $driverProfileId): void
    {
        if ($assignable instanceof Order) {
            if ($assignable->preferred_driver_profile_id === $driverProfileId) {
                $assignable->update(['preferred_driver_profile_id' => null]);
            }

            $delivery = $assignable->delivery()->lockForUpdate()->first();

            if ($delivery !== null
                && $delivery->driver_profile_id === null
                && $delivery->targeted_driver_profile_id === $driverProfileId) {
                $delivery->update(['targeted_driver_profile_id' => null]);
            }

            return;
        }

        if ($assignable->targeted_driver_profile_id === $driverProfileId) {
            $assignable->update(['targeted_driver_profile_id' => null]);
        }
    }

    private function lockAssignable(string $type, string $id): Order|Parcel|null
    {
        if ($type === Order::class) {
            return Order::query()->whereKey($id)->lockForUpdate()->first();
        }

        if ($type === Parcel::class) {
            return Parcel::query()->whereKey($id)->lockForUpdate()->first();
        }

        return null;
    }

    private function notifyOffer(Order|Parcel $assignable, DriverAssignmentRequest $request): void
    {
        $request->loadMissing('driverProfile.user');
        $driverUser = $request->driverProfile?->user;

        if ($driverUser === null) {
            return;
        }

        if ($assignable instanceof Order) {
            $deliveryId = $assignable->delivery()->value('id');

            $this->notifications->notifyEvent('delivery.offered', [$driverUser], [
                'reference' => $assignable->reference,
                'order_id' => $assignable->id,
                'delivery_id' => $deliveryId,
            ]);

            return;
        }

        $this->notifications->notifyEvent('parcel.offered', [$driverUser], [
            'reference' => $assignable->reference,
            'parcel_id' => $assignable->id,
        ]);
    }

    private function requestTtlSeconds(): int
    {
        return max(5, (int) config('beninfood.driver_selection.request_ttl_s', 120));
    }

    private function locationMaxAgeSeconds(): int
    {
        return max(10, (int) config('beninfood.driver_selection.location_max_age_s', 300));
    }

    private function mediaUrl(?string $path): ?string
    {
        if ($path === null || $path === '') {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        return Storage::disk('public')->url($path);
    }
}
