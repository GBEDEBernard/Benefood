<?php

namespace App\Http\Controllers\Admin;

use App\Enums\UserStatus;
use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\View\View;

/**
 * Phase 06 — Gestion des utilisateurs et de leurs rôles depuis le back-office (J45-J53).
 */
class UsersController extends Controller
{
    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = User::query()
            ->with(['roles', 'vendor', 'driverProfile'])
            ->withCount(['roles', 'devices']);

        if ($roleSlug = $request->query('role')) {
            $query->whereHas('roles', fn ($q) => $q->where('slug', $roleSlug));
        }

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($search = trim((string) $request->query('q'))) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%");
            });
        }

        $users = $query->orderByDesc('created_at')->paginate(20)->withQueryString();

        return view('admin.users.index', [
            'users' => $users,
            'roles' => Role::orderBy('name')->get(),
            'statuses' => UserStatus::cases(),
            'filters' => [
                'q' => $request->query('q'),
                'role' => $roleSlug,
                'status' => $status,
            ],
        ]);
    }

    public function show(User $user): View
    {
        $this->authorize('manage', User::class);

        $user->load([
            'roles',
            'devices',
            'vendor',
            'driverProfile',
        ]);

        return view('admin.users.show', [
            'user' => $user,
            'roles' => Role::orderBy('name')->get(),
        ]);
    }

    public function updateStatus(Request $request, User $user): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'status' => ['required', 'string', 'in:'.implode(',', array_column(UserStatus::cases(), 'value'))],
        ]);

        if ($user->id === $request->user()->id && $data['status'] !== UserStatus::Active->value) {
            return back()->with('error', 'Vous ne pouvez pas suspendre votre propre compte.');
        }

        $user->update(['status' => $data['status']]);

        return back()->with('success', "Le statut de « {$user->name} » est maintenant « {$data['status']} ».");
    }

    public function updateRoles(Request $request, User $user): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $roleIds = $request->input('roles', []);

        Validator::make(['roles' => $roleIds], [
            'roles' => ['array'],
            'roles.*' => ['uuid', 'exists:roles,id'],
        ])->validate();

        $activeRoleIds = array_values(array_filter($roleIds));

        if (empty($activeRoleIds)) {
            return back()->with('error', 'Un utilisateur doit avoir au moins un rôle.');
        }

        $remainingAdmin = Role::whereSlug('porteuse')->orWhere('slug', 'admin-technique')->pluck('id')->intersect($roleIds);

        if ($user->id === $request->user()->id && $remainingAdmin->isEmpty()) {
            return back()->with('error', 'Vous devez conserver au moins un rôle administrateur sur votre propre compte.');
        }

        $pivot = [];
        foreach ($activeRoleIds as $index => $id) {
            $pivot[$id] = ['is_active' => $index === 0];
        }

        $user->roles()->sync($pivot);

        return back()->with('success', 'Les rôles de « '.$user->name.' » ont été mis à jour.');
    }
}