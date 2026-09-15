@extends('layouts.app')

@section('content')
<x-admin.page-header :title="$role->name" :subtitle="$role->description ?? 'Permissions : '.$role->permissions_count" :back="route('admin.roles.index')">
    <span class="badge" style="background-color: #E1F5FE; color: #0277BD; font-weight: 600; padding: 6px 14px; border-radius: 20px;">
        {{ $role->users_count }} utilisateur(s)
    </span>
</x-admin.page-header>

@if (session('success'))
    <div class="alert alert-success alert-dismissible fade show" role="alert">
        {{ session('success') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif

<div class="row">
    <!-- Permissions -->
    <div class="col-lg-8 mb-4">
        <form method="POST" action="{{ route('admin.roles.update', $role) }}">
            @csrf
            @method('PUT')
            <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                <div class="card-header d-flex justify-content-between align-items-center" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                    <h5 class="mb-0" style="color: var(--text-dark); font-weight: 700;">Permissions assignées</h5>
                    <button type="submit" class="btn btn-sm" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-save"></i> Enregistrer
                    </button>
                </div>
                <div class="card-body">
                    @foreach ($allPermissions as $module => $permissions)
                        <div class="mb-4">
                            <div class="d-flex align-items-center mb-2">
                                <span class="badge mr-2" style="background-color: #FFF3E0; color: #E65100; font-weight: 600; padding: 4px 10px; border-radius: 8px; font-size: 11px; text-transform: uppercase;">{{ $module }}</span>
                                <span style="color: var(--text-muted); font-size: 12px;">{{ $permissions->count() }} permission(s)</span>
                            </div>
                            <div class="row">
                                @foreach ($permissions as $permission)
                                    <div class="col-md-6">
                                        <div class="custom-control custom-checkbox mb-2">
                                            <input type="checkbox" class="custom-control-input" id="perm-{{ $permission->id }}" name="permissions[]" value="{{ $permission->id }}"
                                                @checked($role->permissions->contains('id', $permission->id))>
                                            <label class="custom-control-label" for="perm-{{ $permission->id }}" style="cursor: pointer; color: var(--text-dark); font-size: 13px;">
                                                {{ $permission->name }}
                                            </label>
                                        </div>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                    @endforeach
                </div>
            </div>
        </form>
    </div>

    <!-- Utilisateurs ayant ce rôle -->
    <div class="col-lg-4 mb-4">
        <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-header" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                <h5 class="mb-0" style="color: var(--text-dark); font-weight: 700;">Utilisateurs</h5>
            </div>
            <div class="card-body">
                @forelse ($role->users as $user)
                    <div class="d-flex align-items-center mb-3 pb-3 {{ !$loop->last ? 'border-bottom' : '' }}">
                        <div class="rounded-circle d-flex align-items-center justify-content-center mr-3" style="width: 36px; height: 36px; background-color: #E8F5E9; font-weight: 700; color: var(--benin-green); font-size: 14px;">
                            {{ strtoupper(substr($user->name, 0, 1)) }}
                        </div>
                        <div>
                            <a href="{{ route('admin.users.show', $user) }}" style="color: var(--text-dark); font-weight: 600; text-decoration: none;">{{ $user->name }}</a>
                            <br><small style="color: var(--text-muted);">{{ $user->phone ?? $user->email ?? '—' }}</small>
                        </div>
                    </div>
                @empty
                    <p class="text-center mb-0" style="color: var(--text-muted);">Aucun utilisateur avec ce rôle.</p>
                @endforelse
            </div>
        </div>
    </div>
</div>
@endsection