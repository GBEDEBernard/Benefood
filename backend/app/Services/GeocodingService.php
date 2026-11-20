<?php

namespace App\Services;

use App\Models\GeoCountry;
use App\Models\GeoDivision;
use App\Models\GeoLocality;
use App\Support\Geo;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Couche de géocodage interchangeable, exécutée uniquement côté serveur.
 *
 * Le référentiel IGN est toujours consulté en premier : recherche textuelle,
 * géocodage inversé et hiérarchie administrative. Les fournisseurs externes
 * (Nominatim, Mapbox, Google) ne servent qu'aux adresses libres et aux pays
 * absents du référentiel. Leurs clés ne sont jamais envoyées au client.
 *
 * @phpstan-type CandidateShape array{provider: string, label: string, latitude: float, longitude: float, components: array<string, string|null>, place_id: string|null, source: string|null, source_url: string|null, data_updated_at: string|null}
 */
final class GeocodingService
{
    /**
     * @param  array<string, mixed>  $filters
     * @return array<int, array<string, mixed>>
     */
    public function searchLocal(string $query, array $filters = [], int $limit = 20): array
    {
        $term = $this->searchTerm($query);
        if ($term === '') {
            return [];
        }

        $limit = min(max(1, $limit), (int) config('beninfood.pagination.max_per_page', 100));
        $countryId = $this->countryId($filters);

        $divisions = GeoDivision::query()
            ->active()
            ->when($countryId !== null, fn ($queryBuilder) => $queryBuilder->where('country_id', $countryId))
            ->when(isset($filters['level']), fn ($queryBuilder) => $queryBuilder->where('level', $filters['level']))
            ->when(isset($filters['parent_id']), fn ($queryBuilder) => $queryBuilder->where('parent_id', $filters['parent_id']))
            ->where(function ($queryBuilder) use ($term): void {
                $queryBuilder
                    ->where('name_normalized', 'like', '%'.$term.'%')
                    ->orWhere('code', 'like', '%'.$term.'%');
            })
            ->with('country', 'parent.parent.parent')
            ->orderByRaw('char_length(name_normalized)')
            ->orderBy('name')
            ->limit($limit)
            ->get();

        $localities = GeoLocality::query()
            ->active()
            ->when($countryId !== null, fn ($queryBuilder) => $queryBuilder->where('country_id', $countryId))
            ->when(isset($filters['division_id']), fn ($queryBuilder) => $queryBuilder->where('division_id', $filters['division_id']))
            ->where(function ($queryBuilder) use ($term): void {
                $queryBuilder
                    ->where('name_normalized', 'like', '%'.$term.'%')
                    ->orWhere('code', 'like', '%'.$term.'%');
            })
            ->with('division.country', 'division.parent.parent.parent')
            ->orderByRaw('char_length(name_normalized)')
            ->orderBy('name')
            ->limit($limit)
            ->get();

        return [
            ...$divisions->map(fn (GeoDivision $division): array => $this->divisionCandidate($division))->all(),
            ...$localities->map(fn (GeoLocality $locality): array => $this->localityCandidate($locality))->all(),
        ];
    }

    /**
     * Géocode une adresse libre avec le fournisseur configuré. Le référentiel
     * local est d'abord interrogé pour éviter un appel externe inutile.
     *
     * @param  array<string, mixed>  $context
     * @return array{provider: string, results: array<int, array<string, mixed>>}
     */
    public function geocode(string $query, array $context = [], int $limit = 5): array
    {
        $query = trim($query);
        if ($query === '') {
            return ['provider' => 'local', 'results' => []];
        }

        $local = $this->searchLocal($query, $context, $limit);
        if ($local !== [] && $this->isExactAdministrativeMatch($local, $query)) {
            return ['provider' => 'local', 'results' => array_slice($local, 0, $limit)];
        }

        $provider = $this->provider();
        if ($provider === 'local' || ! $this->hasCredentials($provider)) {
            return ['provider' => 'local', 'results' => array_slice($local, 0, $limit)];
        }

        $limit = min(max(1, $limit), 5);
        $cacheKey = $this->cacheKey('geocode', $provider, $query, $context, $limit);

        /** @var array<int, array<string, mixed>> $results */
        $results = Cache::remember(
            $cacheKey,
            now()->addSeconds((int) config('beninfood.geography.geocoding.cache_ttl', 86400)),
            fn (): array => $this->allowExternalRequest($provider)
                ? $this->providerGeocode($provider, $query, $context, $limit)
                : [],
        );

        return ['provider' => $provider, 'results' => $results];
    }

