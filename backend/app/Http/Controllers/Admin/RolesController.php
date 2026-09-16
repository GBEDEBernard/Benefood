<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\View\View;

/**
 * Phase 06 — Rôles et permissions (RBAC) depuis le back-office (J32 §3, J50).
 */
class RolesController extends Controller
{
    public function index(): View
    {
        $this->authorize('manage', User::class);

        $roles = Role::query()
            ->withCount(['permissions'])
            ->withCount(['users'])
            ->orderBy('name')
            ->get();

        return view('admin.roles.index', ['roles' => $roles]);
    }

    public function show(Role $role): View
    {
        $this->authorize('manage', User::class);

        $role->load(['permissions', 'users']);
        $permissionsByModule = $role->permissions->groupBy(fn (Permission $permission) => $permission->module ?: 'global');

        return view('admin.roles.show', [
            'role' => $role,
            'permissionsByModule' => $permissionsByModule,
            'allPermissions' => Permission::orderBy('module')->orderBy('name')->get()->groupBy('module'),
        ]);
    }

    public function update(Request $request, Role $role): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $permissionIds = $request->input('permissions', []);

        Validator::make(['permissions' => $permissionIds], [
            'permissions' => ['array'],
            'permissions.*' => ['uuid', 'exists:permissions,id'],
        ])->validate();

        $role->permissions()->sync($permissionIds);

        return back()->with('success', 'Les permissions du rôle « '.$role->name.' » ont été enregistrées.');
    }
}
