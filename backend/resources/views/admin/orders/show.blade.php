@extends('layouts.app')

@section('content')
<x-admin.page-header title="Commande {{ $order->reference }}" subtitle="Créée le {{ $order->created_at?->format('d/m/Y H:i') }}" :back="route('admin.orders.index')">
    {!! \App\Support\AdminLabels::orderStatusBadge($order->status->value) !!}
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
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Client</span><strong>{{ $order->user?->name ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Boutique</span><strong>{{ $order->vendor?->business_name ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Zone</span><strong>{{ $order->zone?->name ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Paiement</span>
                        <strong>{{ $order->payment ? \App\Support\AdminLabels::paymentStatusBadge($order->payment->status->value) : '—' }}</strong>
                    </li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Total</span><strong style="color: var(--benin-green);">{{ \App\Support\AdminLabels::priceLabel($order->total) }}</strong></li>
                    @if ($order->delivered_at)
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Livrée le</span><strong>{{ $order->delivered_at->format('d/m/Y H:i') }}</strong></li>
                    @endif
                    @if ($order->cancelled_at)
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Annulée le</span><strong>{{ $order->cancelled_at->format('d/m/Y H:i') }}</strong></li>
                    @endif
                </ul>
            </div>
        </div>

        @if ($order->address_snapshot)
            <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                <div class="card-body">
                    <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Adresse de livraison</h6>
                    <p class="mb-0" style="color: var(--text-muted); font-size: 14px;">
                        {{ data_get($order->address_snapshot, 'label') ?? data_get($order->address_snapshot, 'street') ?? 'Adresse' }}<br>
                        {{ $order->address_snapshot['city'] ?? '' }}
                    </p>
                </div>
            </div>
        @endif

        @if ($order->financials)
            <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                <div class="card-body">
                    <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Éclatement financier</h6>
                    <ul class="list-unstyled mb-0" style="font-size: 14px;">
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Base commission</span><strong>{{ \App\Support\AdminLabels::priceLabel($order->financials->commission_base) }}</strong></li>
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Taux commission</span><strong>{{ $order->financials->commission_rate }}%</strong></li>
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Commission plateforme</span><strong>{{ \App\Support\AdminLabels::priceLabel($order->financials->commission_amount) }}</strong></li>
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Montant vendeur</span><strong>{{ \App\Support\AdminLabels::priceLabel($order->financials->vendor_amount) }}</strong></li>
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Part livreur</span><strong>{{ \App\Support\AdminLabels::priceLabel($order->financials->delivery_partner_amount) }}</strong></li>
                    </ul>
                </div>
            </div>
        @endif
    </div>

    <!-- Articles + Historique -->
    <div class="col-md-8">
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body p-0">
                <div class="card-header" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                    <h6 class="font-weight-bold mb-0" style="color: var(--text-dark);">Articles</h6>
                </div>
                <div class="table-responsive">
                    <table class="table mb-0" style="font-size: 14px;">
                        <thead style="background-color: #F9FAFB;">
                            <tr>
                                <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Produit</th>
                                <th class="border-0 text-center" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Qté</th>
                                <th class="border-0 text-right" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">PU</th>
                                <th class="border-0 text-right" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Sous-total</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($order->items as $item)
                                <tr>
                                    <td>{{ $item->name_snapshot }}</td>
                                    <td class="text-center">{{ $item->quantity }}</td>
                                    <td class="text-right">{{ \App\Support\AdminLabels::priceLabel($item->unit_price_snapshot) }}</td>
                                    <td class="text-right" style="font-weight: 600;">{{ \App\Support\AdminLabels::priceLabel($item->subtotal) }}</td>
                                </tr>
                            @endforeach
                            <tr>
                                <td colspan="3" class="text-right" style="color: var(--text-muted);">Sous-total</td>
                                <td class="text-right">{{ \App\Support\AdminLabels::priceLabel($order->subtotal) }}</td>
                            </tr>
                            <tr>
                                <td colspan="3" class="text-right" style="color: var(--text-muted);">Livraison</td>
                                <td class="text-right">{{ \App\Support\AdminLabels::priceLabel($order->delivery_fee) }}</td>
                            </tr>
                            <tr>
                                <td colspan="3" class="text-right" style="color: var(--text-muted);">Remise</td>
                                <td class="text-right">-{{ \App\Support\AdminLabels::priceLabel($order->discount) }}</td>
                            </tr>
                            <tr>
                                <td colspan="3" class="text-right font-weight-bold" style="color: var(--text-dark);">Total</td>
                                <td class="text-right font-weight-bold" style="color: var(--benin-green);">{{ \App\Support\AdminLabels::priceLabel($order->total) }}</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Historique des statuts</h6>
                @forelse ($order->statusHistory->sortByDesc('created_at') as $history)
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
        @if ($canCancel && ! in_array($order->status->value, ['cancelled', 'refunded'], true))
            <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px; border-left: 4px solid var(--benin-red);">
                <div class="card-body">
                    <h6 class="font-weight-bold mb-2" style="color: #C62828;">Annulation par la porteuse</h6>
                    <p style="color: var(--text-muted); font-size: 14px;">
                        L'annulation est définitive : le stock est restitué et un remboursement est planifié si la commande est payée.
                        Un motif est obligatoire (journal d'audit).
                    </p>
                    <form method="POST" action="{{ route('admin.orders.cancel', $order) }}" onsubmit="return confirm('Confirmer l\'annulation de cette commande ?');">
                        @csrf
                        <input type="hidden" name="refund_amount" value="{{ $order->payment && $order->payment->status->value === 'confirmed' ? $order->total : '' }}">
                        <div class="form-group mb-2">
                            <textarea name="reason" rows="2" class="form-control" placeholder="Motif obligatoire de l'annulation" required minlength="3"></textarea>
                        </div>
                        <button type="submit" class="btn btn-sm" style="background-color: var(--benin-red); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                            <i class="ti ti-x"></i> Annuler la commande
                        </button>
                    </form>
                </div>
            </div>
        @endif
    </div>
</div>
@endsection