    /**
     * Géocodage inversé strictement local : uniquement le référentiel officiel,
     * sans appel réseau. Utilisé lors de la validation des formulaires pour ne
     * jamais déclencher de requête externe à chaque enregistrement.
     *
     * @return array<string, mixed>|null
     */
    public function reverseLocal(float $latitude, float $longitude, ?string $countryCode = null): ?array
    {
        $country = $countryCode !== null
            ? GeoCountry::query()->active()->where('code', strtoupper($countryCode))->first()
            : null;

        $division = $this->divisionAtPoint($latitude, $longitude, $country?->id);
        if ($division === null) {
            return null;
        }

        $locality = $this->nearestLocality($division, $latitude, $longitude);
        $label = $locality?->displayPath() ?? $division->displayPath();
        $pointLatitude = $locality?->latitude ?? $division->center_latitude ?? $latitude;
        $pointLongitude = $locality?->longitude ?? $division->center_longitude ?? $longitude;
        $source = $locality?->source ?? $division->source;
        $sourceUrl = $locality?->source_url ?? $division->source_url;
        $updatedAt = $locality?->data_updated_at ?? $division->data_updated_at;

        return [
            'provider' => 'local',
            'label' => $label,
            'latitude' => (float) $pointLatitude,
            'longitude' => (float) $pointLongitude,
            'distance_m' => $locality === null
                ? null
                : (int) round(Geo::haversineKm($latitude, $longitude, $locality->latitude, $locality->longitude) * 1000),
            'components' => $this->components($division, $locality),
            'division' => $division->id,
            'locality' => $locality?->id,
            'place_id' => $locality?->code ?? $division->code,
            'source' => $source,
            'source_url' => $sourceUrl,
            'data_updated_at' => $updatedAt?->toDateString(),
        ];
    }

    /**
     * Géocodage inversé : rattachement administratif officiel en priorité,
     * fournisseur externe uniquement en repli hors référentiel.
     *
     * @return array<string, mixed>|null
     */
    public function reverse(float $latitude, float $longitude, ?string $countryCode = null): ?array
    {
        $local = $this->reverseLocal($latitude, $longitude, $countryCode);
        if ($local !== null) {
            return $local;
        }

        $provider = $this->provider();
        if ($provider === 'local' || ! $this->hasCredentials($provider)) {
            return null;
        }

        $cacheKey = $this->cacheKey('reverse', $provider, (string) $latitude, (string) $longitude, ['country' => $countryCode]);
        $coordinates = [
            'latitude' => round($latitude, 5),
            'longitude' => round($longitude, 5),
        ];

        /** @var array<string, mixed>|null $result */
        $result = Cache::remember(
            $cacheKey,
            now()->addSeconds((int) config('beninfood.geography.geocoding.cache_ttl', 86400)),
            fn (): ?array => $this->allowExternalRequest($provider)
                ? $this->providerReverse($provider, $coordinates['latitude'], $coordinates['longitude'], $countryCode)
                : null,
        );

        return $result;
    }

    /**
     * @param  array<int, array<string, mixed>>  $candidates
     */
    private function isExactAdministrativeMatch(array $candidates, string $query): bool
    {
        $needle = Geo::normalizeName($query);
        if ($needle === '') {
            return false;
        }

        foreach ($candidates as $candidate) {
            if (($candidate['name_normalized'] ?? null) === $needle) {
                return true;
            }
        }

        return false;
    }

