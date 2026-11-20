<?php

namespace App\Services;

use App\Models\GeoCountry;
use App\Models\GeoDivision;
use App\Models\GeoLocality;
use App\Support\Geo;
use Illuminate\Support\Facades\Log;

/**
 * Importe le référentiel administratif officiel du Bénin (IGN) dans les
 * tables géographiques. Les fichiers GeoJSON sont ceux du catalogue
 * https://ign.bj/donnees (WGS84, licence Etalab Open Licence 2.0).
 *
 * Aucune localité n'est créée par le service : seules les entités présentes
 * dans les fichiers sont importées. Les correspondances ambiguës sont
 * résolues par inclusion dans la géométrie des arrondissements, jamais par
 * approximation de nom.
 */
final class GeoReferenceImporter
{
    private const DATA_UPDATED_AT = '2026-09-20';

    /**
     * @return array<string, int>
     */
    public function import(): array
    {
        $stats = [
            'departments' => 0,
            'communes' => 0,
            'arrondissements' => 0,
            'localities' => 0,
            'localities_by_name' => 0,
            'localities_by_geometry' => 0,
            'localities_unresolved' => 0,
        ];

        $country = $this->country();
        $departments = $this->importDepartments($country, $stats);
        $communes = $this->importCommunes($country, $departments, $stats);
        $arrondissements = $this->importArrondissements($country, $communes, $stats);

        $this->applyDepartmentCenters($departments);
        $this->applyCommuneCenters($communes);
        $this->applyArrondissementCenters($arrondissements);

        $this->importLocalities($country, $arrondissements, $this->divisionIndex($arrondissements), $stats);

        return $stats;
    }

    private function country(): GeoCountry
    {
        return GeoCountry::query()->updateOrCreate(
            ['code' => 'BJ'],
            [
                'name' => 'Bénin',
                'official_name' => 'République du Bénin',
                'levels' => [
                    ['slug' => 'department', 'label' => 'Département', 'plural' => 'Départements'],
                    ['slug' => 'commune', 'label' => 'Commune', 'plural' => 'Communes'],
                    ['slug' => 'arrondissement', 'label' => 'Arrondissement', 'plural' => 'Arrondissements'],
                ],
                'locality_label' => 'Village ou quartier',
                'source' => config('beninfood.geography.source'),
                'source_url' => config('beninfood.geography.source_url'),
                'data_updated_at' => self::DATA_UPDATED_AT,
                'is_active' => true,
            ],
        );
    }

    /**
     * @param  array<string, int>  $stats
     * @return array<string, GeoDivision> Indexé par nom normalisé
     */
    private function importDepartments(GeoCountry $country, array &$stats): array
    {
        $divisions = [];

        foreach ($this->features('departements') as $feature) {
            $properties = $feature['properties'] ?? [];
            $name = Geo::titleName($properties['NAME1_'] ?? null);
            if ($name === '') {
                continue;
            }

            $code = trim((string) ($properties['ID_'] ?? ''));
            $division = GeoDivision::query()->updateOrCreate(
                [
                    'country_id' => $country->id,
                    'level' => 'department',
                    'source_key' => 'dep-'.$code,
                ],
                [
                    'parent_id' => null,
                    'code' => $code !== '' ? $code : null,
                    'name' => $name,
                    'name_normalized' => Geo::normalizeName($name),
                    'source' => 'IGN Bénin / limites départementales',
                    'source_url' => 'https://ign.bj/donnees/limites-departementales',
                    'data_updated_at' => self::DATA_UPDATED_AT,
                    'is_active' => true,
                ],
            );

            $geometry = Geo::simplifyGeometry($feature['geometry'] ?? null);
            $division->update($this->geometryAttributes($geometry));
            $divisions[Geo::normalizeName($name)] = $division;
            $stats['departments']++;
        }

        return $divisions;
    }

