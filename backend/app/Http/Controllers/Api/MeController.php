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

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'email' => ['sometimes', 'nullable', 'email', 'max:255'],
        ]);

        $user = $this->auth->updateProfile($request->user(), $data);

        return Api::ok(new UserResource($user->loadMissing('roles')));
    }

    public function devices(Request $request): JsonResponse
    {
        $devices = $request->user()->devices()->orderByDesc('last_seen_at')->get();

        return Api::ok($devices->map(function ($device) {
            return [
                'id' => $device->id,
                'platform' => $device->platform,
                'device_type' => $device->device_type,
                'app_version' => $device->app_version,
                'is_active' => $device->is_active,
                'last_seen_at' => $device->last_seen_at?->toIso8601String(),
            ];
        })->values());
    }

    public function registerDevice(Request $request): JsonResponse
    {
        $data = $request->validate([
            'fcm_token' => ['required', 'string', 'max:255'],
            'platform' => ['required', 'string', 'in:android,ios,web'],
            'device_type' => ['sometimes', 'nullable', 'string', 'max:64'],
            'app_version' => ['sometimes', 'nullable', 'string', 'max:32'],
        ]);

        $device = $this->auth->registerDevice($request->user(), $data);

        return Api::created([
            'id' => $device->id,
            'platform' => $device->platform,
            'is_active' => $device->is_active,
        ]);
    }
}