    private function divisionCandidate(GeoDivision $division): array
    {
        return [
            'kind' => 'division',
            'id' => $division->id,
            'name' => $division->name,
            'name_normalized' => $division->name_normalized,
            'label' => $division->displayPath(),
            'level' => $division->level,
            'path' => $division->path(),
            'code' => $division->code,
            'latitude' => $division->center_latitude,
            'longitude' => $division->center_longitude,
            'components' => $this->components($division),
            'source' => $division->source,
            'source_url' => $division->source_url,
            'data_updated_at' => $division->data_updated_at?->toDateString(),
        ];
    }

    private function localityCandidate(GeoLocality $locality): array
    {
        return [
            'kind' => 'locality',
            'id' => $locality->id,
            'name' => $locality->name,
            'name_normalized' => $locality->name_normalized,
            'label' => $locality->displayPath(),
            'level' => 'locality',
            'path' => [...($locality->division?->path() ?? []), $locality->name],
            'code' => $locality->code,
            'latitude' => $locality->latitude,
            'longitude' => $locality->longitude,
            'locality_kind' => $locality->kind,
            'components' => $this->components($locality->division, $locality),
            'source' => $locality->source,
            'source_url' => $locality->source_url,
            'data_updated_at' => $locality->data_updated_at?->toDateString(),
        ];
    }

    /**
     * @return array<string, string|null>
     */
    private function components(?GeoDivision $division, ?GeoLocality $locality = null): array
    {
        if ($division === null) {
            return ['country' => null];
        }

        $parts = $division->path();
        $countryName = array_shift($parts);
        $country = $division->country;
        $slugs = array_column($country?->hierarchy() ?? [], 'slug');

        $components = ['country' => $countryName];
        foreach ($parts as $index => $part) {
            $components[$slugs[$index] ?? 'level_'.($index + 1)] = $part;
        }

        if ($locality !== null) {
            $components['locality'] = $locality->name;
            $components['locality_kind'] = $locality->kind;
        }

        return $components;
    }

    private function divisionAtPoint(float $latitude, float $longitude, ?int $countryId): ?GeoDivision
    {
        $divisions = GeoDivision::query()
            ->active()
            ->when($countryId !== null, fn ($query) => $query->where('country_id', $countryId))
            ->whereNotNull('geometry_json')
            ->with('country', 'parent.parent.parent')
            ->get();

        /** @var array<int, array{division: GeoDivision, depth: int}> $matches */
        $matches = [];
        foreach ($divisions as $division) {
            if ($latitude < $division->bbox_min_latitude || $latitude > $division->bbox_max_latitude
                || $longitude < $division->bbox_min_longitude || $longitude > $division->bbox_max_longitude) {
                continue;
            }

            $geometry = json_decode((string) $division->geometry_json, true);
            if (! Geo::pointInGeometry($latitude, $longitude, $geometry)) {
                continue;
            }

            $depth = 0;
            $parent = $division->parent;
            while ($parent !== null) {
                $depth++;
                $parent = $parent->parent;
            }
            $matches[] = ['division' => $division, 'depth' => $depth];
        }

        if ($matches === []) {
            return null;
        }

        usort($matches, static fn (array $left, array $right): int => $right['depth'] <=> $left['depth']);

        return $matches[0]['division'];
    }

    private function nearestLocality(GeoDivision $division, float $latitude, float $longitude): ?GeoLocality
    {
        /** @var array<int, array{locality: GeoLocality, distance: float}> $nearest */
        $nearest = [];
        foreach ($division->localities()->active()->get() as $locality) {
            $distance = Geo::haversineKm($latitude, $longitude, $locality->latitude, $locality->longitude);
            if ($distance === null) {
                continue;
            }
            $nearest[] = ['locality' => $locality, 'distance' => $distance];
        }

        if ($nearest === []) {
            return null;
        }

        usort($nearest, static fn (array $left, array $right): int => $left['distance'] <=> $right['distance']);

        // Au-delà de 3 km, la localité n'est pas considérée comme le lieu du point.
        return $nearest[0]['distance'] <= 3 ? $nearest[0]['locality'] : null;
    }