    /**
     * Les libellés de communes diffèrent légèrement entre les deux jeux IGN
     * (ex. « Dassa » / « Dassa-Zoumè », « Djougou » / « Djoudjou »). Le jeu
     * « arrondissements » fait foi pour les noms et les rattachements ; le jeu
     * « limites communales » fournit la géométrie, associée par centre.
     *
     * @param  array<string, GeoDivision>  $departments
     * @param  array<string, int>  $stats
     * @return array<string, GeoDivision> Indexé par nom normalisé
     */
    private function importCommunes(GeoCountry $country, array $departments, array &$stats): array
    {
        /** @var array<string, array{name: string, department: string, bounds: array<int, float>|null}> $meta */
        $meta = [];

        foreach ($this->features('arrondissements') as $feature) {
            $properties = $feature['properties'] ?? [];
            $key = Geo::normalizeName($properties['COMMUNE'] ?? '');
            if ($key === '') {
                continue;
            }

            if (! isset($meta[$key])) {
                $meta[$key] = [
                    'name' => Geo::titleName($properties['COMMUNE'] ?? null),
                    'department' => Geo::normalizeName($properties['DEPARTEMEN'] ?? ''),
                    'bounds' => null,
                ];
            }

            $bounds = Geo::geometryBounds($feature['geometry'] ?? null);
            if ($bounds !== null) {
                $meta[$key]['bounds'] = $meta[$key]['bounds'] === null
                    ? $bounds
                    : [
                        min($meta[$key]['bounds'][0], $bounds[0]),
                        min($meta[$key]['bounds'][1], $bounds[1]),
                        max($meta[$key]['bounds'][2], $bounds[2]),
                        max($meta[$key]['bounds'][3], $bounds[3]),
                    ];
            }
        }

        /** @var array<string, array{type: string, coordinates: mixed}> $geometryByCommune */
        $geometryByCommune = [];
        foreach ($this->features('communes') as $feature) {
            $geometry = Geo::simplifyGeometry($feature['geometry'] ?? null);
            if ($geometry === null) {
                continue;
            }

            $center = Geo::geometryCenter($feature['geometry'] ?? null);
            $exactKey = Geo::normalizeName($feature['properties']['NAME1_'] ?? null);
            $matched = $exactKey !== '' && isset($meta[$exactKey]) ? $exactKey : null;

            if ($matched === null && $center !== null) {
                foreach ($meta as $key => $information) {
                    $bounds = $information['bounds'];
                    if ($bounds === null) {
                        continue;
                    }

                    if ($center[1] >= $bounds[1] && $center[1] <= $bounds[3]
                        && $center[0] >= $bounds[0] && $center[0] <= $bounds[2]) {
                        $matched = $key;
                        break;
                    }
                }
            }

            if ($matched !== null) {
                $geometryByCommune[$matched] = $geometry;
            }
        }

        $divisions = [];

        foreach ($meta as $key => $information) {
            $parent = $departments[$information['department']] ?? null;
            if ($parent === null) {
                Log::warning("Commune sans département : {$information['name']}");

                continue;
            }

            $geometry = $geometryByCommune[$key] ?? null;
            $attributes = $geometry !== null
                ? $this->geometryAttributes($geometry)
                : $this->boundsAttributes($information['bounds']);

            $division = GeoDivision::query()->updateOrCreate(
                [
                    'country_id' => $country->id,
                    'level' => 'commune',
                    'source_key' => 'com-'.$key,
                ],
                array_merge([
                    'parent_id' => $parent->id,
                    'code' => null,
                    'name' => $information['name'],
                    'name_normalized' => $key,
                    'source' => 'IGN Bénin / limites communales et arrondissements',
                    'source_url' => 'https://ign.bj/donnees/limites-communales',
                    'data_updated_at' => self::DATA_UPDATED_AT,
                    'is_active' => true,
                ], $attributes),
            );

            $divisions[$key] = $division;
            $stats['communes']++;
        }

        return $divisions;
    }

    /**
     * @param  array<string, GeoDivision>  $communes
     * @param  array<string, int>  $stats
     * @return array<string, GeoDivision> Indexé par `commune|arrondissement`
     */
    private function importArrondissements(GeoCountry $country, array $communes, array &$stats): array
    {
        $divisions = [];

        foreach ($this->features('arrondissements') as $feature) {
            $properties = $feature['properties'] ?? [];
            $name = Geo::titleName($properties['ARRONDISSE'] ?? null);
            $communeName = Geo::normalizeName($properties['COMMUNE'] ?? '');
            $normalized = Geo::normalizeName($name);
            $key = $communeName.'|'.$normalized;

            $commune = $communes[$communeName] ?? null;
            if ($commune === null || $normalized === '') {
                Log::warning("Arrondissement sans commune : {$key}");

                continue;
            }

            $geometry = Geo::simplifyGeometry($feature['geometry'] ?? null);
            $division = GeoDivision::query()->updateOrCreate(
                [
                    'country_id' => $country->id,
                    'level' => 'arrondissement',
                    'source_key' => 'arr-'.$key,
                ],
                array_merge([
                    'parent_id' => $commune->id,
                    'code' => null,
                    'name' => $name,
                    'name_normalized' => $normalized,
                    'source' => 'IGN Bénin / limites des arrondissements',
                    'source_url' => 'https://ign.bj/donnees/limites-des-arrondissements',
                    'data_updated_at' => self::DATA_UPDATED_AT,
                    'is_active' => true,
                ], $this->geometryAttributes($geometry)),
            );

            $divisions[$key] = $division;
            $stats['arrondissements']++;
        }

        return $divisions;
    }

