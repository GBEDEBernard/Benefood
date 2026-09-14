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
            return Api::error('Vous devez être authentifié.', 'unauthenticated', 401)->toResponse($request);
        }

        if (! $user->hasPermission($permission)) {
            return Api::error('Accès refusé.', 'forbidden', 403)->toResponse($request);
        }

        return $next($request);
    }
}
