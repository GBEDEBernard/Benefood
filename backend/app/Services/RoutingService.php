<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Calcul d'itinéraires routiers pour la navigation des livreurs et le suivi
 * temps réel des clients (cahier v1.0).
 *
 * Le tracé suit les routes réelles : Google Routes API (mode deux-roues) est
 * privilégiée lorsqu'une clé est configurée, sinon OSRM (gratuit, sans clé).
 * En dernier recours — réseau indisponible — une ligne droite est renvoyée afin
 * que l'app affiche toujours une distance et une estimation.
 *
 * @phpstan-type RouteStepShape array{type: string, modifier: string|null, instruction: string, name: string, distance_m: int, duration_s: int, geometry: array<int, array{0: float, 1: float}>}
 * @phpstan-type RouteShape array{provider: string, distance_m: int, duration_s: int, eta_s: int, geometry: array<int, array{0: float, 1: float}>, legs: array<int, array{distance_m: int, duration_s: int}>, steps: array<int, RouteStepShape>}
 */
class RoutingService
{
    /**
     * Modifiers OSRM traduits en français (phrases complètes pour l'instruction).
     *
     * @var array<string, string>
     */
    private const OSRM_MODIFIERS_FR = [
        'uturn' => 'en faisant demi-tour',
        'sharp right' => 'franchement à droite',
        'right' => 'à droite',
        'slight right' => 'légèrement à droite',
        'straight' => 'tout droit',
        'slight left' => 'légèrement à gauche',
        'left' => 'à gauche',
        'sharp left' => 'franchement à gauche',
    ];

    /**
     * Manœuvres Google (`navigationInstructions.maneuver`) vers la taxonomie OSRM.
     *
     * @var array<string, string>
     */
    private const GOOGLE_MANEUVERS = [
        'DEPART' => 'depart',
        'TURN_LEFT' => 'turn',
        'TURN_RIGHT' => 'turn',
        'STRAIGHT' => 'continue',
        'UTURN_LEFT' => 'uturn',
        'UTURN_RIGHT' => 'uturn',
        'SHARP_LEFT' => 'turn',
        'SHARP_RIGHT' => 'turn',
        'SLIGHT_LEFT' => 'turn',
        'SLIGHT_RIGHT' => 'turn',
        'ROUNDABOUT_LEFT' => 'roundabout',
        'ROUNDABOUT_RIGHT' => 'roundabout',
        'ROUNDABOUT_TURN' => 'roundabout',
        'EXIT_ROUNDABOUT_LEFT' => 'roundabout',
        'EXIT_ROUNDABOUT_RIGHT' => 'roundabout',
        'EXIT_ROTARY_LEFT' => 'rotary',
        'EXIT_ROTARY_RIGHT' => 'rotary',
        'ROTARY' => 'rotary',
        'RAMP_LEFT' => 'on ramp',
        'RAMP_RIGHT' => 'on ramp',
        'FORK_LEFT' => 'fork',
        'FORK_RIGHT' => 'fork',
        'MERGE' => 'merge',
        'FERRY' => 'continue',
    ];

    /**
     * Modifiers Google vers la taxonomie OSRM.
     *
     * @var array<string, string>
     */
    private const GOOGLE_MODIFIERS = [
        'TURN_LEFT' => 'left',
        'TURN_RIGHT' => 'right',
        'STRAIGHT' => 'straight',
        'UTURN_LEFT' => 'uturn',
        'UTURN_RIGHT' => 'uturn',
        'SHARP_LEFT' => 'sharp left',
        'SHARP_RIGHT' => 'sharp right',
        'SLIGHT_LEFT' => 'slight left',
        'SLIGHT_RIGHT' => 'slight right',
        'ROUNDABOUT_LEFT' => 'left',
        'ROUNDABOUT_RIGHT' => 'right',
        'ROUNDABOUT_TURN' => 'straight',
        'EXIT_ROUNDABOUT_LEFT' => 'left',
        'EXIT_ROUNDABOUT_RIGHT' => 'right',
        'EXIT_ROTARY_LEFT' => 'left',
        'EXIT_ROTARY_RIGHT' => 'right',
        'ROTARY' => 'straight',
        'RAMP_LEFT' => 'slight left',
        'RAMP_RIGHT' => 'slight right',
        'FORK_LEFT' => 'slight left',
        'FORK_RIGHT' => 'slight right',
        'MERGE' => 'straight',
        'FERRY' => 'straight',
        'DEPART' => 'straight',
    ];

