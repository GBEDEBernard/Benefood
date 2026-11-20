<?php

namespace App\Support;

use App\Models\GeoCountry;
use App\Models\GeoDivision;
use App\Models\GeoLocality;
use App\Services\GeocodingService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Validation\ValidationException;

/**
 * Validation et résolution partagées des champs géographiques des formulaires.
 *
 * Les anciens champs libres (`city`, `area`, `address_text`…) restent intact :
 * ce helper ne Produit que les colonnes de référence (pays, division, localité)
 * et les métadonnées GPS. Les niveaux inférieurs sont réinitialisés dès qu'un
 * parent change, afin qu'aucune localité ne reste rattachée à une autre commune.
 */
final class GeoFields
{
    /** Sources acceptées pour une position. */
    public const SOURCES = ['gps', 'map', 'geocoded', 'manual'];

    /**
     * Règles de validation des champs géographiques communs.
     *
     * @return array<string, array<int, string>>
     */
    public static function rules(bool $required = false): array
    {
        $country = $required
            ? ['required', 'string', 'size:2', 'exists:geo_countries,code']
            : ['sometimes', 'nullable', 'string', 'size:2', 'exists:geo_countries,code'];

        return [
            'country_code' => $country,
            'division_id' => ['sometimes', 'nullable', 'integer', 'exists:geo_divisions,id'],
            'locality_id' => ['sometimes', 'nullable', 'integer', 'exists:geo_localities,id'],
            'gps_accuracy_m' => ['sometimes', 'nullable', 'numeric', 'min:0', 'max:10000'],
            'location_source' => ['sometimes', 'nullable', 'string', 'in:'.implode(',', self::SOURCES)],
            'location_recorded_at' => ['sometimes', 'nullable', 'date'],
        ];
    }

    /**
     * Règles spécifiques au point de retrait d'une boutique.
     *
     * @return array<string, array<int, string>>
     */
    public static function pickupRules(): array
    {
        return [
            'pickup_division_id' => ['sometimes', 'nullable', 'integer', 'exists:geo_divisions,id'],
            'pickup_locality_id' => ['sometimes', 'nullable', 'integer', 'exists:geo_localities,id'],
            'pickup_gps_accuracy_m' => ['sometimes', 'nullable', 'numeric', 'min:0', 'max:10000'],
        ];
    }

