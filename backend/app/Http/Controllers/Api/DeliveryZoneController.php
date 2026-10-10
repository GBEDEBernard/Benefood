<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DeliveryZone;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Zones de livraison sélectionnables (J34/J56) : liste de référence utilisée
 * par le vendeur pour définir ses zones desservies.
 */
class DeliveryZoneController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $zones = DeliveryZone::query()
            ->active()
            ->orderBy('name')
            ->get()
            ->map(fn (DeliveryZone $zone) => [
                'id' => $zone->id,
                'name' => $zone->name,
                'city' => $zone->city,
            ])
            ->values();

        return Api::ok($zones);
    }
}