    /**
     * Types de manœuvres OpenRouteService vers la taxonomie OSRM.
     *
     * @var array<int, array{0: string, 1: string|null}>
     */
    private const ORS_MANEUVERS = [
        0 => ['turn', 'left'],
        1 => ['turn', 'right'],
        2 => ['turn', 'sharp left'],
        3 => ['turn', 'sharp right'],
        4 => ['turn', 'slight left'],
        5 => ['turn', 'slight right'],
        6 => ['continue', 'straight'],
        7 => ['roundabout', null],
        8 => ['roundabout', null],
        10 => ['depart', 'straight'],
        11 => ['arrive', null],
        12 => ['fork', 'left'],
        13 => ['fork', 'right'],
    ];

    /**
     * Calcule un itinéraire passant par une liste de points (au moins 2).
     *
     * @param  array<int, array{latitude: float|int|string, longitude: float|int|string}>  $points
     * @return RouteShape
     */
    public function plan(array $points, string $profile = 'moto'): array
    {
        $coordinates = array_map(
            static fn (array $point): array => [(float) $point['latitude'], (float) $point['longitude']],
            array_values($points),
        );

        if (count($coordinates) < 2) {
            return $this->withEta($this->straightRoute($coordinates));
        }

        $route = $this->shouldCache()
            ? Cache::remember(
                $this->cacheKey($coordinates, $profile),
                now()->addSeconds((int) config('beninfood.routing.cache_ttl', 120)),
                fn (): array => $this->compute($coordinates, $profile),
            )
            : $this->compute($coordinates, $profile);

        return $this->withEta($route);
    }

    /**
     * Ajoute l'ETA commerciale (durée brute × coefficient de prudence).
     *
     * @param  RouteShape  $route
     * @return RouteShape
     */
    private function withEta(array $route): array
    {
        $coefficient = max(0.1, (float) config('beninfood.tracking.eta_coefficient', 1.3));
        $route['eta_s'] = (int) round($route['duration_s'] * $coefficient);

        return $route;
    }

    /**
     * @param  array<int, array{0: float, 1: float}>  $coordinates
     * @return RouteShape
     */
    private function compute(array $coordinates, string $profile): array
    {
        if (config('beninfood.routing.google_key')) {
            $google = $this->googleRoute($coordinates, $profile);
            if ($google !== null) {
                return $google;
            }
        }

        if (config('beninfood.routing.ors_key')) {
            $ors = $this->orsRoute($coordinates, $profile);
            if ($ors !== null) {
                return $ors;
            }
        }

        if ($this->shouldUseOsrm()) {
            $osrm = $this->osrmRoute($coordinates);
            if ($osrm !== null) {
                return $osrm;
            }
        }

        return $this->straightRoute($coordinates);
    }

    /**
     * @param  array<int, array{0: float, 1: float}>  $coordinates
     * @return RouteShape|null
     */
    private function orsRoute(array $coordinates, string $profile): ?array
    {
        $url = (string) config('beninfood.routing.ors_url').'/'.$this->orsProfile($profile).'/geojson';

        try {
            $response = Http::withToken((string) config('beninfood.routing.ors_key'))
                ->acceptJson()
                ->timeout($this->timeout())
                ->post($url, [
                    'coordinates' => array_map(
                        static fn (array $point): array => [$point[1], $point[0]],
                        $coordinates,
                    ),
                    'instructions' => true,
                    'language' => 'fr',
                    'units' => 'm',
                ]);
        } catch (Throwable $exception) {
            Log::warning('routing.ors_failed', ['message' => $exception->getMessage()]);

            return null;
        }

        if (! $response->successful()) {
            Log::warning('routing.ors_failed', ['status' => $response->status()]);

            return null;
        }

        $feature = $response->json('features.0');
        if (! is_array($feature)) {
            return null;
        }

        $rawCoordinates = $feature['geometry']['coordinates'] ?? null;
        if (! is_array($rawCoordinates)) {
            return null;
        }

        $geometry = array_map(
            static fn (array $pair): array => [(float) $pair[1], (float) $pair[0]],
            $rawCoordinates,
        );
        $properties = is_array($feature['properties'] ?? null) ? $feature['properties'] : [];
        $summary = is_array($properties['summary'] ?? null) ? $properties['summary'] : [];
        $segments = is_array($properties['segments'] ?? null) ? $properties['segments'] : [];

        return [
            'provider' => 'ors',
            'distance_m' => (int) round((float) ($summary['distance'] ?? 0)),
            'duration_s' => (int) round((float) ($summary['duration'] ?? 0)),
            'geometry' => $geometry,
            'legs' => array_map(
                static fn (array $segment): array => [
                    'distance_m' => (int) round((float) ($segment['distance'] ?? 0)),
                    'duration_s' => (int) round((float) ($segment['duration'] ?? 0)),
                ],
                $segments,
            ),
            'steps' => $this->mapOrsSteps($segments, $geometry),
        ];
    }