    /**
     * @param  array<string, GeoDivision>  $departments
     */
    private function applyDepartmentCenters(array $departments): void
    {
        foreach ($this->features('chefs-lieux-de-departement') as $feature) {
            $properties = $feature['properties'] ?? [];
            $division = $departments[Geo::normalizeName($properties['nom'] ?? '')] ?? null;
            if ($division === null) {
                continue;
            }

            $latitude = Geo::coordinate($properties['Latitude'] ?? null, -90, 90);
            $longitude = Geo::coordinate($properties['Longitude'] ?? null, -180, 180);
            if ($latitude !== null && $longitude !== null) {
                $division->update(['center_latitude' => $latitude, 'center_longitude' => $longitude]);
            }
        }
    }

    /**
     * @param  array<string, GeoDivision>  $communes
     */
    private function applyCommuneCenters(array $communes): void
    {
        foreach ($this->features('chefs-lieux-de-commune') as $feature) {
            $properties = $feature['properties'] ?? [];
            $division = $communes[Geo::normalizeName($properties['Commune'] ?? '')] ?? null;
            if ($division === null) {
                continue;
            }

            $latitude = Geo::coordinate($properties['LAT_COR'] ?? null, -90, 90);
            $longitude = Geo::coordinate($properties['LONG_COR'] ?? null, -180, 180);
            if ($latitude !== null && $longitude !== null) {
                $division->update(['center_latitude' => $latitude, 'center_longitude' => $longitude]);
            }
        }
    }

    /**
     * @param  array<string, GeoDivision>  $arrondissements
     */
    private function applyArrondissementCenters(array $arrondissements): void
    {
        foreach ($this->features('chefs-lieux-darrondissement') as $feature) {
            $properties = $feature['properties'] ?? [];
            $key = Geo::normalizeName($properties['commune'] ?? '').'|'.Geo::normalizeName($properties['nom'] ?? '');
            $division = $arrondissements[$key] ?? null;
            if ($division === null) {
                continue;
            }

            $latitude = Geo::coordinate($properties['latitude'] ?? null, -90, 90);
            $longitude = Geo::coordinate($properties['longitude'] ?? null, -180, 180);
            if ($latitude !== null && $longitude !== null) {
                $division->update(['center_latitude' => $latitude, 'center_longitude' => $longitude]);
            }
        }
    }

    /**
     * Index de rattachement tolérant aux variantes orthographiques des jeux
     * IGN (« Gbafo » / « Gbaffo », « Séméré II » / « Sèmèrè 2 »…).
     *
     * @param  array<string, GeoDivision>  $arrondissements
     * @return array<string, array<string, array<int, GeoDivision>>>
     */
    private function divisionIndex(array $arrondissements): array
    {
        $index = ['department' => [], 'name' => []];

        foreach ($arrondissements as $division) {
            $name = $this->adminName($division->name_normalized);
            $department = $this->adminName($division->parent?->parent?->name_normalized);
            $index['name'][$name][] = $division;

            if ($department !== '') {
                $index['department'][$department.'|'.$name][] = $division;
            }
        }

        return $index;
    }

    /**
     * Normalise un libellé administratif en uniformisant les ordinals
     * (« 1er », « II », « 2eme ») afin de rapprocher les variantes IGN.
     */
    private function adminName(?string $value): string
    {
        $normalized = Geo::normalizeName($value);
        if ($normalized === '') {
            return '';
        }

        $ordinals = [
            'ier' => '1', 'ere' => '1', 'er' => '1', 'eme' => '',
            'i' => '1', 'ii' => '2', 'iii' => '3', 'iv' => '4',
            'v' => '5', 'vi' => '6', 'vii' => '7', 'viii' => '8',
            'ix' => '9', 'x' => '10',
        ];

        $parts = array_map(
            static fn (string $part): string => $ordinals[$part] ?? $part,
            explode(' ', $normalized),
        );

        return implode(' ', array_filter($parts, static fn (string $part): bool => $part !== ''));
    }

