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
