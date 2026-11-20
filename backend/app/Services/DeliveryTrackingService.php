<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\ParcelStatus;
use App\Events\DriverLocationUpdated;
use App\Exceptions\DomainException;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Parcel;
use App\Support\Geo;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Suivi GPS des missions actives : dépôt côté livreur, lecture côté client.
 *
 * Une seule logique sert les commandes et les colis :
 * - une mission doit être active et explicitement assignée au livreur ;
 * - la fréquence est plus rapide en mission que pour le heartbeat de présence ;
 * - la précision, la vitesse, le cap et la source sont conservés ;
 * - les relevés et l'événement de diffusion s'arrêtent dès la fin de mission ;
 * - la distance à vol d'oiseau et la distance routière sont calculées séparément.
 *
 * Le broadcast reste désactivé par défaut : FCM + polling demeurent le canal
 * temps réel. L'événement est simplement prêt pour une activation Reverb.
 *
 * @phpstan-type NormalizedLocationShape array{latitude: float, longitude: float, accuracy_m: float|null, speed_mps: float|null, heading: float|null, source: string, recorded_at: Carbon}
 */
class DeliveryTrackingService
{
    /** @var array<int, DeliveryStatus> */
    private const ACTIVE_DELIVERY_STATUSES = [
        DeliveryStatus::Assigned,
        DeliveryStatus::EnRoutePickup,
        DeliveryStatus::PickedUp,
        DeliveryStatus::InDelivery,
    ];

    /** @var array<int, ParcelStatus> */
    private const ACTIVE_PARCEL_STATUSES = [
        ParcelStatus::Assigned,
        ParcelStatus::EnRoutePickup,
        ParcelStatus::PickedUp,
        ParcelStatus::InDelivery,
    ];

    /** Sources GPS acceptées pour un relevé de mission. */
    private const SOURCES = ['gps', 'network', 'manual'];

    public function __construct(private readonly RoutingService $routing) {}