    /**
     * @param  array<string, GeoDivision>  $arrondissements
     * @param  array<string, array<string, array<int, GeoDivision>>>  $index
     * @param  array<string, int>  $stats
     */
    private function importLocalities(GeoCountry $country, array $arrondissements, array $index, array &$stats): void
    {
        foreach ($this->features('localites') as $feature) {
            $properties = $feature['properties'] ?? [];
            $name = trim((string) ($properties['Nom_LOC'] ?? ''));
            if ($name === '') {
                continue;
            }

            $latitude = Geo::coordinate($properties['Latitude'] ?? null, -90, 90);
            $longitude = Geo::coordinate($properties['Longitude'] ?? null, -180, 180);
            if ($latitude === null || $longitude === null) {
                continue;
            }

            $key = Geo::normalizeName($properties['Commune'] ?? '').'|'.Geo::normalizeName($properties['Arrondisst'] ?? '');
            $division = $arrondissements[$key] ?? null;
            if ($division === null) {
                $division = $this->divisionByAdministrativeName(
                    $index,
                    Geo::normalizeName($properties['Départeme'] ?? ''),
                    Geo::normalizeName($properties['Arrondisst'] ?? ''),
                    $latitude,
                    $longitude,
                );
            }
            if ($division !== null) {
                $stats['localities_by_name']++;
            } else {
                $division = $this->divisionAtPoint($arrondissements, $latitude, $longitude);
                if ($division !== null) {
                    $stats['localities_by_geometry']++;
                }
            }

            if ($division === null) {
                $stats['localities_unresolved']++;
                Log::warning("Localité sans arrondissement : {$name} ({$key})");

                continue;
            }

            $code = trim((string) ($properties['Code_GEO'] ?? ''));
            $kind = $this->kind($properties['Type'] ?? null);
            $sourceKey = $code !== '' ? $code : sprintf('loc-%s-%s', $division->id, sha1(Geo::normalizeName($name).$kind.$latitude.$longitude));

            GeoLocality::query()->updateOrCreate(
                [
                    'country_id' => $country->id,
                    'source_key' => $sourceKey,
                ],
                [
                    'division_id' => $division->id,
                    'code' => $code !== '' ? $code : null,
                    'name' => $name,
                    'name_normalized' => Geo::normalizeName($name),
                    'kind' => $kind,
                    'administrative_status' => $properties['Statut_ADM'] ?? null,
                    'latitude' => $latitude,
                    'longitude' => $longitude,
                    'source' => 'IGN Bénin / localités et chefs-lieux de village',
                    'source_url' => 'https://ign.bj/donnees/localites-et-chefs-lieux-de-village',
                    'data_updated_at' => self::DATA_UPDATED_AT,
                    'is_verified' => true,
                    'is_active' => true,
                ],
            );
            $stats['localities']++;
        }
    }

    /**
     * Rattache une localité en tolérant les variantes orthographiques entre
     * jeux IGN. Le département fait toujours foi ; le nom de l'arrondissement
     * est comparé après normalisation des ordinals, puis avec Levenshtein.
     *
     * @param  array<string, array<string, array<int, GeoDivision>>>  $index
     * @return array<int, GeoDivision>
     */
    private function administrativeCandidates(array $index, string $department, string $name): array
    {
        $department = $this->adminName($department);
        $name = $this->adminName($name);
        if ($department === '' || $name === '') {
            return [];
        }

        $exact = $index['department'][$department.'|'.$name] ?? [];
        if ($exact !== []) {
            return $exact;
        }

        /** @var array<int, GeoDivision> $candidates */
        $candidates = [];
        $bestDistance = PHP_INT_MAX;

        foreach ($index['name'] as $candidateName => $divisions) {
            foreach ($divisions as $division) {
                $divisionDepartment = $this->adminName($division->parent?->parent?->name_normalized);
                if ($divisionDepartment !== $department) {
                    continue;
                }

                $distance = levenshtein($name, (string) $candidateName);
                if ($distance > $bestDistance) {
                    continue;
                }

                if ($distance < $bestDistance) {
                    $bestDistance = $distance;
                    $candidates = [];
                }

                $candidates[] = $division;
            }
        }

        $limit = strlen($name) <= 4 ? 1 : 2;

        return $bestDistance <= $limit ? $candidates : [];
    }

