<?php

namespace App\Support;

/**
 * Aides géographiques : expression SQL de distance orthodromique (Haversine)
 * pour le tri et le filtrage par proximité (recherche « par km »).
 */
final class Geo
{
    /**
     * Construit la distance en kilomètres entre un point de référence et les
     * colonnes `latitude`/`longitude` passées, sous forme de SQL paramétré.
     *
     * Le résultat est renvoyé séparément du SQL pour que l'appelant puisse
     * réutiliser les liaisons dans un `selectRaw`, un `whereRaw` ou un
     * `orderByRaw`. Compatible MySQL/MariaDB (LEAST/GREATEST/RADIANS/ACOS).
     *
     * @return array{0: string, 1: array<int, float>}
     */
    public static function distanceKm(string $latColumn, string $lngColumn, float $latitude, float $longitude): array
    {
        $sql = '6371 * acos(least(1, greatest(-1, '
            .'cos(radians(?)) * cos(radians('.$latColumn.')) * cos(radians('.$lngColumn.') - radians(?))'
            .' + sin(radians(?)) * sin(radians('.$latColumn.'))'
            .')))';

        return [$sql, [$latitude, $longitude, $latitude]];
    }

    /**
     * Distance à vol d'oiseau (Haversine) entre deux points GPS, en km.
     * Renvoie null si l'une des coordonnées est absente ou invalide.
     */
    public static function haversineKm(mixed $lat1, mixed $lng1, mixed $lat2, mixed $lng2): ?float
    {
        if ($lat1 === null || $lng1 === null || $lat2 === null || $lng2 === null) {
            return null;
        }
        if (! is_numeric($lat1) || ! is_numeric($lng1) || ! is_numeric($lat2) || ! is_numeric($lng2)) {
            return null;
        }

        $earthRadius = 6371.0;
        $dLat = deg2rad((float) $lat2 - (float) $lat1);
        $dLng = deg2rad((float) $lng2 - (float) $lng1);
        $a = sin($dLat / 2) ** 2
            + cos(deg2rad((float) $lat1)) * cos(deg2rad((float) $lat2)) * sin($dLng / 2) ** 2;

        return $earthRadius * 2 * asin(sqrt(min(1.0, $a)));
    }

    /** Alias historique / nom court attendu par certains appelants. */
    public static function haversine(mixed $lat1, mixed $lng1, mixed $lat2, mixed $lng2): ?float
    {
        return self::haversineKm($lat1, $lng1, $lat2, $lng2);
    }

    /**
     * Lit une coordonnée décimale depuis la requête, en la bornant à des
     * valeurs valides. Renvoie null si absente ou hors bornes.
     */
    public static function coordinate(mixed $value, float $min, float $max): ?float
    {
        if ($value === null || $value === '' || ! is_numeric($value)) {
            return null;
        }

        $float = (float) $value;

        return $float >= $min && $float <= $max ? $float : null;
    }

    /**
     * Normalise un libellé géographique pour la recherche et le rapprochement
     * entre jeux de données (casse, espaces, diacritiques, tirements).
     */
    public static function normalizeName(?string $value): string
    {
        $value = trim((string) $value);
        $value = preg_replace('/\s+/u', ' ', $value) ?? $value;
        $transliterated = transliterator_transliterate('Any-Latin; Latin-ASCII; Lower()', $value);

        if ($transliterated === false) {
            $transliterated = mb_strtolower($value, 'UTF-8');
        }

        return trim(preg_replace('/[^a-z0-9]+/', ' ', $transliterated) ?? $transliterated);
    }

    /**
     * Met un libellé géographique en casse lisible en conservant ses accents.
     */
    public static function titleName(?string $value): string
    {
        $value = trim(preg_replace('/\s+/u', ' ', trim((string) $value)) ?? (string) $value);

        return mb_convert_case($value, MB_CASE_TITLE, 'UTF-8');
    }

    /**
     * Réduit une géométrie GeoJSON pour le stockage : précision à 5 décimales
     * (~1 mètre) et nombre de sommets plafonné afin de garder un test de point
     * rapide côté PHP.
     *
     * @param  array{type: string, coordinates: mixed}  $geometry
     * @return array{type: string, coordinates: mixed}|null
     */
    public static function simplifyGeometry(mixed $geometry, int $maxPoints = 600): ?array
    {
        if (! is_array($geometry) || ! isset($geometry['type'], $geometry['coordinates'])) {
            return null;
        }

        $type = (string) $geometry['type'];
        $coordinates = $geometry['coordinates'];

        if ($type === 'Polygon') {
            $rings = self::simplifyRings($coordinates, $maxPoints);

            return $rings === [] ? null : ['type' => 'Polygon', 'coordinates' => $rings];
        }

        if ($type === 'MultiPolygon') {
            $polygons = [];
            foreach (is_array($coordinates) ? $coordinates : [] as $polygon) {
                $rings = self::simplifyRings($polygon, $maxPoints);
                if ($rings !== []) {
                    $polygons[] = $rings;
                }
            }

            return $polygons === [] ? null : ['type' => 'MultiPolygon', 'coordinates' => $polygons];
        }

        return null;
    }