    /**
     * Enregistre une position livreur et la propage à ses missions actives.
     *
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    public function recordLocation(DriverProfile $profile, array $data): array
    {
        $location = $this->normalize($data);
        $deliveries = $this->activeDeliveries($profile);
        $parcels = $this->activeParcels($profile);
        $hasMission = $deliveries->isNotEmpty() || $parcels->isNotEmpty();
        $interval = $hasMission
            ? max(1, (int) config('beninfood.geography.tracking.min_interval_s', 4))
            : max(1, (int) config('beninfood.tracking.idle_min_interval_s', 15));
        $cacheKey = sprintf('tracking:location:%s:%s', $profile->id, $hasMission ? 'mission' : 'idle');
        $now = Carbon::now();
        $last = $this->cacheTime($cacheKey);

        // Carbon 3 renvoie un écart signé : `abs()` protège aussi contre un
        // léger décalage d'horloge entre deux dépôts consécutifs.
        $elapsed = $last === null ? null : abs($now->diffInSeconds($last));

        if ($elapsed !== null && $elapsed < $interval) {
            return [
                'accepted' => false,
                'reason' => 'throttled',
                'interval_s' => $interval,
                'next_allowed_at' => $last->copy()->addSeconds($interval)->toIso8601String(),
            ];
        }

        if (isset($data['delivery_id']) && $data['delivery_id'] !== null && $data['delivery_id'] !== '') {
            $deliveries = $deliveries->where('id', (string) $data['delivery_id'])->values();
            if ($deliveries->isEmpty()) {
                throw new DomainException(
                    'tracking.mission_not_active',
                    'Cette mission n\'est plus active ou n\'est pas assignée à ce livreur.',
                    409,
                );
            }
        }

        if (isset($data['parcel_id']) && $data['parcel_id'] !== null && $data['parcel_id'] !== '') {
            $parcels = $parcels->where('id', (string) $data['parcel_id'])->values();
            if ($parcels->isEmpty()) {
                throw new DomainException(
                    'tracking.mission_not_active',
                    'Cette mission n\'est plus active ou n\'est pas assignée à ce livreur.',
                    409,
                );
            }
        }

        $previousLatitude = $profile->last_latitude !== null ? (float) $profile->last_latitude : null;
        $previousLongitude = $profile->last_longitude !== null ? (float) $profile->last_longitude : null;
        $heading = $location['heading'] ?? $this->headingBetween(
            $previousLatitude,
            $previousLongitude,
            $location['latitude'],
            $location['longitude'],
        );

        DB::transaction(function () use ($profile, $location, $heading, $deliveries): void {
            $profile->update([
                'last_latitude' => $location['latitude'],
                'last_longitude' => $location['longitude'],
                'last_location_at' => $location['recorded_at'],
                'last_heading' => $heading ?? $profile->last_heading,
            ]);

            foreach ($deliveries as $delivery) {
                $delivery->update([
                    'last_latitude' => $location['latitude'],
                    'last_longitude' => $location['longitude'],
                    'last_location_at' => $location['recorded_at'],
                    'last_accuracy_m' => $location['accuracy_m'],
                    'last_heading' => $heading,
                    'last_speed_mps' => $location['speed_mps'],
                    'last_location_source' => $location['source'],
                ]);

                $delivery->locations()->create([
                    'driver_profile_id' => $profile->id,
                    'latitude' => $location['latitude'],
                    'longitude' => $location['longitude'],
                    'heading' => $heading,
                    'accuracy_m' => $location['accuracy_m'],
                    'speed_mps' => $location['speed_mps'],
                    'location_source' => $location['source'],
                    'recorded_at' => $location['recorded_at'],
                ]);
            }
        });

        Cache::put($cacheKey, $now, now()->addSeconds(max(60, $interval * 4)));

        foreach ($deliveries as $delivery) {
            $delivery->loadMissing('order');

            event(new DriverLocationUpdated(
                (string) $delivery->id,
                (string) $profile->id,
                $delivery->order?->user_id !== null ? (string) $delivery->order->user_id : null,
                $this->positionForDelivery($delivery) ?? [],
            ));
        }

        return [
            'accepted' => true,
            'position' => $this->driverPosition($location['latitude'], $location['longitude'], $location, $now),
            'missions' => $deliveries->map(fn (Delivery $delivery): array => [
                'id' => $delivery->id,
                'type' => 'delivery',
                'status' => $delivery->status?->value,
            ])->concat($parcels->map(fn (Parcel $parcel): array => [
                'id' => $parcel->id,
                'type' => 'parcel',
                'status' => $parcel->status?->value,
            ]))->values()->all(),
            'interval_s' => $interval,
            'next_allowed_at' => $now->copy()->addSeconds($interval)->toIso8601String(),
        ];
    }

    /**
     * Position publique d'une commande, compatible avec l'ancien champ
     * `delivery.position` consommé par l'application mobile.
     *
     * @return array<string, mixed>|null
     */
    public function positionForDelivery(Delivery $delivery): ?array
    {
        if (! $delivery->isTrackingActive() || $delivery->driver_profile_id === null) {
            return null;
        }

        $latitude = $delivery->last_latitude;
        $longitude = $delivery->last_longitude;
        $recordedAt = $delivery->last_location_at;

        if ($latitude === null || $longitude === null) {
            $driver = $delivery->driverProfile;
            $latitude = $driver?->last_latitude;
            $longitude = $driver?->last_longitude;
            $recordedAt ??= $driver?->last_location_at;
        }

        if ($latitude === null || $longitude === null) {
            return null;
        }

        $address = $delivery->order?->address_snapshot ?? [];

        return $this->driverPosition(
            (float) $latitude,
            (float) $longitude,
            [
                'accuracy_m' => $delivery->last_accuracy_m,
                'speed_mps' => $delivery->last_speed_mps,
                'heading' => $delivery->last_heading,
                'source' => $delivery->last_location_source ?? 'gps',
                'recorded_at' => $recordedAt,
            ],
            Carbon::now(),
            Geo::haversineKm(
                $latitude,
                $longitude,
                $delivery->dropoff_latitude ?? $address['latitude'] ?? null,
                $delivery->dropoff_longitude ?? $address['longitude'] ?? null,
            ),
        );
    }

