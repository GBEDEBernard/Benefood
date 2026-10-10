@extends('layouts.app')

@section('content')
<x-admin.page-header title="Colis {{ $parcel->reference }}" subtitle="Créé le {{ $parcel->created_at?->format('d/m/Y H:i') }}" :back="route('admin.parcels.index')">
    {!! \App\Support\AdminLabels::parcelStatusBadge($parcel->status->value) !!}
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

<div class="row">
    <!-- Infos générales -->
    <div class="col-md-4">
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Informations</h6>
                <ul class="list-unstyled mb-0" style="font-size: 14px;">
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Expéditeur</span><strong>{{ $parcel->user?->name ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Livreur</span><strong>{{ $parcel->driverProfile?->user?->name ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Description</span><strong>{{ $parcel->description ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Distance</span><strong>{{ $parcel->distance_km !== null ? number_format((float) $parcel->distance_km, 1).' km' : '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Frais de livraison</span><strong style="color: var(--benin-green);">{{ \App\Support\AdminLabels::priceLabel($parcel->delivery_fee) }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Paiement</span>
                        <strong>{{ $parcel->payment ? \App\Support\AdminLabels::paymentStatusBadge($parcel->payment->status->value) : '—' }}</strong>
                    </li>
                    @if ($parcel->delivered_at)
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Livré le</span><strong>{{ $parcel->delivered_at->format('d/m/Y H:i') }}</strong></li>
                    @endif
                    @if ($parcel->cancelled_at)
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Annulé le</span><strong>{{ $parcel->cancelled_at->format('d/m/Y H:i') }}</strong></li>
                    @endif
                </ul>
            </div>
        </div>

        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Éclatement financier</h6>
                <ul class="list-unstyled mb-0" style="font-size: 14px;">
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Part livreur (80 %)</span><strong>{{ \App\Support\AdminLabels::priceLabel($parcel->partner_amount) }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Commission plateforme ({{ $parcel->commission_rate }} %)</span><strong>{{ \App\Support\AdminLabels::priceLabel($parcel->platform_amount) }}</strong></li>
                </ul>
            </div>
        </div>
    </div>

    <div class="col-md-8">
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Trajet</h6>
                @php
                    $pickup = $parcel->pickup_snapshot ?? [];
                    $dropoff = $parcel->dropoff_snapshot ?? [];
                @endphp
                <div class="d-flex mb-2">
                    <div class="mr-3" style="width: 10px; height: 10px; border-radius: 50%; background-color: var(--benin-green); margin-top: 6px; flex-shrink: 0;"></div>
                    <div>
                        <div style="font-weight: 600; color: var(--text-dark);">Départ</div>
                        <small style="color: var(--text-muted);">{{ $pickup['label'] ?? ($pickup['address_text'] ?? '—') }}</small>
                        @if (! empty($pickup['city']))<br><small style="color: var(--text-muted);">{{ $pickup['city'] }}</small>@endif
                    </div>
                </div>
                <div class="d-flex">
                    <div class="mr-3" style="width: 10px; height: 10px; border-radius: 50%; background-color: var(--benin-red); margin-top: 6px; flex-shrink: 0;"></div>
                    <div>
                        <div style="font-weight: 600; color: var(--text-dark);">Arrivée</div>
                        <small style="color: var(--text-muted);">{{ $dropoff['label'] ?? ($dropoff['address_text'] ?? '—') }}</small>
                        @if (! empty($dropoff['city']))<br><small style="color: var(--text-muted);">{{ $dropoff['city'] }}</small>@endif
                    </div>
                </div>
            </div>
        </div>

        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Historique des statuts</h6>
                @forelse ($parcel->statusHistory->sortByDesc('created_at') as $history)
                    <div class="d-flex align-items-start mb-3">
                        <div class="mr-3" style="width: 10px; height: 10px; border-radius: 50%; background-color: var(--benin-green); margin-top: 6px;"></div>
                        <div>
                            <div style="font-weight: 600; color: var(--text-dark);">
                                {{ $history->from_status ?? '—' }} → {{ $history->to_status }}
                            </div>
                            <small style="color: var(--text-muted);">
                                {{ $history->created_at?->format('d/m/Y H:i') }}
                                @if ($history->reason) — {{ $history->reason }} @endif
                            </small>
                        </div>
                    </div>
                @empty
                    <p class="mb-0" style="color: var(--text-muted);">Aucun historique.</p>
                @endforelse
            </div>
        </div>

        <!-- Annulation (action autorisée porteuse) -->
        @if (! in_array($parcel->status->value, ['delivered', 'cancelled', 'refunded'], true))
            <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px; border-left: 4px solid var(--benin-red);">
                <div class="card-body">
                    <h6 class="font-weight-bold mb-2" style="color: #C62828;">Annulation par la porteuse</h6>
                    <p style="color: var(--text-muted); font-size: 14px;">
                        L'annulation est définitive. Un motif est obligatoire (journal d'audit).
                    </p>
                    <form method="POST" action="{{ route('admin.parcels.cancel', $parcel) }}" onsubmit="return confirm('Confirmer l\'annulation de ce colis ?');">
                        @csrf
                        <div class="form-group mb-2">
                            <textarea name="reason" rows="2" class="form-control" placeholder="Motif obligatoire de l'annulation" required minlength="3"></textarea>
                        </div>
                        <button type="submit" class="btn btn-sm" style="background-color: var(--benin-red); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                            <i class="ti ti-x"></i> Annuler le colis
                        </button>
                    </form>
                </div>
            </div>
        @endif
    </div>
</div>
@endsection