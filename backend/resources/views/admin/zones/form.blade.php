@extends('layouts.app')

@section('content')
<x-admin.page-header
    :title="$zone ? 'Modifier la zone' : 'Nouvelle zone de livraison'"
    :subtitle="$zone ? $zone->name : 'Définir une zone tarifaire (J70)'"
    :back="route('admin.zones.index')">
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
        <form method="POST" action="{{ $zone ? route('admin.zones.update', $zone) : route('admin.zones.store') }}">
            @csrf
            @if ($zone)
                @method('PUT')
            @endif

            <div class="row">
                <div class="col-md-6">
                    <div class="form-group">
                        <label for="name" style="color: var(--text-dark); font-weight: 600;">Nom de la zone *</label>
                        <input type="text" id="name" name="name" class="form-control" required maxlength="255"
                               value="{{ old('name', $zone?->name) }}" placeholder="Ex : Cotonou Centre">
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-group">
                        <label for="city" style="color: var(--text-dark); font-weight: 600;">Ville *</label>
                        <input type="text" id="city" name="city" class="form-control" required maxlength="255"
                               value="{{ old('city', $zone?->city) }}" placeholder="Ex : Cotonou">
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label for="identification_mode" style="color: var(--text-dark); font-weight: 600;">Mode d'identification de la zone *</label>
                <select id="identification_mode" name="identification_mode" class="form-control" required>
                    @foreach ($modes as $mode)
                        <option value="{{ $mode->value }}" {{ old('identification_mode', $zone?->identification_mode?->value ?? 'zone') === $mode->value ? 'selected' : '' }}>
                            {{ $mode->label() }}
                        </option>
                    @endforeach
                </select>
                <small style="color: var(--text-muted);">
                    Quartier / Secteur : saisi des noms ci-dessous. Distance : point central + rayon. Combinaison : les deux.
                </small>
            </div>

            <div class="form-group">
                <label for="terms" style="color: var(--text-dark); font-weight: 600;">Noms (quartiers / secteurs)</label>
                <textarea id="terms" name="terms" class="form-control" rows="2"
                          placeholder="Un nom par ligne — ex : Akpakpa, Fidjrossè, Cadjehoun">{{ old('terms', $zone?->terms ? implode("\n", $zone->terms) : '') }}</textarea>
            </div>

            <div class="row">
                <div class="col-md-4">
                    <div class="form-group">
                        <label for="center_latitude" style="color: var(--text-dark); font-weight: 600;">Latitude (centre)</label>
                        <input type="number" id="center_latitude" name="center_latitude" step="any" class="form-control"
                               value="{{ old('center_latitude', $zone?->center_latitude) }}" placeholder="Ex : 6.3702932">
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-group">
                        <label for="center_longitude" style="color: var(--text-dark); font-weight: 600;">Longitude (centre)</label>
                        <input type="number" id="center_longitude" name="center_longitude" step="any" class="form-control"
                               value="{{ old('center_longitude', $zone?->center_longitude) }}" placeholder="Ex : 2.3912362">
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-group">
                        <label for="radius_km" style="color: var(--text-dark); font-weight: 600;">Rayon (km)</label>
                        <input type="number" id="radius_km" name="radius_km" step="0.001" min="0" class="form-control"
                               value="{{ old('radius_km', $zone?->radius_km) }}" placeholder="Ex : 5">
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label for="sort_order" style="color: var(--text-dark); font-weight: 600;">Ordre d'affichage</label>
                <input type="number" id="sort_order" name="sort_order" class="form-control" min="0" step="1"
                       value="{{ old('sort_order', $zone?->sort_order ?? 0) }}">
            </div>

            <div class="form-check mb-4">
                <input class="form-check-input" type="checkbox" id="is_active" name="is_active" value="1"
                       {{ old('is_active', $zone?->is_active ?? true) ? 'checked' : '' }}>
                <label class="form-check-label" for="is_active" style="color: var(--text-dark); font-weight: 600;">
                    Zone active (utilisée pour la tarification)
                </label>
            </div>

            <div class="d-flex" style="gap: 8px;">
                <button type="submit" class="btn" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                    <i class="ti ti-check"></i> {{ $zone ? 'Enregistrer' : 'Créer la zone' }}
                </button>
                <a href="{{ route('admin.zones.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                    Annuler
                </a>
            </div>
        </form>
    </div>
</div>
@endsection