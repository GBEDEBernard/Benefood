@extends('layouts.app')

@section('content')
<x-admin.page-header title="Villes & quartiers" subtitle="Référentiel utilisé par la recherche et les adresses">
    <div class="d-flex" style="gap: 8px;">
        <a href="{{ route('admin.zones.index') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
            <i class="ti ti-map"></i> Zones
        </a>
        <a href="{{ route('admin.locations.create') }}" class="btn btn-sm" style="background-color: var(--benin-orange); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
            <i class="ti ti-plus"></i> Nouveau quartier
        </a>
    </div>
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

@if ($cities->isEmpty())
    <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body text-center py-5" style="color: var(--text-muted);">
            <i class="ti ti-map-pin" style="font-size: 40px;"></i>
            <p class="mt-2 mb-0">Aucun quartier — créez-en un pour définir une ville.</p>
        </div>
    </div>
@endif

@foreach ($cities as $city => $items)
    <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body p-0">
            <div class="d-flex align-items-center justify-content-between px-4 py-3" style="background-color: #F9FAFB; border-radius: 12px 12px 0 0;">
                <div style="color: var(--text-dark); font-weight: 700;">
                    <i class="ti ti-building-community" style="color: var(--benin-orange);"></i> {{ $city }}
                </div>
                <small style="color: var(--text-muted);">{{ $items->count() }} quartier(s)</small>
            </div>
            <div class="table-responsive">
                <table class="table table-hover mb-0">
                    <thead style="background-color: #FFFFFF;">
                        <tr>
                            <th class="border-0 py-3 px-4" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Quartier</th>
                            <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Coordonnées</th>
                            <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Zone de livraison</th>
                            <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Ordre</th>
                            <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                            <th class="border-0 py-3"></th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($items as $neighborhood)
                            <tr>
                                <td class="py-3 px-4" style="color: var(--text-dark); font-weight: 600;">{{ $neighborhood->name }}</td>
                                <td class="py-3" style="color: var(--text-muted);">
                                    @if ($neighborhood->latitude !== null && $neighborhood->longitude !== null)
                                        <i class="ti ti-map-pin"></i> {{ $neighborhood->latitude }}, {{ $neighborhood->longitude }}
                                    @else
                                        —
                                    @endif
                                </td>
                                <td class="py-3" style="color: var(--text-muted);">
                                    {{ $neighborhood->deliveryZone?->name ?? '—' }}
                                </td>
                                <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ $neighborhood->sort_order }}</td>
                                <td class="py-3">{!! \App\Support\AdminLabels::zoneStatusBadge($neighborhood->is_active) !!}</td>
                                <td class="py-3 text-right">
                                    <div class="d-flex justify-content-end" style="gap: 6px;">
                                        <a href="{{ route('admin.locations.edit', $neighborhood) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                            <i class="ti ti-pencil"></i>
                                        </a>
                                        <form method="POST" action="{{ route('admin.locations.destroy', $neighborhood) }}"
                                              class="d-inline" onsubmit="return confirm('Désactiver le quartier « {{ $neighborhood->name }} » ?');">
                                            @csrf
                                            @method('DELETE')
                                            <button class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: {{ $neighborhood->is_active ? 'var(--benin-red)' : 'var(--text-muted)' }};"
                                                    {{ $neighborhood->is_active ? '' : 'disabled' }}>
                                                <i class="ti ti-trash"></i>
                                            </button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>
    </div>
@endforeach
@endsection