    /**
     * @param  array<int, array<string, mixed>>  $segments
     * @param  array<int, array{0: float, 1: float}>  $geometry
     * @return array<int, RouteStepShape>
     */
    private function mapOrsSteps(array $segments, array $geometry): array
    {
        $steps = [];

        foreach ($segments as $segment) {
            foreach (is_array($segment['steps'] ?? null) ? $segment['steps'] : [] as $step) {
                if (! is_array($step)) {
                    continue;
                }

                [$type, $modifier] = self::ORS_MANEUVERS[(int) ($step['type'] ?? 6)] ?? ['continue', 'straight'];
                $name = (string) ($step['name'] ?? '');
                $instruction = trim((string) ($step['instruction'] ?? ''));

                $steps[] = [
                    'type' => $type,
                    'modifier' => $modifier,
                    'instruction' => $instruction !== ''
                        ? $instruction
                        : $this->osrmInstruction($type, $modifier, $name, []),
                    'name' => $name,
                    'distance_m' => (int) round((float) ($step['distance'] ?? 0)),
                    'duration_s' => (int) round((float) ($step['duration'] ?? 0)),
                    'geometry' => $this->orsStepGeometry($step, $geometry),
                ];
            }
        }

        return $steps;
    }

    /**
     * @param  array<string, mixed>  $step
     * @param  array<int, array{0: float, 1: float}>  $geometry
     * @return array<int, array{0: float, 1: float}>
     */
    private function orsStepGeometry(array $step, array $geometry): array
    {
        $wayPoints = $step['way_points'] ?? null;
        if (! is_array($wayPoints) || count($wayPoints) < 2) {
            return [];
        }

        $start = (int) $wayPoints[0];
        $end = (int) $wayPoints[1];

        return array_slice($geometry, $start, max(0, $end - $start + 1));
    }

    private function orsProfile(string $profile): string
    {
        return match ($profile) {
            'foot' => 'foot-walking',
            default => 'driving-car',
        };
    }

    private function shouldUseOsrm(): bool
    {
        $url = (string) config('beninfood.routing.osrm_url');
        if ($url === '') {
            return false;
        }

        $host = strtolower((string) parse_url($url, PHP_URL_HOST));

        if ((bool) config('beninfood.routing.allow_public_osrm', false)) {
            return true;
        }

        return ! str_contains($host, 'project-osrm.org');
    }

    /**
     * @param  array<int, array{0: float, 1: float}>  $coordinates
     * @return RouteShape|null
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
                'X-Goog-FieldMask' => 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.duration,routes.legs.distanceMeters,routes.legs.steps.distanceMeters,routes.legs.steps.duration,routes.legs.steps.polyline.encodedPolyline,routes.legs.steps.navigationInstructions,routes.legs.steps.startLocation,routes.legs.steps.endLocation',
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
            'steps' => $this->mapGoogleSteps($route['legs'] ?? []),
        ];
    }

    /**
     * @param  array<int, array{0: float, 1: float}>  $coordinates
     * @return RouteShape|null
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
                    'steps' => 'true',
                    'language' => 'fr',
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
            'steps' => $this->mapOsrmSteps($route['legs'] ?? []),
        ];
    }

    /**
     * Repli géométrique : segments à vol d'oiseau, vitesse urbaine moyenne.
     *
     * @param  array<int, array{0: float, 1: float}>  $coordinates
     * @return RouteShape
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
            'steps' => [],
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
     * Aplatit les steps des legs OSRM en liste d'instructions normalisées.
     *
     * @param  array<int, array<string, mixed>>  $legs
     * @return array<int, RouteStepShape>
     */
    private function mapOsrmSteps(array $legs): array
    {
        $steps = [];

        foreach ($legs as $leg) {
            foreach (is_array($leg['steps'] ?? null) ? $leg['steps'] : [] as $step) {
                if (! is_array($step)) {
                    continue;
                }

                $maneuver = is_array($step['maneuver'] ?? null) ? $step['maneuver'] : [];
                $type = (string) ($maneuver['type'] ?? 'continue');
                $modifier = isset($maneuver['modifier']) ? (string) $maneuver['modifier'] : null;
                $name = (string) ($step['name'] ?? '');

                $steps[] = [
                    'type' => $type,
                    'modifier' => $modifier,
                    'instruction' => $this->osrmInstruction($type, $modifier, $name, $maneuver),
                    'name' => $name,
                    'distance_m' => (int) round((float) ($step['distance'] ?? 0)),
                    'duration_s' => (int) round((float) ($step['duration'] ?? 0)),
                    'geometry' => $this->mapOsrmStepGeometry($step),
                ];
            }
        }

        return $steps;
    }