    private function provider(): string
    {
        $provider = strtolower((string) config('beninfood.geography.geocoding.provider', 'nominatim'));

        return match ($provider) {
            'mapbox', 'google', 'local' => $provider,
            default => 'nominatim',
        };
    }

    private function hasCredentials(string $provider): bool
    {
        return match ($provider) {
            'mapbox' => (string) config('beninfood.geography.geocoding.mapbox_token') !== '',
            'google' => (string) config('beninfood.geography.geocoding.google_key') !== '',
            default => true,
        };
    }

    /**
     * @param  array<string, mixed>  $context
     * @return array<int, array<string, mixed>>
     */
    private function providerGeocode(string $provider, string $query, array $context, int $limit): array
    {
        return match ($provider) {
            'mapbox' => $this->mapboxGeocode($query, $context, $limit),
            'google' => $this->googleGeocode($query, $context, $limit),
            default => $this->nominatimGeocode($query, $context, $limit),
        };
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function nominatimGeocode(string $query, array $context, int $limit): array
    {
        $parameters = [
            'q' => $query,
            'format' => 'jsonv2',
            'addressdetails' => 1,
            'limit' => $limit,
            'accept-language' => 'fr',
        ];

        $country = strtoupper((string) ($context['country'] ?? ''));
        if ($country !== '') {
            $parameters['countrycodes'] = strtolower($country);
        }
        if (isset($context['latitude'], $context['longitude'])) {
            $parameters['viewbox'] = implode(',', [
                (float) $context['longitude'] - 1,
                (float) $context['latitude'] + 1,
                (float) $context['longitude'] + 1,
                (float) $context['latitude'] - 1,
            ]);
            $parameters['bounded'] = 1;
        }

        try {
            $response = Http::withHeaders($this->userAgentHeaders())
                ->timeout($this->timeout())
                ->get((string) config('beninfood.geography.geocoding.nominatim_url').'/search', $parameters);
        } catch (Throwable $exception) {
            Log::warning('geocoding.nominatim_failed', ['message' => $exception->getMessage()]);

            return [];
        }

        if (! $response->successful() || ! is_array($response->json())) {
            return [];
        }

        return array_values(array_filter(array_map(
            fn (mixed $item): ?array => is_array($item) ? $this->normalizeProviderItem('nominatim', $item) : null,
            $response->json(),
        )));
    }

    /**
     * @param  array<string, mixed>  $context
     * @return array<int, array<string, mixed>>
     */
    private function mapboxGeocode(string $query, array $context, int $limit): array
    {
        $url = (string) config('beninfood.geography.geocoding.mapbox_url', 'https://api.mapbox.com/geocoding/v5/mapbox.places');
        $parameters = [
            'access_token' => (string) config('beninfood.geography.geocoding.mapbox_token'),
            'limit' => $limit,
            'language' => 'fr',
        ];

        $country = strtoupper((string) ($context['country'] ?? ''));
        if ($country !== '') {
            $parameters['country'] = $country;
        }
        if (isset($context['latitude'], $context['longitude'])) {
            $parameters['proximity'] = (float) $context['longitude'].','.(float) $context['latitude'];
        }

        try {
            $response = Http::timeout($this->timeout())
                ->get($url.'/'.rawurlencode($query).'.json', $parameters);
        } catch (Throwable $exception) {
            Log::warning('geocoding.mapbox_failed', ['message' => $exception->getMessage()]);

            return [];
        }

        $features = $response->successful() ? $response->json('features') : [];

        return array_values(array_filter(array_map(
            fn (mixed $item): ?array => is_array($item) ? $this->normalizeProviderItem('mapbox', $item) : null,
            is_array($features) ? $features : [],
        )));
    }

    /**
     * @param  array<string, mixed>  $context
     * @return array<int, array<string, mixed>>
     */
    private function googleGeocode(string $query, array $context, int $limit): array
    {
        $parameters = [
            'address' => $query,
            'language' => 'fr',
            'key' => (string) config('beninfood.geography.geocoding.google_key'),
        ];

        $country = strtoupper((string) ($context['country'] ?? ''));
        if ($country !== '') {
            $parameters['components'] = 'country:'.$country;
        }

        try {
            $response = Http::timeout($this->timeout())
                ->get((string) config('beninfood.geography.geocoding.google_url', 'https://maps.googleapis.com/maps/api/geocode/json'), $parameters);
        } catch (Throwable $exception) {
            Log::warning('geocoding.google_failed', ['message' => $exception->getMessage()]);

            return [];
        }

        $results = $response->successful() ? $response->json('results') : [];

        return array_values(array_slice(array_filter(array_map(
            fn (mixed $item): ?array => is_array($item) ? $this->normalizeProviderItem('google', $item) : null,
            is_array($results) ? $results : [],
        )), 0, $limit));
    }

    private function providerReverse(string $provider, float $latitude, float $longitude, ?string $countryCode): ?array
    {
        return match ($provider) {
            'mapbox' => $this->mapboxReverse($latitude, $longitude),
            'google' => $this->googleReverse($latitude, $longitude),
            default => $this->nominatimReverse($latitude, $longitude, $countryCode),
        };
    }

    private function nominatimReverse(float $latitude, float $longitude, ?string $countryCode): ?array
    {
        $parameters = [
            'lat' => $latitude,
            'lon' => $longitude,
            'format' => 'jsonv2',
            'addressdetails' => 1,
            'zoom' => 18,
            'accept-language' => 'fr',
        ];

        try {
            $response = Http::withHeaders($this->userAgentHeaders())
                ->timeout($this->timeout())
                ->get((string) config('beninfood.geography.geocoding.nominatim_url').'/reverse', $parameters);
        } catch (Throwable $exception) {
            Log::warning('geocoding.nominatim_reverse_failed', ['message' => $exception->getMessage()]);

            return null;
        }

        $item = $response->successful() ? $response->json() : null;

        return is_array($item) && ($item['lat'] ?? null) !== null
            ? $this->normalizeProviderItem('nominatim', $item)
            : null;
    }

    private function mapboxReverse(float $latitude, float $longitude): ?array
    {
        $url = (string) config('beninfood.geography.geocoding.mapbox_url', 'https://api.mapbox.com/geocoding/v5/mapbox.places');

        try {
            $response = Http::timeout($this->timeout())->get(
                $url.'/'.$longitude.','.$latitude.'.json',
                [
                    'access_token' => (string) config('beninfood.geography.geocoding.mapbox_token'),
                    'language' => 'fr',
                ],
            );
        } catch (Throwable $exception) {
            Log::warning('geocoding.mapbox_reverse_failed', ['message' => $exception->getMessage()]);

            return null;
        }

        $feature = $response->successful() ? $response->json('features.0') : null;

        return is_array($feature) ? $this->normalizeProviderItem('mapbox', $feature) : null;
    }

    private function googleReverse(float $latitude, float $longitude): ?array
    {
        try {
            $response = Http::timeout($this->timeout())->get(
                (string) config('beninfood.geography.geocoding.google_url', 'https://maps.googleapis.com/maps/api/geocode/json'),
                [
                    'latlng' => $latitude.','.$longitude,
                    'language' => 'fr',
                    'key' => (string) config('beninfood.geography.geocoding.google_key'),
                ],
            );
        } catch (Throwable $exception) {
            Log::warning('geocoding.google_reverse_failed', ['message' => $exception->getMessage()]);

            return null;
        }

        $item = $response->successful() ? $response->json('results.0') : null;

        return is_array($item) ? $this->normalizeProviderItem('google', $item) : null;
    }

    /**
     * @param  array<string, mixed>  $item
     * @return array<string, mixed>|null
     */
    private function normalizeProviderItem(string $provider, array $item): ?array
    {
        $latitude = Geo::coordinate($item['lat'] ?? ($item['geometry']['location']['lat'] ?? ($item['center'][1] ?? null)), -90, 90);
        $longitude = Geo::coordinate($item['lon'] ?? ($item['geometry']['location']['lng'] ?? ($item['center'][0] ?? null)), -180, 180);
        if ($latitude === null || $longitude === null) {
            return null;
        }

        $address = is_array($item['address'] ?? null) ? $item['address'] : [];
        $components = is_array($item['address_components'] ?? null) ? $item['address_components'] : [];
        $context = is_array($item['context'] ?? null) ? $item['context'] : [];

        return [
            'provider' => $provider,
            'label' => (string) ($item['display_name'] ?? $item['formatted_address'] ?? $item['place_name'] ?? ''),
            'latitude' => $latitude,
            'longitude' => $longitude,
            'components' => match ($provider) {
                'nominatim' => array_filter([
                    'country' => $address['country'] ?? null,
                    'department' => $address['state'] ?? $address['region'] ?? null,
                    'commune' => $address['city'] ?? $address['town'] ?? $address['county'] ?? null,
                    'locality' => $address['neighbourhood'] ?? $address['suburb'] ?? $address['village'] ?? null,
                ], static fn ($value): bool => is_string($value) && $value !== ''),
                'mapbox' => $this->mapboxComponents($context),
                default => $this->googleComponents($components),
            },
            'place_id' => isset($item['place_id'], $item['osm_type'])
                ? (string) $item['osm_type'].'/'.(string) $item['place_id']
                : (isset($item['id']) ? (string) $item['id'] : (isset($item['place_id']) ? (string) $item['place_id'] : null)),
            'source' => ucfirst($provider),
            'source_url' => $provider === 'nominatim'
                ? 'https://nominatim.openstreetmap.org'
                : ($provider === 'mapbox' ? 'https://www.mapbox.com' : 'https://maps.googleapis.com'),
            'data_updated_at' => null,
        ];
    }

    /**
     * @param  array<int, array<string, mixed>>  $context
     * @return array<string, string|null>
     */
    private function mapboxComponents(array $context): array
    {
        $components = [];
        foreach ($context as $entry) {
            $id = (string) ($entry['id'] ?? '');
            $type = strtok($id, '.');
            if ($type !== false && $type !== '') {
                $components[$type] = (string) ($entry['text'] ?? '');
            }
        }

        return $components;
    }

    /**
     * @param  array<int, array<string, mixed>>  $components
     * @return array<string, string|null>
     */
    private function googleComponents(array $components): array
    {
        $result = [];
        foreach ($components as $component) {
            foreach (is_array($component['types'] ?? null) ? $component['types'] : [] as $type) {
                $result[(string) $type] = (string) ($component['long_name'] ?? '');
            }
        }

        return $result;
    }

    /**
     * @param  array<string, mixed>  $context
     */
    private function cacheKey(string $operation, string $provider, string $query, array $context, int $limit = 5): string
    {
        ksort($context);

        return 'geocoding:'.$operation.':'.md5($provider.'|'.$query.'|'.$limit.'|'.json_encode($context));
    }

    private function allowExternalRequest(string $provider): bool
    {
        $key = 'geocoding:last_request:'.$provider;
        $last = Cache::get($key);
        $now = microtime(true);
        $interval = (int) config('beninfood.geography.geocoding.min_interval_ms', 1100);

        if ($last !== null && ($now - (float) $last) * 1000 < $interval) {
            return false;
        }

        Cache::put($key, $now, now()->addMinutes(10));

        return true;
    }

    /**
     * @return array<string, string>
     */
    private function userAgentHeaders(): array
    {
        return [
            'User-Agent' => (string) config('beninfood.geography.geocoding.user_agent', 'Beninfood/1.0'),
            'Accept' => 'application/json',
        ];
    }

    private function timeout(): int
    {
        return max(1, (int) config('beninfood.geography.geocoding.timeout', 5));
    }

    private function searchTerm(string $query): string
    {
        return Geo::normalizeName($query);
    }

    /**
     * @param  array<string, mixed>  $filters
     */
    private function countryId(array $filters): ?int
    {
        if (isset($filters['country_id'])) {
            return (int) $filters['country_id'];
        }

        $code = strtoupper((string) ($filters['country'] ?? ''));
        if ($code === '') {
            return null;
        }

        return GeoCountry::query()->where('code', $code)->value('id');
    }
}
