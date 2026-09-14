<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Services\AuthService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Profil et contexte d'utilisation (J51-J52).
 */
class MeController extends Controller
{
    public function __construct(private readonly AuthService $auth) {}

    public function show(Request $request): JsonResponse
    {
        return Api::ok(new UserResource($request->user()->loadMissing('roles')));
    }

    public function roles(Request $request): JsonResponse
    {
        $roles = $request->user()->roles()
            ->orderByPivot('is_active', 'desc')
            ->orderByPivot('last_used_at', 'desc')
            ->get();

        return Api::ok($roles->map(fn ($role) => [
            'role' => [
                'slug' => $role->slug,
                'name' => $role->name,
            ],
            'is_active' => (bool) $role->pivot->is_active,
        ])->values());
    }

    public function activeRole(Request $request): JsonResponse
    {
        $data = $request->validate([
            'role_slug' => ['required', 'string', 'max:64'],
        ]);

        $active = $this->auth->switchActiveRole($request->user(), $data['role_slug']);

        return Api::ok([
            'active_role' => $active,
            'message' => "Mode « {$active} » activé.",
        ]);
    }
}