    /**
     * Position publique d'un colis, compatible avec `parcel.position`.
     *
     * @return array<string, mixed>|null
     */
    public function positionForParcel(Parcel $parcel): ?array
    {
        $active = in_array($parcel->status, self::ACTIVE_PARCEL_STATUSES, true);
        if (! $active || $parcel->driver_profile_id === null) {
            return null;
        }

        $driver = $parcel->driverProfile;
        if ($driver === null || $driver->last_latitude === null || $driver->last_longitude === null) {
            return null;
        }

        $dropoff = $parcel->dropoff_snapshot ?? [];

        return $this->driverPosition(
            (float) $driver->last_latitude,
            (float) $driver->last_longitude,
            [
                'accuracy_m' => null,
                'speed_mps' => null,
                'heading' => $driver->last_heading,
                'source' => 'gps',
                'recorded_at' => $driver->last_location_at,
            ],
            Carbon::now(),
            Geo::haversineKm(
                $driver->last_latitude,
                $driver->last_longitude,
                $dropoff['latitude'] ?? null,
                $dropoff['longitude'] ?? null,
            ),
        );
    }

    /**
     * Suivi complet d'une commande : trois positions distinctes, distances
     * orthodromiques, distance routière et ETA.
     *
     * @return array<string, mixed>
     */
    public function trackingForDelivery(Delivery $delivery): array
    {
        $delivery->loadMissing(['order', 'vendor']);
        $address = $delivery->order?->address_snapshot ?? [];

        $client = $this->point(
            $delivery->dropoff_latitude ?? $address['latitude'] ?? null,
            $delivery->dropoff_longitude ?? $address['longitude'] ?? null,
            'client',
            $address['full_address'] ?? null,
        );
        $shop = $this->point(
            $delivery->pickup_latitude ?? $delivery->vendor?->pickup_latitude ?? $delivery->vendor?->latitude,
            $delivery->pickup_longitude ?? $delivery->vendor?->pickup_longitude ?? $delivery->vendor?->longitude,
            'shop',
            $delivery->vendor?->pickup_address ?? $delivery->vendor?->address,
        );
        $driver = $this->positionForDelivery($delivery);

        return $this->assemble(
            $delivery->isTrackingActive() && $delivery->driver_profile_id !== null,
            $delivery->status?->value,
            $client,
            $shop,
            $driver,
            $this->isPickingUp($delivery->status) ? $shop : $client,
        );
    }

    /**
     * Suivi complet d'un colis (le point de collecte joue le rôle « boutique »).
     *
     * @return array<string, mixed>
     */
    public function trackingForParcel(Parcel $parcel): array
    {
        $pickup = $parcel->pickup_snapshot ?? [];
        $dropoff = $parcel->dropoff_snapshot ?? [];

        $client = $this->point(
            $dropoff['latitude'] ?? null,
            $dropoff['longitude'] ?? null,
            'client',
            $dropoff['address_text'] ?? $dropoff['full_address'] ?? null,
        );
        $shop = $this->point(
            $pickup['latitude'] ?? null,
            $pickup['longitude'] ?? null,
            'pickup',
            $pickup['address_text'] ?? $pickup['full_address'] ?? null,
        );
        $driver = $this->positionForParcel($parcel);
        $active = in_array($parcel->status, self::ACTIVE_PARCEL_STATUSES, true)
            && $parcel->driver_profile_id !== null;

        return $this->assemble(
            $active,
            $parcel->status?->value,
            $client,
            $shop,
            $driver,
            in_array($parcel->status, [ParcelStatus::Assigned, ParcelStatus::EnRoutePickup], true) ? $shop : $client,
        );
    }

    /**
     * @return Collection<int, Delivery>
     */
    private function activeDeliveries(DriverProfile $profile): Collection
    {
        return Delivery::query()
            ->where('driver_profile_id', $profile->id)
            ->whereIn('status', array_map(static fn (DeliveryStatus $status): string => $status->value, self::ACTIVE_DELIVERY_STATUSES))
            ->get();
    }

    /**
     * @return Collection<int, Parcel>
     */
    private function activeParcels(DriverProfile $profile): Collection
    {
        return Parcel::query()
            ->where('driver_profile_id', $profile->id)
            ->whereIn('status', array_map(static fn (ParcelStatus $status): string => $status->value, self::ACTIVE_PARCEL_STATUSES))
            ->get();
    }

