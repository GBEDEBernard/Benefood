<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Calcul d'itinéraires routiers pour la navigation des livreurs et le suivi
 * temps réel des clients (cahier v1.0).
 *
 * Le tracé suit les routes réelles : Google Routes API (mode deux-roues) est
 * privilégiée lorsqu'une clé est configurée, sinon OSRM (gratuit, sans clé).
 * En dernier recours — réseau indisponible — une ligne droite est renvoyée afin
 * que l'app affiche toujours une distance et une estimation.
 */
class RoutingService
{
    /**
     * Calcule un itinéraire passant par une liste de points (au moins 2).
     *
     * @param  array<int, array{latitude: float|int|string, longitude: float|int|string}>  $points
     * @return array{provider: string, distance_m: int, duration_s: int, geometry: array<int, array{0: float, 1: float}>, legs: array<int, array{distance_m: int, duration_s: int}>}
     */
    public function plan(array $points, string $profile = 'moto'): array
    {
        $coordinates = array_map(
            static fn (array $point): array => [(float) $point['latitude'], (float) $point['longitude']],
            array_values($points),
        );

        if (count($coordinates) < 2) {
            return $this->straightRoute($coordinates);
        }

        if (! $this->shouldCache()) {
            return $this->compute($coordinates, $profile);
        }

        return Cache::remember(
            $this->cacheKey($coordinates, $profile),
            now()->addSeconds((int) config('beninfood.routing.cache_ttl', 120)),
            fn (): array => $this->compute($coordinates, $profile),
        );
    }

    /**
     * @param  array<int, array{0: float, 1: float}>  $coordinates
     * @return array{provider: string, distance_m: int, duration_s: int, geometry: array<int, array{0: float, 1: float}>, legs: array<int, array{distance_m: int, duration_s: int}>}
     */
    private function compute(array $coordinates, string $profile): array
    {
        if (config('beninfood.routing.google_key')) {
            $google = $this->googleRoute($coordinates, $profile);
            if ($google !== null) {
                return $google;
            }
        }

        $osrm = $this->osrmRoute($coordinates);
        if ($osrm !== null) {
            return $osrm;
        }

        return $this->straightRoute($coordinates);
    }

    /**
     * @param  array<int, array{0: float, 1: float}>  $coordinates
     * @return array{provider: string, distance_m: int, duration_s: int, geometry: array<int, array{0: float, 1: float}>, legs: array<int, array{distance_m: int, duration_s: int}>}|null
     */
    private function googleRoute(array $coordinates, string $profile): ?array
    {
        $key = (string) config('beninfood.routing.google_key');
        $origin = $coordinates[0];
        $destination = $coordinates[array_key_last($coordinates)];
        $intermediates = array_slice($coordinates, 1, -1);

        $payload = [
            'origin' => ['location' => ['latLng' => ['latitude' => $origin[0], 'longitude' => $origin[1]]]],
            'destination' => ['location' => ['latLng' => ['latitude' => $destination[0], 'longitude' => $destination[1]]]],
            'travelMode' => $this->googleTravelMode($profile),
            'routingPreference' => 'TRAFFIC_AWARE',
            'polylineQuality' => 'HIGH_QUALITY',
            'computeAlternativeRoutes' => false,
            'languageCode' => 'fr-FR',
            'units' => 'METRIC',
        ];

        if ($intermediates !== []) {
            $payload['intermediates'] = array_map(
                static fn (array $point): array => ['location' => ['latLng' => ['latitude' => $point[0], 'longitude' => $point[1]]]],
                $intermediates,
            );
        }

        try {
            $response = Http::withHeaders([
                'X-Goog-Api-Key' => $key,
                'X-Goog-FieldMask' => 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.duration,routes.legs.distanceMeters',
                'Accept' => 'application/json',
            ])->timeout($this->timeout())->post((string) config('beninfood.routing.google_url'), $payload);
        } catch (Throwable) {
            return null;
        }

        if (! $response->successful()) {
            return null;
        }

        $route = $response->json('routes.0');
        if (! is_array($route) || ! is_string($route['polyline']['encodedPolyline'] ?? null)) {
            return null;
        }

        return [
            'provider' => 'google',
            'distance_m' => (int) ($route['distanceMeters'] ?? 0),
            'duration_s' => $this->parseGoogleDuration($route['duration'] ?? null),
            'geometry' => $this->decodePolyline($route['polyline']['encodedPolyline']),
            'legs' => $this->mapGoogleLegs($route['legs'] ?? []),
        ];
    }

