@extends('layouts.app')

@section('content')
<x-admin.page-header title="Tarifs de livraison" subtitle="Phase 09 — Tarif par zone et par vendeur (J71)">
    <div class="d-flex" style="gap: 8px;">
        <a href="{{ route('admin.zones.index') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
            <i class="ti ti-map"></i> Zones
        </a>
        <a href="{{ route('admin.rates.create') }}" class="btn btn-sm" style="background-color: var(--benin-orange); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
            <i class="ti ti-plus"></i> Nouveau tarif
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

<!-- Filtres -->
<form method="GET" action="{{ route('admin.rates.index') }}">
    <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body py-3">
            <div class="row align-items-center">
                <div class="col-md-3">
                    <select name="zone_id" class="form-control">
                        <option value="">Toutes les zones</option>
                        @foreach ($zones as $zone)
                            <option value="{{ $zone->id }}" {{ ($filters['zone_id'] ?? '') === $zone->id ? 'selected' : '' }}>
                                {{ $zone->name }}
                            </option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-3">
                    <select name="vendor_id" class="form-control">
                        <option value="">Tous les vendeurs</option>
                        @foreach ($vendors as $vendor)
                            <option value="{{ $vendor->id }}" {{ ($filters['vendor_id'] ?? '') === $vendor->id ? 'selected' : '' }}>
                                {{ $vendor->business_name }}
                            </option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-2">
                    <select name="scope" class="form-control">
                        <option value="">Défaut + vendeurs</option>
                        <option value="default" {{ ($filters['scope'] ?? '') === 'default' ? 'selected' : '' }}>Par défaut</option>
                        <option value="vendor" {{ ($filters['scope'] ?? '') === 'vendor' ? 'selected' : '' }}>Spécifiques</option>
                    </select>
                </div>
                <div class="col-md-4 d-flex">
                    <button type="submit" class="btn mr-2" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-search"></i> Filtrer
                    </button>
                    <a href="{{ route('admin.rates.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
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
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Zone</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Type</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Boutique</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Prix</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Validité</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($rates as $rate)
                        <tr>
                            <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ $rate->zone?->name ?? '—' }}</td>
                            <td class="py-3">
                                @if ($rate->vendor_id === null)
                                    <span class="badge badge-pill" style="background-color: #E8F5E9; color: #2E7D32; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Défaut</span>
                                @else
                                    <span class="badge badge-pill" style="background-color: #FFF3E0; color: #E65100; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Spécifique</span>
                                @endif
                            </td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $rate->vendor?->business_name ?? '—' }}</td>
                            <td class="py-3" style="color: var(--text-dark); font-weight: 700;">{{ \App\Support\AdminLabels::priceLabel($rate->price) }}</td>
                            <td class="py-3" style="color: var(--text-muted);">
                                {{ $rate->effective_from ? $rate->effective_from->format('d/m/Y') : '∞' }}
                                → {{ $rate->effective_to ? $rate->effective_to->format('d/m/Y') : '∞' }}
                            </td>
                            <td class="py-3">{!! \App\Support\AdminLabels::rateStatusBadge($rate->is_active) !!}</td>
                            <td class="py-3 text-right">
                                <div class="d-flex justify-content-end" style="gap: 6px;">
                                    <a href="{{ route('admin.rates.edit', $rate) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                        <i class="ti ti-pencil"></i>
                                    </a>
                                    <form method="POST" action="{{ route('admin.rates.destroy', $rate) }}"
                                          class="d-inline" onsubmit="return confirm('Désactiver ce tarif ?');">
                                        @csrf
                                        @method('DELETE')
                                        <button class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: {{ $rate->is_active ? 'var(--benin-red)' : 'var(--text-muted)' }};"
                                                {{ $rate->is_active ? '' : 'disabled' }}>
                                            <i class="ti ti-trash"></i>
                                        </button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="7" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-currency-frank" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucun tarif — créez un tarif par défaut par zone.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($rates->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $rates->links() }}
        </div>
    @endif
</div>
@endsection