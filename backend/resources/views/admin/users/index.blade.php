@extends('layouts.app')

@section('content')
<x-admin.page-header title="Utilisateurs" subtitle="Comptes, rôles et statuts — Phase 06">
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
@if (session('error'))
    <div class="alert alert-danger alert-dismissible fade show" role="alert">
        {{ session('error') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif

<!-- Filters -->
<form method="GET" action="{{ route('admin.users.index') }}">
    <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body py-3">
            <div class="row align-items-center">
                <div class="col-md-4 mb-2 mb-md-0">
                    <input type="text" name="q" value="{{ $filters['q'] ?? '' }}" class="form-control" placeholder="Rechercher par nom, téléphone, email...">
                </div>
                <div class="col-md-3 mb-2 mb-md-0">
                    <select name="role" class="form-control">
                        <option value="">Tous les rôles</option>
                        @foreach ($roles as $role)
                            <option value="{{ $role->slug }}" @selected(($filters['role'] ?? '') === $role->slug)>{{ $role->name }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-2 mb-2 mb-md-0">
                    <select name="status" class="form-control">
                        <option value="">Tous les statuts</option>
                        @foreach ($statuses as $status)
                            <option value="{{ $status->value }}" @selected(($filters['status'] ?? '') === $status->value)>{{ ucfirst($status->value) }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-3 d-flex">
                    <button type="submit" class="btn mr-2" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-search"></i> Filtrer
                    </button>
                    <a href="{{ route('admin.users.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                        Réinitialiser
                    </a>
                </div>
            </div>
        </div>
    </div>
</form>

<!-- Table -->
<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover mb-0">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Utilisateur</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Rôles</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Appareils</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Inscrit le</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($users as $user)
                        <tr>
                            <td class="py-3">
                                <div class="d-flex align-items-center">
                                    <div class="rounded-circle d-flex align-items-center justify-content-center mr-3" style="width: 40px; height: 40px; background-color: #E8F5E9; font-weight: 700; color: var(--benin-green); font-size: 15px;">
                                        {{ strtoupper(substr($user->name, 0, 1)) }}
                                    </div>
                                    <div>
                                        <div style="color: var(--text-dark); font-weight: 600;">{{ $user->name }}</div>
                                        <small style="color: var(--text-muted);">{{ $user->phone }}@if ($user->email) · {{ $user->email }}@endif</small>
                                    </div>
                                </div>
                            </td>
                            <td class="py-3">
                                @forelse ($user->roles as $role)
                                    <span class="badge mr-1 mb-1" style="background-color: {{ $role->pivot->is_active ? '#E8F5E9' : '#F1F3F4' }}; color: {{ $role->pivot->is_active ? 'var(--benin-green)' : 'var(--text-muted)' }}; font-weight: 600; padding: 5px 10px; border-radius: 8px;">
                                        {{ $role->name }}
                                    </span>
                                @empty
                                    <span class="text-muted">Aucun rôle</span>
                                @endforelse
                            </td>
                            <td class="py-3">{!! \App\Support\AdminLabels::userStatusBadge($user->status) !!}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $user->devices_count }}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $user->created_at?->format('d/m/Y H:i') ?? '—' }}</td>
                            <td class="py-3 text-right">
                                <a href="{{ route('admin.users.show', $user) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                    <i class="ti ti-eye"></i> Voir
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-user" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucun utilisateur trouvé.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($users->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $users->links() }}
        </div>
    @endif
</div>
@endsection