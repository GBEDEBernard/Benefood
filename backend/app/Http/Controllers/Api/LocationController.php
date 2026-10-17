<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Neighborhood;
use App\Support\Api;
use Illuminate\Http\JsonResponse;

/**
 * Référentiel géographique public : villes et quartiers, utilisés par le
 * client pour la recherche par localité et les sélecteurs d'adresse/colis.
 */
class LocationController extends Controller
{
    public function index(): JsonResponse
    {
        $neighborhoods = Neighborhood::query()
            ->active()
            ->orderBy('city')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        $cities = $neighborhoods
            ->groupBy('city')
            ->map(fn ($items, string $city) => [
                'city' => $city,
                'neighborhoods' => $items->map(fn (Neighborhood $neighborhood) => [
                    'id' => $neighborhood->id,
                    'name' => $neighborhood->name,
                    'latitude' => $neighborhood->latitude,
                    'longitude' => $neighborhood->longitude,
                ])->values(),
            ])
            ->values();

        return Api::ok($cities);
    }
}
