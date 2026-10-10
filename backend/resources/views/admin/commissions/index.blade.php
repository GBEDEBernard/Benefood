@extends('layouts.app')

@section('content')
<x-admin.page-header title="Commissions" subtitle="Phase 16 — Taux de commission et historique">
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
                                        @if ($rate->is_active)
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
    </div>

    <div class="col-md-4">
        <!-- Nouveau taux -->
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Nouveau taux</h6>
                <form method="POST" action="{{ route('admin.commissions.store') }}">
                    @csrf
                    <div class="form-group mb-3">
                        <label for="rate" class="font-weight-600" style="color: var(--text-dark);">Taux (%) *</label>
                        <input type="number" id="rate" name="rate" min="0" max="100" value="{{ old('rate') }}" class="form-control @error('rate') is-invalid @enderror" required>
                        @error('rate')<div class="invalid-feedback">{{ $message }}</div>@enderror
                    </div>
                    <div class="form-group mb-3">
                        <label for="effective_from" class="font-weight-600" style="color: var(--text-dark);">Effectif à partir du</label>
                        <input type="datetime-local" id="effective_from" name="effective_from" value="{{ old('effective_from', \Carbon\Carbon::now()->format('Y-m-d\TH:i')) }}" class="form-control">
                    </div>
                    <div class="form-group mb-3">
                        <label for="notes" class="font-weight-600" style="color: var(--text-dark);">Notes</label>
                        <textarea id="notes" name="notes" rows="2" class="form-control">{{ old('notes') }}</textarea>
                    </div>
                    <button type="submit" class="btn btn-block" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-plus"></i> Enregistrer le taux
                    </button>
                </form>
            </div>
        </div>

        <!-- Barème plateforme (cahier v1.0) -->
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-1" style="color: var(--text-dark);">Barème plateforme</h6>
                <p class="mb-3" style="color: var(--text-muted); font-size: 12.5px;">Répartition appliquée à chaque commande (figée par commande).</p>
                @php
                    $serviceFee = (int) config('beninfood.service_fee.rate', 5);
                    $deliveryCommission = (int) config('beninfood.delivery_commission.rate', 20);
                    $gatewayFee = ((int) config('beninfood.payment_gateway.fee_rate_basis_points', 120)) / 100;
                    $minPayout = (int) config('beninfood.wallet.min_payout', 1000);
                @endphp
                <ul class="list-unstyled mb-0" style="font-size: 14px;">
                    <li class="d-flex justify-content-between py-2" style="border-bottom: 1px solid var(--border-color);">
                        <span style="color: var(--text-muted);">Frais de service client</span>
                        <strong style="color: var(--text-dark);">{{ $serviceFee }} %</strong>
                    </li>
                    <li class="d-flex justify-content-between py-2" style="border-bottom: 1px solid var(--border-color);">
                        <span style="color: var(--text-muted);">Commission livreur</span>
                        <strong style="color: var(--text-dark);">{{ $deliveryCommission }} %</strong>
                    </li>
                    <li class="d-flex justify-content-between py-2" style="border-bottom: 1px solid var(--border-color);">
                        <span style="color: var(--text-muted);">Frais passerelle (absorbés)</span>
                        <strong style="color: var(--text-dark);">{{ rtrim(rtrim(number_format($gatewayFee, 2, ',', ''), '0'), ',') }} %</strong>
                    </li>
                    <li class="d-flex justify-content-between py-2">
                        <span style="color: var(--text-muted);">Retrait minimum</span>
                        <strong style="color: var(--text-dark);">{{ \App\Support\AdminLabels::priceLabel($minPayout) }}</strong>
                    </li>
                </ul>
                <p class="mt-3 mb-0" style="color: var(--text-muted); font-size: 12px;">
                    <i class="ti ti-info-circle"></i> Modifiable via la configuration serveur (variables <code>BENINFOOD_SERVICE_FEE_RATE</code>, <code>BENINFOOD_DELIVERY_COMMISSION_RATE</code>, <code>BENINFOOD_GATEWAY_FEE_BASIS_POINTS</code>).
                </p>
            </div>
        </div>

        <!-- Revenu mensuel -->
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body p-0">
                <div class="card-header" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                    <h6 class="font-weight-bold mb-0" style="color: var(--text-dark);">Revenu de commission (12 derniers mois)</h6>
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