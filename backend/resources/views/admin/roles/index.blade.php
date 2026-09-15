@extends('layouts.app')

@section('content')
<x-admin.page-header title="Rôles & Permissions" subtitle="Phase 06 — RBAC & accès">
    <a href="{{ route('admin.dashboard') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
        <i class="ti ti-home"></i> Dashboard
    </a>
</x-admin.page-header>

@if (session('success'))
    <div class="alert alert-success alert-dismissible fade show" role="alert">
        {{ session('success') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif

<div class="row">
    @forelse ($roles as $role)
        <div class="col-md-4 mb-4">
            <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px; transition: transform 0.2s;">
                <div class="card-body">
                    <div class="d-flex align-items-center justify-content-between mb-3">
                        <div class="rounded-circle d-flex align-items-center justify-content-center" style="width: 46px; height: 46px; background-color: #E8F5E9;">
                            <i class="ti ti-lock" style="color: var(--benin-green);"></i>
                        </div>
                        <a href="{{ route('admin.roles.show', $role) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                            <i class="ti ti-eye"></i> Voir
                        </a>
                    </div>
                    <h5 class="mb-1" style="color: var(--text-dark); font-weight: 700;">{{ $role->name }}</h5>
                    <p class="mb-3" style="color: var(--text-muted); font-size: 13px;">{{ $role->description ?? '—' }}</p>
                    <div class="d-flex justify-content-between">
                        <span class="badge" style="background-color: #E1F5FE; color: #0277BD; font-weight: 600; padding: 5px 10px; border-radius: 8px; font-size: 12px;">
                            {{ $role->permissions_count }} permissions
                        </span>
                        <span class="badge" style="background-color: #FFF3E0; color: #E65100; font-weight: 600; padding: 5px 10px; border-radius: 8px; font-size: 12px;">
                            {{ $role->users_count }} utilisateur(s)
                        </span>
                    </div>
                </div>
            </div>
        </div>
    @empty
        <div class="col-12">
            <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                <div class="card-body text-center py-5" style="color: var(--text-muted);">
                    <i class="ti ti-lock" style="font-size: 40px;"></i>
                    <p class="mt-2 mb-0">Aucun rôle trouvé.</p>
                </div>
            </div>
        </div>
    @endforelse
</div>
@endsection