    /**
     * @param  array<string, mixed>  $data
     * @return NormalizedLocationShape
     */
    private function normalize(array $data): array
    {
        $latitude = Geo::coordinate($data['latitude'] ?? null, -90, 90);
        $longitude = Geo::coordinate($data['longitude'] ?? null, -180, 180);

        if ($latitude === null || $longitude === null) {
            throw new DomainException('tracking.invalid_coordinates', 'Coordonnées GPS invalides.', 422);
        }

        $accuracy = $data['accuracy_m'] ?? $data['gps_accuracy_m'] ?? null;
        $accuracy = is_numeric($accuracy) ? (float) $accuracy : null;
        $maxAccuracy = (float) config('beninfood.geography.tracking.max_accuracy_m', 100);

        if ($accuracy !== null && $accuracy > $maxAccuracy) {
            throw new DomainException(
                'tracking.inaccurate_position',
                'Position GPS trop imprécise pour un suivi en direct.',
                422,
            );
        }

        $speed = $data['speed_mps'] ?? null;
        $speed = is_numeric($speed) ? (float) $speed : null;
        $maxSpeed = (float) config('beninfood.geography.tracking.max_speed_mps', 40);

        if ($speed !== null && $speed > $maxSpeed) {
            throw new DomainException('tracking.invalid_speed', 'Vitesse GPS incohérente.', 422);
        }

        $heading = $data['heading'] ?? null;
        $heading = is_numeric($heading) ? (float) $heading % 360 : null;
        $source = (string) ($data['location_source'] ?? $data['source'] ?? 'gps');
        if (! in_array($source, self::SOURCES, true)) {
            $source = 'gps';
        }

        $recordedAt = $data['location_recorded_at'] ?? $data['recorded_at'] ?? null;
        $recordedAt = $recordedAt instanceof CarbonInterface
            ? Carbon::instance($recordedAt)
            : ($recordedAt !== null && $recordedAt !== '' ? Carbon::parse((string) $recordedAt) : Carbon::now());
        $now = Carbon::now();

        if ($recordedAt->isFuture()) {
            $recordedAt = $now;
        }

        $maxAge = max(60, (int) config('beninfood.driver_selection.location_max_age_s', 300));
        if ($now->diffInSeconds($recordedAt) > $maxAge) {
            throw new DomainException('tracking.stale_position', 'Position GPS trop ancienne.', 422);
        }

        return [
            'latitude' => $latitude,
            'longitude' => $longitude,
            'accuracy_m' => $accuracy,
            'speed_mps' => $speed,
            'heading' => $heading,
            'source' => $source,
            'recorded_at' => $recordedAt,
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function cacheTime(string $key): ?Carbon
    {
        $value = Cache::get($key);

        if ($value instanceof CarbonInterface) {
            return Carbon::instance($value);
        }

        if (is_numeric($value)) {
            return Carbon::createFromTimestamp((int) $value);
        }

        return null;
    }

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

        $y = sin(deg2rad($dLng)) * cos(deg2rad($toLat));
        $x = cos(deg2rad($fromLat)) * sin(deg2rad($toLat))
            - sin(deg2rad($fromLat)) * cos(deg2rad($toLat)) * cos(deg2rad($dLng));

        return round((rad2deg(atan2($y, $x)) + 360) % 360, 2);
    }

    /**
     * @param  array<string, mixed>  $location
     * @return array<string, mixed>
     */
    private function driverPosition(
        float $latitude,
        float $longitude,
        array $location,
        Carbon $now,
        ?float $distanceKm = null,
    ): array {
        $recordedAt = $location['recorded_at'] instanceof CarbonInterface
            ? Carbon::instance($location['recorded_at'])
            : null;
        $age = $recordedAt !== null ? max(0, (int) $now->diffInSeconds($recordedAt)) : null;
        $staleWarn = (int) config('beninfood.tracking.stale_warn_s', 30);
        $staleHide = (int) config('beninfood.tracking.stale_hide_eta_s', 120);

        return [
            'latitude' => round($latitude, 6),
            'longitude' => round($longitude, 6),
            'heading' => $location['heading'] !== null ? (float) $location['heading'] : null,
            'accuracy_m' => $location['accuracy_m'] !== null ? (float) $location['accuracy_m'] : null,
            'speed_mps' => $location['speed_mps'] !== null ? (float) $location['speed_mps'] : null,
            'location_source' => $location['source'] ?? 'gps',
            'recorded_at' => $recordedAt?->toIso8601String(),
            // Alias historique consommé par les modèles Flutter existants.
            'last_location_at' => $recordedAt?->toIso8601String(),
            'age_seconds' => $age,
            'stale' => $age !== null && $age > $staleWarn,
            'eta_hidden' => $age !== null && $age > $staleHide,
            'distance_km' => $distanceKm !== null ? round($distanceKm, 3) : null,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function point(mixed $latitude, mixed $longitude, string $role, ?string $label): array
    {
        return [
            'latitude' => is_numeric($latitude) ? round((float) $latitude, 6) : null,
            'longitude' => is_numeric($longitude) ? round((float) $longitude, 6) : null,
            'role' => $role,
            'label' => $label,
        ];
    }

    /**
     * @param  array<string, mixed>  $client
     * @param  array<string, mixed>  $shop
     * @param  array<string, mixed>|null  $driver
     * @param  array<string, mixed>  $target
     * @return array<string, mixed>
     */
    private function assemble(
        bool $active,
        ?string $status,
        array $client,
        array $shop,
        ?array $driver,
        array $target,
    ): array {
        $straight = [
            'driver_client_km' => $driver === null ? null : Geo::haversineKm(
                $driver['latitude'], $driver['longitude'], $client['latitude'], $client['longitude'],
            ),
            'driver_shop_km' => $driver === null ? null : Geo::haversineKm(
                $driver['latitude'], $driver['longitude'], $shop['latitude'], $shop['longitude'],
            ),
            'shop_client_km' => Geo::haversineKm(
                $shop['latitude'], $shop['longitude'], $client['latitude'], $client['longitude'],
            ),
        ];

        foreach ($straight as $key => $value) {
            $straight[$key] = $value !== null ? round($value, 3) : null;
        }

        $road = null;
        if ($active && $driver !== null && $target['latitude'] !== null && $target['longitude'] !== null) {
            try {
                $route = $this->routing->plan([
                    ['latitude' => $driver['latitude'], 'longitude' => $driver['longitude']],
                    ['latitude' => $target['latitude'], 'longitude' => $target['longitude']],
                ]);
                $road = [
                    'provider' => $route['provider'],
                    'distance_m' => (int) $route['distance_m'],
                    'duration_s' => (int) $route['duration_s'],
                    'eta_s' => (int) $route['eta_s'],
                ];
            } catch (Throwable) {
                $road = null;
            }
        }

        $etaSeconds = $road['eta_s'] ?? null;
        $straightSeconds = $straight['driver_client_km'] !== null
            ? (int) round($straight['driver_client_km'] / max(1, (int) config('beninfood.routing.fallback_speed_kmh', 22)) * 3600
                * max(0.1, (float) config('beninfood.tracking.eta_coefficient', 1.3)))
            : null;

        return [
            'active' => $active,
            'status' => $status,
            'points' => [
                'client' => $client,
                'shop' => $shop,
                'driver' => $active ? $driver : null,
            ],
            'distances' => [
                'straight_km' => $straight,
                'road_m' => $road['distance_m'] ?? null,
                'road_provider' => $road['provider'] ?? null,
                'road_duration_s' => $road['duration_s'] ?? null,
            ],
            'eta' => [
                'seconds' => $etaSeconds ?? $straightSeconds,
                'minutes' => ($etaSeconds ?? $straightSeconds) !== null
                    ? (int) ceil(($etaSeconds ?? $straightSeconds) / 60)
                    : null,
                'source' => $etaSeconds !== null ? 'road' : 'straight',
                'provider' => $road['provider'] ?? 'straight',
                'available' => ($etaSeconds ?? $straightSeconds) !== null && ($driver['eta_hidden'] ?? false) === false,
            ],
            'legacy_position' => $active ? $driver : null,
        ];
    }

    private function isPickingUp(?DeliveryStatus $status): bool
    {
        return in_array($status, [DeliveryStatus::Assigned, DeliveryStatus::EnRoutePickup], true);
    }
}