    /**
     * @return array<int, array<int, array<int, float>>>
     */
    private static function simplifyRings(mixed $rings, int $maxPoints): array
    {
        $result = [];

        foreach (is_array($rings) ? $rings : [] as $ring) {
            $points = [];
            $count = is_array($ring) ? count($ring) : 0;

            for ($index = 0; $index < $count; $index++) {
                $point = $ring[$index];
                if (! is_array($point) || ! isset($point[0], $point[1]) || ! is_numeric($point[0]) || ! is_numeric($point[1])) {
                    continue;
                }

                $points[] = [
                    round((float) $point[0], 5),
                    round((float) $point[1], 5),
                ];
            }

            if (count($points) < 4) {
                continue;
            }

            if (count($points) > $maxPoints) {
                $step = (int) ceil(count($points) / $maxPoints);
                $reduced = [];
                foreach ($points as $index => $point) {
                    if ($index % $step === 0) {
                        $reduced[] = $point;
                    }
                }
                $last = $points[count($points) - 1];
                if ($reduced[count($reduced) - 1] !== $last) {
                    $reduced[] = $last;
                }
                $points = $reduced;
            }

            if ($points[0] !== $points[count($points) - 1]) {
                $points[] = $points[0];
            }

            $result[] = $points;
        }

        return $result;
    }

    /**
     * Emprise [minLng, minLat, maxLng, maxLat] d'une géométrie GeoJSON.
     *
     * @param  array{type: string, coordinates: mixed}  $geometry
     * @return array{0: float, 1: float, 2: float, 3: float}|null
     */
    public static function geometryBounds(mixed $geometry): ?array
    {
        $points = self::flattenPoints($geometry);
        if ($points === []) {
            return null;
        }

        $longitudes = array_column($points, 0);
        $latitudes = array_column($points, 1);

        return [
            min($longitudes),
            min($latitudes),
            max($longitudes),
            max($latitudes),
        ];
    }

    /**
     * Centre approximatif d'une géométrie (centre de l'emprise).
     *
     * @param  array{type: string, coordinates: mixed}  $geometry
     * @return array{0: float, 1: float}|null
     */
    public static function geometryCenter(mixed $geometry): ?array
    {
        $bounds = self::geometryBounds($geometry);

        return $bounds === null ? null : [($bounds[1] + $bounds[3]) / 2, ($bounds[0] + $bounds[2]) / 2];
    }

    /**
     * Test du rayon : le point est-il dans le polygone (ou l'un des
     * polygones d'un MultiPolygon) ? Les trous sont exclus.
     *
     * @param  array{type: string, coordinates: mixed}  $geometry
     */
    public static function pointInGeometry(float $latitude, float $longitude, mixed $geometry): bool
    {
        if (! is_array($geometry) || ! isset($geometry['type'], $geometry['coordinates'])) {
            return false;
        }

        $type = (string) $geometry['type'];
        $coordinates = $geometry['coordinates'];

        if ($type === 'Polygon') {
            return self::pointInPolygon($latitude, $longitude, $coordinates);
        }

        if ($type === 'MultiPolygon') {
            foreach (is_array($coordinates) ? $coordinates : [] as $polygon) {
                if (self::pointInPolygon($latitude, $longitude, $polygon)) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * @param  mixed  $polygon  Tableau d'anneaux [outer, holes…]
     */
    private static function pointInPolygon(float $latitude, float $longitude, mixed $polygon): bool
    {
        if (! is_array($polygon) || $polygon === []) {
            return false;
        }

        if (! self::pointInRing($longitude, $latitude, $polygon[0])) {
            return false;
        }

        for ($index = 1; $index < count($polygon); $index++) {
            if (self::pointInRing($longitude, $latitude, $polygon[$index])) {
                return false;
            }
        }

        return true;
    }

    /**
     * @param  mixed  $ring  Séquence de points [longitude, latitude]
     */
    private static function pointInRing(float $x, float $y, mixed $ring): bool
    {
        if (! is_array($ring)) {
            return false;
        }

        $inside = false;
        $count = count($ring);

        for ($i = 0, $j = $count - 1; $i < $count; $j = $i++) {
            $a = $ring[$i] ?? null;
            $b = $ring[$j] ?? null;
            if (! is_array($a) || ! is_array($b) || ! isset($a[0], $a[1], $b[0], $b[1])) {
                continue;
            }

            $xi = (float) $a[0];
            $yi = (float) $a[1];
            $xj = (float) $b[0];
            $yj = (float) $b[1];

            if ((($yi > $y) !== ($yj > $y))
                && ($x < ($xj - $xi) * ($y - $yi) / (($yj - $yi) ?: 1e-12) + $xi)) {
                $inside = ! $inside;
            }
        }

        return $inside;
    }

    /**
     * @return array<int, array<int, float>>
     */
    private static function flattenPoints(mixed $geometry): array
    {
        $points = [];
        $walk = function (mixed $node) use (&$walk, &$points): void {
            if (! is_array($node)) {
                return;
            }

            if (isset($node[0], $node[1]) && is_numeric($node[0]) && is_numeric($node[1])) {
                $points[] = [(float) $node[0], (float) $node[1]];

                return;
            }

            foreach ($node as $child) {
                $walk($child);
            }
        };
        $walk(is_array($geometry) ? ($geometry['coordinates'] ?? []) : []);

        return $points;
    }
}
