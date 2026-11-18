<?php

use App\Support\Geo;

if (! function_exists('haversine_distance')) {
    /**
     * Distance à vol d'oiseau (Haversine) entre deux points GPS, en km.
     */
    function haversine_distance(mixed $lat1, mixed $lng1, mixed $lat2, mixed $lng2): ?float
    {
        return Geo::haversineKm($lat1, $lng1, $lat2, $lng2);
    }
}
