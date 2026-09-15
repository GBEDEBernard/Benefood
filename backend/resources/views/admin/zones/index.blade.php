@extends('layouts.app')

@section('content')
<x-admin.page-header title="Zones de livraison" subtitle="Phase 09 — Tarification des zones (J69-J70)">
    <div class="d-flex" style="gap: 8px;">
        <a href="{{ route('admin.rates.index') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
            <i class="ti ti-currency-frank"></i> Tarifs
        </a>
        <a href="{{ route('admin.zones.create') }}" class="btn btn-sm" style="background-color: var(--benin-orange); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
            <i class="ti ti-plus"></i> Nouvelle zone
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

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover mb-0">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Zone</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Ville</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Mode d'identification</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Tarifs</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Boutiques</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($zones as $zone)
                        <tr>
                            <td class="py-3">
                                <div style="color: var(--text-dark); font-weight: 600;">{{ $zone->name }}</div>
                                @if ($zone->identification_mode->value === 'distance')
                                    <small style="color: var(--text-muted);">
                                        <i class="ti ti-map-pin"></i> {{ $zone->center_latitude }}, {{ $zone->center_longitude }} · rayon {{ $zone->radius_km }} km
                                    </small>
                                @elseif ($zone->terms)
                                    <small style="color: var(--text-muted);">{{ \Illuminate\Support\Str::limit(implode(', ', $zone->terms), 60) }}</small>
                                @endif
                            </td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $zone->city }}</td>
                            <td class="py-3">
                                <span class="badge badge-pill" style="background-color: #FFF8E1; color: #F57F17; font-weight: 600; padding: 6px 12px; border-radius: 20px;">
                                    {{ \App\Support\AdminLabels::zoneModeLabel($zone->identification_mode->value) }}
                                </span>
                            </td>
                            <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ $zone->rates_count }}</td>
                            <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ $zone->vendors_count }}</td>
                            <td class="py-3">{!! \App\Support\AdminLabels::zoneStatusBadge($zone->is_active) !!}</td>
                            <td class="py-3 text-right">
                                <div class="d-flex justify-content-end" style="gap: 6px;">
                                    <a href="{{ route('admin.zones.edit', $zone) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                        <i class="ti ti-pencil"></i>
                                    </a>
                                    <form method="POST" action="{{ route('admin.zones.destroy', $zone) }}"
                                          class="d-inline" onsubmit="return confirm('Désactiver la zone « {{ $zone->name }} » ?');">
                                        @csrf
                                        @method('DELETE')
                                        <button class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: {{ $zone->is_active ? 'var(--benin-red)' : 'var(--text-muted)' }};"
                                                {{ $zone->is_active ? '' : 'disabled' }}>
                                            <i class="ti ti-trash"></i>
                                        </button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="7" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-map" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucune zone de livraison — créez-en une pour débuter.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
</div>
@endsection