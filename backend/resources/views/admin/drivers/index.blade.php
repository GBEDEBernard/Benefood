@extends('layouts.app')

@section('content')
<x-admin.page-header title="Livreurs" subtitle="Phase 16 — Gestion des livreurs">
    <a href="{{ route('admin.drivers.create') }}" class="btn btn-sm" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
        <i class="ti ti-plus"></i> Créer un livreur
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

@php
    $statusChips = [
        ['key' => '', 'label' => 'Tous', 'count' => $counts['all'], 'fg' => 'var(--benin-green)'],
        ['key' => 'active', 'label' => 'Actifs', 'count' => $counts['active'], 'fg' => 'var(--benin-green)'],
        ['key' => 'online', 'label' => 'En ligne', 'count' => $counts['online'], 'fg' => 'var(--text-dark)'],
        ['key' => 'pending', 'label' => 'En validation', 'count' => $counts['pending'], 'fg' => 'var(--benin-orange)'],
        ['key' => 'suspended', 'label' => 'Suspendus', 'count' => $counts['suspended'], 'fg' => 'var(--benin-red)'],
    ];
    $activeFilter = $filters['status'] ?? '';
    if ($activeFilter === '' && ($filters['available'] ?? '') === '1') {
        $activeFilter = 'online';
    }
@endphp
<div class="row mb-4">
    <div class="col-12">
        <ul class="nav" style="gap: 8px; flex-wrap: wrap; list-style: none; padding: 0; margin: 0;">
            @foreach ($statusChips as $chip)
                <li class="nav-item">
                    <a class="btn btn-sm"
                       @if ($chip['key'] === 'online')
                           href="{{ route('admin.drivers.index', array_merge(['available' => '1', 'q' => $filters['q'] ?? null])) }}"
                       @else
                           href="{{ route('admin.drivers.index', array_merge(['status' => $chip['key'] ?: null, 'q' => $filters['q'] ?? null])) }}"
                       @endif
                       style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ $activeFilter === $chip['key'] ? 'background-color: '.$chip['fg'].'; color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                        {{ $chip['label'] }} <span class="ml-1" style="font-weight: 700;">{{ $chip['count'] }}</span>
                    </a>
                </li>
            @endforeach
        </ul>
    </div>
</div>

<form method="GET" action="{{ route('admin.drivers.index') }}">
    @if (! empty($filters['status']))
        <input type="hidden" name="status" value="{{ $filters['status'] }}">
    @endif
    @if (($filters['available'] ?? '') === '1')
        <input type="hidden" name="available" value="1">
    @endif
    <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body py-3">
            <div class="row align-items-center">
                <div class="col-md-8">
                    <input type="text" name="q" value="{{ $filters['q'] ?? '' }}" class="form-control" placeholder="Rechercher par nom, téléphone, véhicule...">
                </div>
                <div class="col-md-4 d-flex">
                    <button type="submit" class="btn mr-2" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-search"></i> Filtrer
                    </button>
                    <a href="{{ route('admin.drivers.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                        Réinitialiser
                    </a>
                </div>
            </div>
        </div>
    </div>
</form>

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover mb-0">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Livreur</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Type</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Véhicule</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Disponibilité</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Inscrit le</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($drivers as $driver)
                        <tr>
                            <td class="py-3">
                                <div style="color: var(--text-dark); font-weight: 600;">{{ $driver->user?->name ?? '—' }}</div>
                                <small style="color: var(--text-muted);">{{ $driver->user?->phone }}</small>
                            </td>
                            <td class="py-3" style="color: var(--text-muted);">
                                {{ $driver->type === 'beninfood' ? 'Beninfood' : 'Indépendant' }}
                            </td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $driver->vehicle ?? '—' }}</td>
                            <td class="py-3">{!! \App\Support\AdminLabels::availableBadge((bool) $driver->available) !!}</td>
                            <td class="py-3">{!! \App\Support\AdminLabels::driverStatusBadge($driver->status) !!}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $driver->created_at?->format('d/m/Y') ?? '—' }}</td>
                            <td class="py-3 text-right">
                                <a href="{{ route('admin.drivers.show', $driver) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                    <i class="ti ti-eye"></i> Voir
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="7" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-truck" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucun livreur trouvé.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($drivers->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $drivers->links() }}
        </div>
    @endif
</div>
@endsection