    /**
     * Résout les références géographiques d'une requête.
     *
     * @param  array<string, mixed>  $data  Données déjà validées par le contrôleur
     * @param  array{prefix?: string, current?: Model|array<string, mixed>|null, infer?: bool}  $options
     * @return array<string, mixed> Colonnes prêtes pour `update()`/`create()`
     */
    public static function resolve(array $data, array $options = []): array
    {
        $prefix = (string) ($options['prefix'] ?? '');
        $current = $options['current'] ?? null;
        $infer = (bool) ($options['infer'] ?? true);

        $countryKey = $prefix.'country_code';
        $divisionKey = $prefix.'division_id';
        $localityKey = $prefix.'locality_id';
        $latitudeKey = $prefix.'latitude';
        $longitudeKey = $prefix.'longitude';
        $accuracyKey = $prefix.'gps_accuracy_m';
        $sourceKey = $prefix === 'pickup_' ? 'location_source' : $prefix.'location_source';
        $recordedAtKey = $prefix === 'pickup_' ? 'location_recorded_at' : $prefix.'location_recorded_at';

        $countryProvided = array_key_exists($countryKey, $data)
            || array_key_exists($prefix.'country_id', $data);
        $divisionProvided = array_key_exists($divisionKey, $data);
        $localityProvided = array_key_exists($localityKey, $data);

        $countryValue = $data[$countryKey] ?? $data[$prefix.'country_id'] ?? null;
        $divisionValue = $data[$divisionKey] ?? null;
        $localityValue = $data[$localityKey] ?? null;
        $latitude = self::numeric($data[$latitudeKey] ?? null);
        $longitude = self::numeric($data[$longitudeKey] ?? null);
        $source = isset($data[$sourceKey]) ? (string) $data[$sourceKey] : null;

        $result = [];
        $country = null;

        if ($countryProvided) {
            if ($countryValue === null || $countryValue === '') {
                $result['country_id'] = null;
            } else {
                $country = is_numeric($countryValue)
                    ? GeoCountry::query()->active()->find((int) $countryValue)
                    : GeoCountry::query()->active()->where('code', strtoupper((string) $countryValue))->first();

                if ($country === null) {
                    throw self::error($countryKey, 'Pays inconnu ou inactif.');
                }

                $result['country_id'] = $country->id;
            }

            if (! $divisionProvided && ! $localityProvided) {
                $result['division_id'] = null;
                $result['locality_id'] = null;
            }
        } else {
            $countryId = self::currentValue($current, 'country_id');
            if ($countryId !== null) {
                $country = GeoCountry::query()->active()->find((int) $countryId);
            }
        }

        if ($divisionProvided) {
            if ($divisionValue === null || $divisionValue === '') {
                $result['division_id'] = null;
                $result['locality_id'] = null;
            } else {
                $division = GeoDivision::query()->active()
                    ->with('country')
                    ->find((int) $divisionValue);

                if ($division === null) {
                    throw self::error($divisionKey, 'Subdivision administrative inconnue.');
                }

                $explicitCountryId = self::explicitCountryId($result, $country, $current);
                if ($explicitCountryId !== null && (int) $explicitCountryId !== (int) $division->country_id) {
                    throw self::error($divisionKey, 'Cette subdivision n\'appartient pas au pays choisi.');
                }

                $result['division_id'] = $division->id;
                $result['country_id'] = $division->country_id;
                $country = $division->country;

                if (! $localityProvided) {
                    $result['locality_id'] = null;
                }
            }
        }

        if ($localityProvided) {
            if ($localityValue === null || $localityValue === '') {
                $result['locality_id'] = null;
            } else {
                $locality = GeoLocality::query()->active()
                    ->with('division.country')
                    ->find((int) $localityValue);

                if ($locality === null) {
                    throw self::error($localityKey, 'Localité inconnue.');
                }

                $explicitDivisionId = self::explicitId($result, $divisionValue, self::currentValue($current, $prefix.'division_id') ?? self::currentValue($current, 'division_id'));
                if ($explicitDivisionId !== null && (int) $explicitDivisionId !== (int) $locality->division_id) {
                    throw self::error($localityKey, 'Cette localité n\'appartient pas à la subdivision choisie.');
                }

                $explicitCountryId = self::explicitCountryId($result, $country, $current);
                if ($explicitCountryId !== null && (int) $explicitCountryId !== (int) $locality->country_id) {
                    throw self::error($localityKey, 'Cette localité n\'appartient pas au pays choisi.');
                }

                $result['locality_id'] = $locality->id;
                $result['division_id'] = $locality->division_id;
                $result['country_id'] = $locality->country_id;
            }
        }

        if ($infer && ! $localityProvided && $latitude !== null && $longitude !== null && $source !== 'manual') {
            self::inferFromCoordinates(
                $result,
                $latitude,
                $longitude,
                $country?->code,
                $divisionProvided ? ($result[$divisionKey] ?? $divisionValue) : null,
                $divisionKey,
                $localityKey,
            );
        }

        if (array_key_exists($accuracyKey, $data)) {
            $result['gps_accuracy_m'] = $data[$accuracyKey] === null ? null : (float) $data[$accuracyKey];
        }

        if (array_key_exists($sourceKey, $data)) {
            if ($data[$sourceKey] !== null && ! in_array((string) $data[$sourceKey], self::SOURCES, true)) {
                throw self::error($sourceKey, 'Source de position invalide.');
            }
            $result['location_source'] = $data[$sourceKey] === null ? null : (string) $data[$sourceKey];
        }

        if (array_key_exists($recordedAtKey, $data)) {
            $result['location_recorded_at'] = $data[$recordedAtKey];
        }

        if ($source === 'gps' || $source === 'map') {
            if ($latitude === null || $longitude === null) {
                throw self::error($latitudeKey, 'Une position GPS est requise pour cette source.');
            }
            if (! array_key_exists($accuracyKey, $data) && $current === null) {
                $result['location_source'] = $source;
            }
        }

        return $result;
    }

