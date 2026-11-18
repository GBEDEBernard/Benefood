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
}
