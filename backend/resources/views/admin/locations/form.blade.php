@extends('layouts.app')

@section('content')
<x-admin.page-header
    :title="$neighborhood ? 'Modifier le quartier' : 'Nouveau quartier'"
    :subtitle="$neighborhood ? $neighborhood->city.' · '.$neighborhood->name : 'Ajouter un quartier à une ville'"
>
    <a href="{{ route('admin.locations.index') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
        <i class="ti ti-arrow-left"></i> Retour
    </a>
</x-admin.page-header>

@if ($errors->any())
    <div class="alert alert-danger alert-dismissible fade show" role="alert">
        <ul class="mb-0">
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-4">
        <form method="POST" action="{{ $neighborhood ? route('admin.locations.update', $neighborhood) : route('admin.locations.store') }}">
            @csrf
            @if ($neighborhood)
                @method('PUT')
            @endif

            <div class="row">
                <div class="col-md-6">
                    <div class="form-group">
                        <label for="city" style="color: var(--text-dark); font-weight: 600;">Ville *</label>
                        <input type="text" id="city" name="city" class="form-control" required maxlength="120"
                               list="cities-list" value="{{ old('city', $neighborhood?->city) }}" placeholder="Ex : Cotonou">
                        <datalist id="cities-list">
                            @foreach ($cities as $city)
                                <option value="{{ $city }}"></option>
                            @endforeach
                        </datalist>
                        <small style="color: var(--text-muted);">Saisissez une ville existante ou un nouveau nom pour la créer.</small>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-group">
                        <label for="name" style="color: var(--text-dark); font-weight: 600;">Quartier *</label>
                        <input type="text" id="name" name="name" class="form-control" required maxlength="120"
                               value="{{ old('name', $neighborhood?->name) }}" placeholder="Ex : Fidjrossè">
                    </div>
                </div>
            </div>

            <div class="row">
                <div class="col-md-4">
                    <div class="form-group">
                        <label for="latitude" style="color: var(--text-dark); font-weight: 600;">Latitude</label>
                        <input type="number" id="latitude" name="latitude" step="any" class="form-control"
                               value="{{ old('latitude', $neighborhood?->latitude) }}" placeholder="Ex : 6.3702932">
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-group">
                        <label for="longitude" style="color: var(--text-dark); font-weight: 600;">Longitude</label>
                        <input type="number" id="longitude" name="longitude" step="any" class="form-control"
                               value="{{ old('longitude', $neighborhood?->longitude) }}" placeholder="Ex : 2.3912362">
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-group">
                        <label for="sort_order" style="color: var(--text-dark); font-weight: 600;">Ordre d'affichage</label>
                        <input type="number" id="sort_order" name="sort_order" class="form-control" min="0" step="1"
                               value="{{ old('sort_order', $neighborhood?->sort_order ?? 0) }}">
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label for="delivery_zone_id" style="color: var(--text-dark); font-weight: 600;">Zone de livraison</label>
                <select id="delivery_zone_id" name="delivery_zone_id" class="form-control">
                    <option value="">— Aucune —</option>
                    @foreach ($zones as $zone)
                        <option value="{{ $zone->id }}" {{ old('delivery_zone_id', $neighborhood?->delivery_zone_id) === $zone->id ? 'selected' : '' }}>
                            {{ $zone->city }} — {{ $zone->name }}
                        </option>
                    @endforeach
                </select>
                <small style="color: var(--text-muted);">Utilisée pour la tarification des livraisons dans ce quartier.</small>
            </div>

            <div class="form-check mb-4">
                <input class="form-check-input" type="checkbox" id="is_active" name="is_active" value="1"
                       {{ old('is_active', $neighborhood?->is_active ?? true) ? 'checked' : '' }}>
                <label class="form-check-label" for="is_active" style="color: var(--text-dark); font-weight: 600;">
                    Quartier actif (proposé dans la recherche et les adresses)
                </label>
            </div>

            <div class="d-flex" style="gap: 8px;">
                <button type="submit" class="btn" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                    <i class="ti ti-check"></i> {{ $neighborhood ? 'Enregistrer' : 'Créer le quartier' }}
                </button>
                <a href="{{ route('admin.locations.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                    Annuler
                </a>
            </div>
        </form>
    </div>
</div>
@endsection
