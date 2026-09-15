@extends('layouts.app')

@section('content')
<x-admin.page-header
    :title="$rate ? 'Modifier le tarif' : 'Nouveau tarif de livraison'"
    subtitle="Phase 09 — Définir un tarif par zone (J71)"
    :back="route('admin.rates.index')">
</x-admin.page-header>

@if ($errors->any())
    <div class="alert alert-danger">
        <ul class="mb-0">
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
    </div>
@endif

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px; max-width: 760px;">
    <div class="card-body p-4">
        <form method="POST" action="{{ $rate ? route('admin.rates.update', $rate) : route('admin.rates.store') }}">
            @csrf
            @if ($rate)
                @method('PUT')
            @endif

            <div class="row">
                <div class="col-md-6">
                    <div class="form-group">
                        <label for="zone_id" style="color: var(--text-dark); font-weight: 600;">Zone *</label>
                        <select id="zone_id" name="zone_id" class="form-control" required>
                            <option value="">— Choisir une zone —</option>
                            @foreach ($zones as $zone)
                                <option value="{{ $zone->id }}" {{ old('zone_id', $rate?->zone_id) === $zone->id ? 'selected' : '' }}>
                                    {{ $zone->name }} ({{ $zone->city }})
                                </option>
                            @endforeach
                        </select>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-group">
                        <label for="vendor_id" style="color: var(--text-dark); font-weight: 600;">Boutique (optionnel)</label>
                        <select id="vendor_id" name="vendor_id" class="form-control">
                            <option value="">— Tarif par défaut de la zone —</option>
                            @foreach ($vendors as $vendor)
                                <option value="{{ $vendor->id }}" {{ old('vendor_id', $rate?->vendor_id) === $vendor->id ? 'selected' : '' }}>
                                    {{ $vendor->business_name }}
                                </option>
                            @endforeach
                        </select>
                        <small style="color: var(--text-muted);">Sélectionnez une boutique pour un tarif spécifique (surcharge).</small>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label for="price" style="color: var(--text-dark); font-weight: 600;">Prix de livraison (FCFA) *</label>
                <input type="number" id="price" name="price" class="form-control" required min="0" step="1"
                       value="{{ old('price', $rate?->price) }}" placeholder="Ex : 1500">
            </div>

            <div class="row">
                <div class="col-md-6">
                    <div class="form-group">
                        <label for="effective_from" style="color: var(--text-dark); font-weight: 600;">Valide à partir du</label>
                        <input type="date" id="effective_from" name="effective_from" class="form-control"
                               value="{{ old('effective_from', $rate?->effective_from?->format('Y-m-d')) }}">
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-group">
                        <label for="effective_to" style="color: var(--text-dark); font-weight: 600;">Valide jusqu'au</label>
                        <input type="date" id="effective_to" name="effective_to" class="form-control"
                               value="{{ old('effective_to', $rate?->effective_to?->format('Y-m-d')) }}">
                    </div>
                </div>
            </div>

            <div class="form-check mb-4">
                <input class="form-check-input" type="checkbox" id="is_active" name="is_active" value="1"
                       {{ old('is_active', $rate?->is_active ?? true) ? 'checked' : '' }}>
                <label class="form-check-label" for="is_active" style="color: var(--text-dark); font-weight: 600;">
                    Tarif actif
                </label>
            </div>

            <div class="d-flex" style="gap: 8px;">
                <button type="submit" class="btn" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                    <i class="ti ti-check"></i> {{ $rate ? 'Enregistrer' : 'Créer le tarif' }}
                </button>
                <a href="{{ route('admin.rates.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                    Annuler
                </a>
            </div>
        </form>
    </div>
</div>
@endsection