    /**
     * @param  array<int, array{0: float, 1: float}>  $coordinates
     * @return array{provider: string, distance_m: int, duration_s: int, geometry: array<int, array{0: float, 1: float}>, legs: array<int, array{distance_m: int, duration_s: int}>}|null
     */
    private function osrmRoute(array $coordinates): ?array
    {
        $path = implode(';', array_map(
            static fn (array $point): string => $point[1].','.$point[0],
            $coordinates,
        ));

        try {
            $response = Http::timeout($this->timeout())
                ->acceptJson()
                ->get((string) config('beninfood.routing.osrm_url').'/route/v1/driving/'.$path, [
                    'overview' => 'full',
                    'geometries' => 'geojson',
                    'steps' => 'false',
                ]);
        } catch (Throwable) {
            return null;
        }

        if (! $response->successful()) {
            return null;
        }

        $route = $response->json('routes.0');
        if (! is_array($route) || ! is_array($route['geometry']['coordinates'] ?? null)) {
            return null;
        }

        $geometry = array_map(
            static fn (array $pair): array => [(float) $pair[1], (float) $pair[0]],
            $route['geometry']['coordinates'],
        );

        return [
            'provider' => 'osrm',
            'distance_m' => (int) round((float) ($route['distance'] ?? 0)),
            'duration_s' => (int) round((float) ($route['duration'] ?? 0)),
            'geometry' => $geometry,
            'legs' => array_map(
                static fn (array $leg): array => [
                    'distance_m' => (int) round((float) ($leg['distance'] ?? 0)),
                    'duration_s' => (int) round((float) ($leg['duration'] ?? 0)),
                ],
                $route['legs'] ?? [],
            ),
        ];
    }

    /**
     * Repli géométrique : segments à vol d'oiseau, vitesse urbaine moyenne.
     *
     * @param  array<int, array{0: float, 1: float}>  $coordinates
     * @return array{provider: string, distance_m: int, duration_s: int, geometry: array<int, array{0: float, 1: float}>, legs: array<int, array{distance_m: int, duration_s: int}>}
     */
    private function straightRoute(array $coordinates): array
    {
        $speed = max(1, (int) config('beninfood.routing.fallback_speed_kmh', 22));
        $legs = [];
        $totalMeters = 0.0;
        $totalSeconds = 0.0;

        for ($i = 0; $i < count($coordinates) - 1; $i++) {
            $km = $this->haversineKm($coordinates[$i], $coordinates[$i + 1]);
            $meters = $km * 1000;
            $seconds = $km / $speed * 3600;
            $legs[] = ['distance_m' => (int) round($meters), 'duration_s' => (int) round($seconds)];
            $totalMeters += $meters;
            $totalSeconds += $seconds;
        }

        return [
            'provider' => 'straight',
            'distance_m' => (int) round($totalMeters),
            'duration_s' => (int) round($totalSeconds),
            'geometry' => $coordinates,
            'legs' => $legs,
        ];
    }

    private function googleTravelMode(string $profile): string
    {
        return match ($profile) {
            'car' => 'DRIVE',
            'foot' => 'WALK',
            default => 'TWO_WHEELER',
        };
    }

    /** Convertit une durée Google (`"123s"`) en secondes entières. */
    private function parseGoogleDuration(mixed $duration): int
    {
        if (is_string($duration)) {
            return (int) rtrim($duration, 's');
        }

        return (int) $duration;
    }

    /**
     * @param  array<int, array<string, mixed>>  $legs
     * @return array<int, array{distance_m: int, duration_s: int}>
     */
    private function mapGoogleLegs(array $legs): array
    {
        return array_map(
            fn (array $leg): array => [
                'distance_m' => (int) ($leg['distanceMeters'] ?? 0),
                'duration_s' => $this->parseGoogleDuration($leg['duration'] ?? null),
            ],
            array_values($legs),
        );
    }

    /**
     * Décode une polyligne encodée (algorithme Google) en paires [lat, lng].
     *
     * @return array<int, array{0: float, 1: float}>
     */
    private function decodePolyline(string $encoded): array
    {
        $points = [];
        $index = 0;
        $lat = 0;
        $lng = 0;
        $length = strlen($encoded);

        while ($index < $length) {
            $shift = 0;
            $result = 0;
            do {
                $byte = ord($encoded[$index++]) - 63;
                $result |= ($byte & 0x1F) << $shift;
                $shift += 5;
            } while ($byte >= 0x20);
            $lat += ($result & 1) ? ~($result >> 1) : ($result >> 1);

            $shift = 0;
            $result = 0;
            do {
                $byte = ord($encoded[$index++]) - 63;
                $result |= ($byte & 0x1F) << $shift;
                $shift += 5;
            } while ($byte >= 0x20);
            $lng += ($result & 1) ? ~($result >> 1) : ($result >> 1);

            $points[] = [$lat / 1e5, $lng / 1e5];
        }

        return $points;
    }

    /**
     * @param  array{0: float, 1: float}  $from
     * @param  array{0: float, 1: float}  $to
     */
    private function haversineKm(array $from, array $to): float
    {
        $earthRadius = 6371.0088;
        $dLat = deg2rad($to[0] - $from[0]);
        $dLng = deg2rad($to[1] - $from[1]);
        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($from[0])) * cos(deg2rad($to[0])) * sin($dLng / 2) ** 2;

        return $earthRadius * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }

    private function timeout(): int
    {
        return max(1, (int) config('beninfood.routing.timeout', 6));
    }

    private function shouldCache(): bool
    {
        return ! app()->runningUnitTests();
    }

    /**
     * @param  array<int, array{0: float, 1: float}>  $coordinates
     */
    private function cacheKey(array $coordinates, string $profile): string
    {
        $rounded = array_map(
            static fn (array $point): array => [round($point[0], 4), round($point[1], 4)],
            $coordinates,
        );

        return 'routing:'.md5($profile.'|'.json_encode($rounded));
    }
}
