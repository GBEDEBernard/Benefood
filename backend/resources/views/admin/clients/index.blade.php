@extends('layouts.app')

@section('content')
<x-admin.page-header title="Clients" subtitle="Liste des clients — Phase 10">
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

<!-- Filters -->
<form method="GET" action="{{ route('admin.clients.index') }}">
    <div class="card mb-4">
        <div class="card-body py-3">
            <div class="row align-items-center">
                <div class="col-md-4 mb-2 mb-md-0">
                    <input type="text" name="q" value="{{ $filters['q'] ?? '' }}" class="form-control" placeholder="Rechercher par nom, téléphone, email...">
                </div>
                <div class="col-md-3 mb-2 mb-md-0">
                    <select name="status" class="form-control">
                        <option value="">Tous les statuts</option>
                        @foreach ($statuses as $status)
                            <option value="{{ $status->value }}" @selected(($filters['status'] ?? '') === $status->value)>{{ ucfirst($status->value) }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-5 d-flex">
                    <button type="submit" class="btn mr-2" style="background-color: var(--benin-green); color: #FFFFFF;">
                        <i class="ti ti-search"></i> Filtrer
                    </button>
                    <a href="{{ route('admin.clients.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);">
                        Réinitialiser
                    </a>
                </div>
            </div>
        </div>
    </div>
</form>

<!-- Table -->
<div class="card">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover mb-0">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th>Client</th>
                        <th>Rôles</th>
                        <th>Statut</th>
                        <th>Appareils</th>
                        <th>Inscrit le</th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($users as $user)
                        <tr>
                            <td>
                                <div class="d-flex align-items-center">
                                    <div class="rounded-circle d-flex align-items-center justify-content-center mr-3" style="width: 40px; height: 40px; background-color: #E8F5E9; font-weight: 700; color: var(--benin-green);">
                                        {{ strtoupper(substr($user->name, 0, 1)) }}
                                    </div>
                                    <div>
                                        <div style="color: var(--text-dark); font-weight: 600;">{{ $user->name }}</div>
                                        <small style="color: var(--text-muted);">{{ $user->phone }}@if ($user->email) · {{ $user->email }}@endif</small>
                                    </div>
                                </div>
                            </td>
                            <td>
                                @forelse ($user->roles as $role)
                                    <span class="badge mr-1 mb-1" style="background-color: {{ $role->pivot->is_active ? '#E8F5E9' : '#F1F3F4' }}; color: {{ $role->pivot->is_active ? 'var(--benin-green)' : 'var(--text-muted)' }};">{{ $role->name }}</span>
                                @empty
                                    <span class="text-muted">Aucun rôle</span>
                                @endforelse
                            </td>
                            <td>{!! \App\Support\AdminLabels::userStatusBadge($user->status) !!}</td>
                            <td style="color: var(--text-muted);">{{ $user->devices_count }}</td>
                            <td style="color: var(--text-muted);">{{ $user->created_at?->format('d/m/Y H:i') ?? '—' }}</td>
                            <td class="text-right">
                                <a href="{{ route('admin.clients.show', $user) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);">Voir</a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="text-center py-5 text-muted">Aucun client trouvé.</td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($users->hasPages())
        <div class="card-footer" style="background: #FFFFFF;">
            {{ $users->links() }}
        </div>
    @endif
</div>
@endsection
