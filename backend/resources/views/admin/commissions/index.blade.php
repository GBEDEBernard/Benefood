@extends('layouts.app')

@section('content')
<x-admin.page-header title="Commissions" subtitle="Commissions client, vendeur, livreur et colis — application immédiate aux nouvelles transactions">
    <a href="{{ route('admin.dashboard') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
        <i class="ti ti-home"></i> Dashboard
    </a>
    <a href="{{ route('admin.pricing.index') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
        <i class="ti ti-map-alt"></i> Tarifs par distance
    </a>
</x-admin.page-header>

@if (session('success'))
    <div class="alert alert-success alert-dismissible fade show" role="alert">
        {{ session('success') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif
@if ($errors->any())
    <div class="alert alert-danger"><ul class="mb-0">@foreach ($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul></div>
@endif

<div class="row">
    <div class="col-md-8">
        <!-- Range → taux actif -->
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body p-0">
                <div class="card-header" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                    <h6 class="font-weight-bold mb-0" style="color: var(--text-dark);">Historique des taux</h6>
                </div>
                <div class="table-responsive">
                    <table class="table mb-0" style="font-size: 14px;">
                        <thead style="background-color: #F9FAFB;">
                            <tr>
                                <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Taux</th>
                                <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Effet à partir du</th>
                                <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Jusqu'au</th>
                                <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                                <th class="border-0"></th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($rates as $rate)
                                <tr>
                                    <td class="py-3" style="font-weight: 700; color: var(--text-dark);">{{ $rate->rate }}%</td>
                                    <td class="py-3" style="color: var(--text-muted);">{{ $rate->effective_from?->format('d/m/Y') ?? '—' }}</td>
                                    <td class="py-3" style="color: var(--text-muted);">{{ $rate->effective_to?->format('d/m/Y') ?? 'En cours' }}</td>
                                    <td class="py-3">
                                        @if ($rate->is_active && $rate->effective_from?->isFuture())
                                            <span class="badge badge-pill" style="background-color: #FFF3E0; color: #E65100; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Programmé</span>
                                        @elseif ($rate->is_active)
                                            <span class="badge badge-pill" style="background-color: #E8F5E9; color: #2E7D32; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Actif</span>
                                        @else
                                            <span class="badge badge-pill" style="background-color: #ECEFF1; color: #37474F; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Clôturé</span>
                                        @endif
                                    </td>
                                    <td class="py-3 text-right">
                                        @if ($rate->is_active)
                                            <form method="POST" action="{{ route('admin.commissions.destroy', $rate) }}"
                                                  onsubmit="return confirm('Clôturer ce taux ? Les nouveaux taux ne s\'appliqueront plus.');">
                                                @csrf
                                                @method('DELETE')
                                                <button type="submit" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                                    <i class="ti ti-x"></i> Clôturer
                                                </button>
                                            </form>
                                        @endif
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="5" class="text-center py-4" style="color: var(--text-muted);">Aucun taux enregistré.</td>
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

        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-header bg-white" style="border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                <h6 class="font-weight-bold mb-0" style="color: var(--text-dark);">Taux particuliers par boutique</h6>
                <small class="text-muted">Prioritaire sur le taux global. Un taux laissé vide suit le taux vendeur global actuellement appliqué. Les changements prennent effet dès la prochaine vente.</small>
            </div>
            <div class="table-responsive">
                <table class="table mb-0" style="font-size: 14px;">
                    <thead style="background-color: #F9FAFB;"><tr><th class="border-0">Boutique</th><th class="border-0">Taux spécifique (%)</th><th class="border-0 text-right">Action</th></tr></thead>
                    <tbody>
                        @forelse ($vendors as $vendor)
                            <tr>
                                <td class="align-middle">{{ $vendor->business_name }}</td>
                                <td class="align-middle">
                                    <form id="vendor-rate-{{ $vendor->id }}" method="POST" action="{{ route('admin.commissions.vendors.update', $vendor) }}">
                                        @csrf
                                        @method('PUT')
                                    </form>
                                    <input form="vendor-rate-{{ $vendor->id }}" type="number" name="commission_exception_rate" min="0" max="100" class="form-control" style="max-width:140px" value="{{ $vendor->settings?->commission_exception_rate }}" placeholder="Global">
                                </td>
                                <td class="align-middle text-right"><button form="vendor-rate-{{ $vendor->id }}" class="btn btn-sm" style="background:var(--benin-green);color:#fff">Enregistrer</button></td>
                            </tr>
                        @empty
                            <tr><td colspan="3" class="text-center text-muted py-4">Aucune boutique enregistrée.</td></tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div class="col-md-4">
        <!-- Nouveau taux -->
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-1" style="color: var(--text-dark);">Commission vendeur globale</h6>
                <p class="mb-3" style="color: var(--text-muted); font-size: 12.5px;">Prélevée sur le sous-total de chaque vente. Taux actuellement appliqué : <strong>{{ $activeVendorRate }} %</strong>.</p>
                <form method="POST" action="{{ route('admin.commissions.store') }}">
                    @csrf
                    <div class="form-group mb-3">
                        <label for="rate" class="font-weight-600" style="color: var(--text-dark);">Taux de commission vendeur (%) *</label>
                        <input type="number" id="rate" name="rate" min="0" max="100" value="{{ old('rate') }}" class="form-control @error('rate') is-invalid @enderror" required>
                        @error('rate')<div class="invalid-feedback">{{ $message }}</div>@enderror
                    </div>
                    <div class="form-group mb-3">
                        <label for="effective_from" class="font-weight-600" style="color: var(--text-dark);">Appliquer à partir du</label>
                        <input type="datetime-local" id="effective_from" name="effective_from" value="{{ old('effective_from', \Carbon\Carbon::now()->format('Y-m-d\TH:i')) }}" class="form-control">
                        <small class="text-muted">Laissez la date actuelle pour une application immédiate.</small>
                    </div>
                    <div class="form-group mb-3">
                        <label for="notes" class="font-weight-600" style="color: var(--text-dark);">Notes</label>
                        <textarea id="notes" name="notes" rows="2" class="form-control">{{ old('notes') }}</textarea>
                    </div>
                    <button type="submit" class="btn btn-block" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-check"></i> Appliquer la commission vendeur
                    </button>
                </form>
            </div>
        </div>

        <!-- Frais et commissions configurables -->
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-1" style="color: var(--text-dark);">Commissions client, livreur et colis</h6>
                <p class="mb-3" style="color: var(--text-muted); font-size: 12.5px;">Les taux enregistrés s’appliquent immédiatement aux nouveaux devis, commandes et colis. Les commandes déjà créées gardent leur calcul.</p>
                <form method="POST" action="{{ route('admin.commissions.platform-settings') }}">
                    @csrf
                    @method('PUT')
                    <div class="form-group"><label for="service_fee_rate">Commission client (%)</label><input id="service_fee_rate" name="service_fee_rate" type="number" min="0" max="100" class="form-control" value="{{ old('service_fee_rate', $platformSettings['service_fee_rate']) }}" required><small class="text-muted">Calculée sur le sous-total produits, hors frais de livraison.</small></div>
                    <div class="form-group"><label for="delivery_commission_rate">Commission livreur (%)</label><input id="delivery_commission_rate" name="delivery_commission_rate" type="number" min="0" max="100" class="form-control" value="{{ old('delivery_commission_rate', $platformSettings['delivery_commission_rate']) }}" required><small class="text-muted">Prélevée sur les frais de livraison des commandes.</small></div>
                    <div class="form-group"><label for="parcel_commission_rate">Commission livreur colis (%)</label><input id="parcel_commission_rate" name="parcel_commission_rate" type="number" min="0" max="100" class="form-control" value="{{ old('parcel_commission_rate', $platformSettings['parcel_commission_rate']) }}" required><small class="text-muted">Prélevée sur les frais de livraison du colis, payée par le livreur.</small></div>
                    <div class="form-group"><label for="parcel_creation_fee">Frais de création de colis (F CFA)</label><input id="parcel_creation_fee" name="parcel_creation_fee" type="number" min="0" class="form-control" value="{{ old('parcel_creation_fee', $platformSettings['parcel_creation_fee']) }}" required><small class="text-muted">Montant fixe payé par le créateur du colis, en plus de la livraison. Ce n’est pas une commission.</small></div>
                    <div class="form-group"><label for="gateway_fee_basis_points">Frais passerelle absorbés (points de base)</label><input id="gateway_fee_basis_points" name="gateway_fee_basis_points" type="number" min="0" max="10000" class="form-control" value="{{ old('gateway_fee_basis_points', $platformSettings['gateway_fee_basis_points']) }}" required><small class="text-muted">100 points = 1 %; ce coût n’est pas ajouté au total client.</small></div>
                    <div class="form-group"><label for="minimum_payout">Retrait minimum (F CFA)</label><input id="minimum_payout" name="minimum_payout" type="number" min="0" class="form-control" value="{{ old('minimum_payout', $platformSettings['minimum_payout']) }}" required></div>
                    <button type="submit" class="btn btn-block" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;"><i class="ti ti-device-floppy"></i> Enregistrer les commissions</button>
                </form>
            </div>
        </div>

        <!-- Revenu mensuel -->
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body p-0">
                <div class="card-header" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                    <h6 class="font-weight-bold mb-0" style="color: var(--text-dark);">Revenu plateforme (12 derniers mois)</h6>
                </div>
                @if (count($monthlyRevenue) > 0)
                    <div class="table-responsive">
                        <table class="table mb-0" style="font-size: 14px;">
                            <tbody>
                                @foreach ($monthlyRevenue as $row)
                                    <tr>
                                        <td class="py-2 px-3" style="color: var(--text-muted);">{{ \Carbon\Carbon::createFromFormat('Y-m', $row->month)->translatedFormat('F Y') }}</td>
                                        <td class="py-2 px-3 text-right" style="font-weight: 600;">{{ \App\Support\AdminLabels::priceLabel((int) $row->total) }}</td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </table>
                    </div>
                @else
                    <div class="text-center py-4" style="color: var(--text-muted);">Aucun revenu.</div>
                @endif
            </div>
        </div>
    </div>
</div>
@endsection