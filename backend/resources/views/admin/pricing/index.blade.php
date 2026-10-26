@extends('layouts.app')

@section('content')
<x-admin.page-header title="Tarifs et barèmes de distance" subtitle="Paramétrez les frais, les commissions et les paliers appliqués aux commandes et aux colis">
    <a href="{{ route('admin.commissions.index') }}" class="btn btn-sm" style="background:#fff;border:1px solid var(--border-color);border-radius:8px;color:var(--text-dark)">
        <i class="ti ti-percentage"></i> Gérer les commissions (client, vendeur, livreur, colis)
    </a>
</x-admin.page-header>

@if (session('success'))
    <div class="alert alert-success">{{ session('success') }}</div>
@endif
@if (session('error'))
    <div class="alert alert-danger">{{ session('error') }}</div>
@endif
@if ($errors->any())
    <div class="alert alert-danger">
        <ul class="mb-0">@foreach ($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul>
    </div>
@endif

<div class="card mb-4" style="border:0;box-shadow:0 2px 10px rgba(0,0,0,.05);border-radius:12px">
    <div class="card-body">
        <h5 class="font-weight-bold mb-1">Montants et répartitions</h5>
        <p class="text-muted mb-4">Les changements affectent les nouveaux devis et paiements. Les commandes et colis déjà créés gardent leurs montants.</p>
        <form method="POST" action="{{ route('admin.pricing.settings') }}">
            @csrf
            <div class="row">
                <div class="col-lg-3 col-md-6 form-group">
                    <label for="order_minimum_fee">Minimum livraison commande (F CFA)</label>
                    <input id="order_minimum_fee" name="order_minimum_fee" type="number" min="0" step="1" required class="form-control" value="{{ old('order_minimum_fee', $settings['order_minimum_fee']) }}">
                </div>
                <div class="col-lg-3 col-md-6 form-group">
                    <label for="order_default_fee">Repli si coordonnées absentes (commande)</label>
                    <input id="order_default_fee" name="order_default_fee" type="number" min="0" step="1" required class="form-control" value="{{ old('order_default_fee', $settings['order_default_fee']) }}">
                </div>
                <div class="col-lg-3 col-md-6 form-group">
                    <label for="parcel_minimum_fee">Minimum livraison colis (F CFA)</label>
                    <input id="parcel_minimum_fee" name="parcel_minimum_fee" type="number" min="0" step="1" required class="form-control" value="{{ old('parcel_minimum_fee', $settings['parcel_minimum_fee']) }}">
                </div>
                <div class="col-lg-3 col-md-6 form-group">
                    <label for="parcel_default_fee">Repli si coordonnées absentes (colis)</label>
                    <input id="parcel_default_fee" name="parcel_default_fee" type="number" min="0" step="1" required class="form-control" value="{{ old('parcel_default_fee', $settings['parcel_default_fee']) }}">
                </div>
                <div class="col-lg-3 col-md-6 form-group">
                    <label for="parcel_creation_fee">Frais de création de colis (F CFA)</label>
                    <input id="parcel_creation_fee" name="parcel_creation_fee" type="number" min="0" step="1" required class="form-control" value="{{ old('parcel_creation_fee', $settings['parcel_creation_fee']) }}">
                    <small class="text-muted">Payé par le créateur du colis, en plus de la livraison.</small>
                </div>
            </div>
            <div class="d-flex justify-content-end">
                <button class="btn" style="background:var(--benin-green);color:#fff;border-radius:8px;font-weight:600"><i class="ti ti-device-floppy"></i> Enregistrer les montants</button>
            </div>
        </form>
    </div>
</div>

@php
    $ruleGroups = [
        ['type' => 'order', 'title' => 'Commandes de produits', 'description' => 'Distance boutique → adresse du client.', 'rules' => $orderRules],
        ['type' => 'parcel', 'title' => 'Envoi de colis', 'description' => 'Distance lieu de ramassage → lieu de livraison.', 'rules' => $parcelRules],
    ];
@endphp

@foreach ($ruleGroups as $group)
<div class="card mb-4" style="border:0;box-shadow:0 2px 10px rgba(0,0,0,.05);border-radius:12px">
    <div class="card-header bg-white" style="border-bottom:1px solid var(--border-color);border-radius:12px 12px 0 0">
        <h5 class="font-weight-bold mb-1">{{ $group['title'] }}</h5>
        <small class="text-muted">{{ $group['description'] }} Le prix du palier est calculé depuis sa borne précédente; la réduction est appliquée au montant obtenu.</small>
    </div>
    <div class="table-responsive">
        <table class="table mb-0">
            <thead style="background:#f9fafb">
                <tr>
                    <th class="border-0">Distance maximale (km)</th>
                    <th class="border-0">Prix au début du palier (F)</th>
                    <th class="border-0">Supplément par km (F)</th>
                    <th class="border-0">Réduction (%)</th>
                    <th class="border-0 text-right">Actions</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($group['rules'] as $rule)
                    @php($formId = 'update-rule-'.$rule->id)
                    <tr>
                        <td class="align-middle">
                            <input form="{{ $formId }}" name="max_km" type="number" min="0.001" max="10000" step="0.001" class="form-control" value="{{ $rule->max_km === null ? '' : $rule->max_km }}" placeholder="Sans limite (dernier palier)">
                        </td>
                        <td class="align-middle"><input form="{{ $formId }}" name="base_fee" type="number" min="0" step="1" required class="form-control" value="{{ $rule->base_fee }}"></td>
                        <td class="align-middle"><input form="{{ $formId }}" name="per_km" type="number" min="0" step="1" required class="form-control" value="{{ $rule->per_km }}"></td>
                        <td class="align-middle"><input form="{{ $formId }}" name="discount_percentage" type="number" min="0" max="100" step="1" required class="form-control" value="{{ $rule->discount_percentage }}"></td>
                        <td class="align-middle text-right text-nowrap">
                            <form id="{{ $formId }}" method="POST" action="{{ route('admin.pricing.rules.update', $rule) }}">
                                @csrf
                                @method('PUT')
                            </form>
                            <button form="{{ $formId }}" class="btn btn-sm" style="background:var(--benin-green);color:#fff" title="Enregistrer"><i class="ti ti-device-floppy"></i></button>
                            <form method="POST" action="{{ route('admin.pricing.rules.destroy', $rule) }}" class="d-inline" onsubmit="return confirm('Supprimer ce palier ?');">
                                @csrf
                                @method('DELETE')
                                <button class="btn btn-sm btn-outline-danger" title="Supprimer"><i class="ti ti-trash"></i></button>
                            </form>
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    </div>
    <div class="card-body" style="border-top:1px solid var(--border-color)">
        <h6 class="font-weight-bold">Ajouter un palier {{ $group['type'] === 'order' ? 'de commande' : 'de colis' }}</h6>
        <form method="POST" action="{{ route('admin.pricing.rules.store') }}" class="row align-items-end">
            @csrf
            <input type="hidden" name="service_type" value="{{ $group['type'] }}">
            <div class="col-lg-3 col-md-6 form-group">
                <label>Distance maximale (km)</label>
                <input name="max_km" type="number" min="0.001" max="10000" step="0.001" class="form-control" placeholder="Ex. 12" required>
                <small class="text-muted">Laissez le palier final « sans limite » en place.</small>
            </div>
            <div class="col-lg-3 col-md-6 form-group"><label>Prix au début du palier (F)</label><input name="base_fee" type="number" min="0" step="1" class="form-control" required></div>
            <div class="col-lg-3 col-md-6 form-group"><label>Supplément par km (F)</label><input name="per_km" type="number" min="0" step="1" value="0" class="form-control" required></div>
            <div class="col-lg-2 col-md-6 form-group"><label>Réduction (%)</label><input name="discount_percentage" type="number" min="0" max="100" step="1" value="0" class="form-control" required></div>
            <div class="col-lg-1 form-group"><button class="btn btn-block" style="background:var(--benin-orange);color:#fff" title="Ajouter"><i class="ti ti-plus"></i></button></div>
        </form>
    </div>
</div>
@endforeach

<div class="alert alert-info">
    <strong>Note :</strong> les distances sont actuellement calculées à vol d’oiseau à partir des coordonnées GPS. Les remises et règles modifiées ici ne changent pas rétroactivement les commandes déjà enregistrées.
</div>
@endsection