    /**
     * @param  array<string, array<string, array<int, GeoDivision>>>  $index
     */
    private function divisionByAdministrativeName(
        array $index,
        string $department,
        string $name,
        float $latitude,
        float $longitude,
    ): ?GeoDivision {
        $candidates = $this->administrativeCandidates($index, $department, $name);
        if ($candidates === []) {
            return null;
        }
        if (count($candidates) === 1) {
            return $candidates[0];
        }

        return $this->divisionAtPoint($candidates, $latitude, $longitude);
    }

    /**
     * Cherche la division contenant le point, en filtrant d'abord par emprise.
     *
     * @param  array<string, GeoDivision>  $divisions
     */
    private function divisionAtPoint(array $divisions, float $latitude, float $longitude): ?GeoDivision
    {
        foreach ($divisions as $division) {
            if ($division->bbox_min_latitude === null
                || $latitude < $division->bbox_min_latitude
                || $latitude > $division->bbox_max_latitude
                || $longitude < $division->bbox_min_longitude
                || $longitude > $division->bbox_max_longitude) {
                continue;
            }

            $geometry = $division->geometry_json === null ? null : json_decode($division->geometry_json, true);
            if ($geometry !== null && Geo::pointInGeometry($latitude, $longitude, $geometry)) {
                return $division;
            }
        }

        return null;
    }

    /**
     * @param  array<int, float>|null  $bounds
     * @return array<string, mixed>
     */
    private function boundsAttributes(?array $bounds): array
    {
        if ($bounds === null) {
            return [
                'geometry_json' => null,
                'bbox_min_latitude' => null,
                'bbox_max_latitude' => null,
                'bbox_min_longitude' => null,
                'bbox_max_longitude' => null,
                'center_latitude' => null,
                'center_longitude' => null,
            ];
        }

        return [
            'geometry_json' => null,
            'bbox_min_longitude' => $bounds[0],
            'bbox_min_latitude' => $bounds[1],
            'bbox_max_longitude' => $bounds[2],
            'bbox_max_latitude' => $bounds[3],
            'center_latitude' => ($bounds[1] + $bounds[3]) / 2,
            'center_longitude' => ($bounds[0] + $bounds[2]) / 2,
        ];
    }

    /**
     * @param  array{type: string, coordinates: mixed}|null  $geometry
     * @return array<string, mixed>
     */
    private function geometryAttributes(?array $geometry): array
    {
        if ($geometry === null) {
            return [
                'geometry_json' => null,
                'bbox_min_latitude' => null,
                'bbox_max_latitude' => null,
                'bbox_min_longitude' => null,
                'bbox_max_longitude' => null,
                'center_latitude' => null,
                'center_longitude' => null,
            ];
        }

        $bounds = Geo::geometryBounds($geometry);
        $center = Geo::geometryCenter($geometry);
        $attributes = ['geometry_json' => json_encode($geometry, JSON_THROW_ON_ERROR)];

        if ($bounds !== null) {
            $attributes['bbox_min_longitude'] = $bounds[0];
            $attributes['bbox_min_latitude'] = $bounds[1];
            $attributes['bbox_max_longitude'] = $bounds[2];
            $attributes['bbox_max_latitude'] = $bounds[3];
        }

        if ($center !== null) {
            $attributes['center_latitude'] = $center[0];
            $attributes['center_longitude'] = $center[1];
        }

        return $attributes;
    }

    private function kind(mixed $type): string
    {
        return match (Geo::normalizeName(is_string($type) ? $type : null)) {
            'village' => 'village',
            'quartier' => 'quartier',
            'hameau' => 'hameau',
            'peulh' => 'peulh',
            'ville' => 'ville',
            default => 'unknown',
        };
    }

    /**
     * @return array<int, array{properties: array<string, mixed>, geometry: array<string, mixed>}>
     */
    private function features(string $dataset): array
    {
        $path = config('beninfood.geography.data_path').'/'.$dataset.'.geojson';
        $contents = @file_get_contents($path);

        if ($contents === false) {
            Log::error("Jeu de données IGN introuvable : {$path}");

            return [];
        }

        $decoded = json_decode($contents, true);

        return is_array($decoded['features'] ?? null) ? $decoded['features'] : [];
    }
}
