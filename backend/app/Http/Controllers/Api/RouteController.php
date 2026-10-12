<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\RoutingService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Calcul d'itinéraire routier (navigation livreur, suivi client).
 *
 * Endpoint authentifié : le tracé est calculé côté serveur (clé Google/OSRM
 * non exposée au client mobile) puis renvoyé sous forme de polyligne.
 */
class RouteController extends Controller
{
    public function __construct(private readonly RoutingService $routingService) {}

    public function plan(Request $request): JsonResponse
    {
        $data = $request->validate([
            'points' => ['required', 'array', 'min:2', 'max:10'],
            'points.*.latitude' => ['required', 'numeric', 'between:-90,90'],
            'points.*.longitude' => ['required', 'numeric', 'between:-180,180'],
            'profile' => ['sometimes', 'string', 'in:moto,car,foot'],
        ]);

        return Api::ok($this->routingService->plan(
            $data['points'],
            $data['profile'] ?? 'moto',
        ));
    }
}
