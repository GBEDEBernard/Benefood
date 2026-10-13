<?php

namespace App\Http\Middleware;

use App\Support\Api;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Middleware `permission:slug` — vérifie une permission cumulée via les rôles (J32 §6).
 */
class EnsureHasPermission
{
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        $user = $request->user();

        if ($user === null) {
            return Api::error('Vous devez être authentifié.', 'unauthenticated', 401);
        }

        // Une ou plusieurs permissions acceptées, séparées par « | »
        // (ex. `permission:client.parcels.manage|vendor.parcels.manage`) :
        // il suffit que le compte possède l'une d'elles.
        foreach (explode('|', $permission) as $slug) {
            if ($user->hasPermission(trim($slug))) {
                return $next($request);
            }
        }

        return Api::error('Accès refusé.', 'forbidden', 403);
    }
}