    /**
     * Représentation API des références géographiques d'un modèle.
     *
     * @return array<string, mixed>
     */
    public static function payload(Model $model, string $prefix = ''): array
    {
        $country = $prefix === 'pickup_' ? null : $model->country;
        $division = $prefix === 'pickup_' ? $model->pickupDivision : $model->division;
        $locality = $prefix === 'pickup_' ? $model->pickupLocality : $model->locality;
        $country ??= $division?->country ?? $locality?->division?->country;

        $recordedAtKey = $prefix === 'pickup_' ? 'location_recorded_at' : $prefix.'location_recorded_at';
        $recordedAt = array_key_exists($recordedAtKey, $model->getAttributes())
            ? $model->getAttribute($recordedAtKey)
            : null;

        return [
            'country' => $country === null ? null : [
                'code' => $country->code,
                'name' => $country->name,
            ],
            'division' => $division === null ? null : [
                'id' => $division->id,
                'name' => $division->name,
                'level' => $division->level,
                'code' => $division->code,
                'path' => $division->path(),
            ],
            'locality' => $locality === null ? null : [
                'id' => $locality->id,
                'name' => $locality->name,
                'kind' => $locality->kind,
                'code' => $locality->code,
            ],
            'geographic_path' => $locality?->displayPath() ?? $division?->displayPath(),
            'gps_accuracy_m' => $model->getAttribute($prefix.'gps_accuracy_m'),
            'location_source' => $model->getAttribute('location_source'),
            'location_recorded_at' => is_object($recordedAt) && method_exists($recordedAt, 'toIso8601String')
                ? $recordedAt->toIso8601String()
                : $recordedAt,
        ];
    }

    /**
     * @param  array<string, mixed>  $result
     */
    private static function inferFromCoordinates(
        array &$result,
        float $latitude,
        float $longitude,
        ?string $countryCode,
        mixed $divisionId,
        string $divisionKey,
        string $localityKey,
    ): void {
        $reverse = app(GeocodingService::class)->reverseLocal($latitude, $longitude, $countryCode);
        if ($reverse === null) {
            return;
        }

        if ($divisionId !== null && (string) $divisionId !== (string) $reverse['division']) {
            // Le GPS ne correspond pas au choix manuel : on conserve le choix
            // explicite sans inventer de rattachement administratif.
            return;
        }

        if (! array_key_exists($divisionKey, $result)) {
            $result[$divisionKey] = $reverse['division'];
        }
        if (! array_key_exists('country_id', $result) && $countryCode === null) {
            $division = GeoDivision::query()->active()->find($reverse['division']);
            $result['country_id'] = $division?->country_id;
        }
        if (! array_key_exists($localityKey, $result) && $reverse['locality'] !== null) {
            $result[$localityKey] = $reverse['locality'];
        }
    }

    /**
     * @param  Model|array<string, mixed>|null  $current
     */
    private static function currentValue(Model|array|null $current, string $key): mixed
    {
        if ($current === null) {
            return null;
        }

        if (is_array($current)) {
            return $current[$key] ?? null;
        }

        return $current->getAttribute($key);
    }

    /**
     * @param  array<string, mixed>  $result
     * @param  Model|array<string, mixed>|null  $current
     */
    private static function explicitCountryId(array $result, ?GeoCountry $country, Model|array|null $current): mixed
    {
        if (array_key_exists('country_id', $result)) {
            return $result['country_id'];
        }

        return $country?->id ?? self::currentValue($current, 'country_id');
    }

    private static function explicitId(mixed ...$values): mixed
    {
        foreach ($values as $value) {
            if ($value !== null && $value !== '') {
                return $value;
            }
        }

        return null;
    }

    private static function numeric(mixed $value): ?float
    {
        return is_numeric($value) ? (float) $value : null;
    }

    private static function error(string $field, string $message): ValidationException
    {
        return ValidationException::withMessages([$field => $message]);
    }
}