    /**
     * @param  array<string, mixed>  $step
     * @return array<int, array{0: float, 1: float}>
     */
    private function mapOsrmStepGeometry(array $step): array
    {
        $coordinates = $step['geometry']['coordinates'] ?? null;

        if (! is_array($coordinates)) {
            return [];
        }

        return array_map(
            static fn (array $pair): array => [(float) $pair[1], (float) $pair[0]],
            $coordinates,
        );
    }

    /**
     * Construit une instruction française à partir d'une manœuvre OSRM.
     *
     * @param  array<string, mixed>  $maneuver
     */
    private function osrmInstruction(string $type, ?string $modifier, string $name, array $maneuver): string
    {
        $street = $name !== '' ? ' sur '.$name : '';

        return match ($type) {
            'depart' => 'Partez'.$street,
            'arrive' => 'Vous êtes arrivé',
            'roundabout', 'rotary', 'roundabout turn' => sprintf(
                'Au rond-point, prenez la sortie %s%s',
                isset($maneuver['exit']) ? (string) $maneuver['exit'] : '',
                $street,
            ),
            'merge' => 'Rejoignez la voie'.$street,
            'on ramp' => 'Prenez la rampe'.$street,
            'off ramp' => 'Prenez la sortie'.$street,
            'fork' => 'Restez '.$this->modifierFr($modifier).$street,
            'end of road' => 'À la fin de la route, tournez '.$this->modifierFr($modifier).$street,
            'turn' => 'Tournez '.$this->modifierFr($modifier).$street,
            'new name' => 'Continuez'.$street,
            'notification' => $name !== '' ? 'Suivez '.$name : 'Continuez',
            default => 'Continuez '.$this->modifierFr($modifier).$street,
        };
    }

    private function modifierFr(?string $modifier): string
    {
        return self::OSRM_MODIFIERS_FR[$modifier] ?? 'tout droit';
    }

    /**
     * Aplatit les steps des legs Google en liste d'instructions normalisées.
     *
     * @param  array<int, array<string, mixed>>  $legs
     * @return array<int, RouteStepShape>
     */
    private function mapGoogleSteps(array $legs): array
    {
        $steps = [];

        foreach ($legs as $leg) {
            foreach (is_array($leg['steps'] ?? null) ? $leg['steps'] : [] as $step) {
                if (! is_array($step)) {
                    continue;
                }

                $navigation = is_array($step['navigationInstructions'] ?? null) ? $step['navigationInstructions'] : [];
                $maneuverEnum = (string) ($navigation['maneuver'] ?? 'STRAIGHT');
                $type = self::GOOGLE_MANEUVERS[$maneuverEnum] ?? 'continue';
                $modifier = self::GOOGLE_MODIFIERS[$maneuverEnum] ?? null;
                $name = (string) ($step['streetName'] ?? '');

                // L'instruction Google est déjà en français (`languageCode: fr-FR`).
                $instruction = trim((string) ($navigation['instructions'] ?? ''));
                if ($instruction === '') {
                    $instruction = $this->osrmInstruction($type, $modifier, $name, []);
                }

                $steps[] = [
                    'type' => $type,
                    'modifier' => $modifier,
                    'instruction' => $instruction,
                    'name' => $name,
                    'distance_m' => (int) round((float) ($step['distanceMeters'] ?? 0)),
                    'duration_s' => $this->parseGoogleDuration($step['duration'] ?? null),
                    'geometry' => $this->mapGoogleStepGeometry($step),
                ];
            }
        }

        return $steps;
    }

    /**
     * @param  array<string, mixed>  $step
     * @return array<int, array{0: float, 1: float}>
     */
    private function mapGoogleStepGeometry(array $step): array
    {
        $encoded = $step['polyline']['encodedPolyline'] ?? null;

        return is_string($encoded) ? $this->decodePolyline($encoded) : [];
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
