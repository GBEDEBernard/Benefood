@extends('layouts.app')

@section('content')
<x-admin.page-header title="Remboursement {{ $refund->order->reference }}" subtitle="Créé le {{ $refund->created_at?->format('d/m/Y H:i') ?? '—' }}" :back="route('admin.refunds.index')">
    {!! \App\Support\AdminLabels::refundStatusBadge($refund->status->value) !!}
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
    <div class="col-md-6">
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Détails</h6>
                <ul class="list-unstyled mb-0" style="font-size: 14px;">
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Commande</span>
                        <strong><a href="{{ route('admin.orders.show', $refund->order) }}" style="color: var(--benin-green);">{{ $refund->order->reference }}</a></strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Client</span><strong>{{ $refund->order->user?->name ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Boutique</span><strong>{{ $refund->order->vendor?->business_name ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Montant</span><strong style="color: var(--benin-green);">{{ \App\Support\AdminLabels::priceLabel($refund->amount) }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Raison</span><strong>{{ $refund->reason ?? '—' }}</strong></li>
                    @if ($refund->executed_at)
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Exécuté le</span><strong>{{ $refund->executed_at?->format('d/m/Y H:i') }}</strong></li>
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Par</span><strong>{{ $refund->executor?->name ?? '—' }}</strong></li>
                    @endif
                    @if ($refund->gateway_refund_id)
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Réf. passerelle</span><strong style="font-family: monospace;">{{ $refund->gateway_refund_id }}</strong></li>
                    @endif
                </ul>
            </div>
        </div>
    </div>

    <div class="col-md-6">
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Paiement d'origine</h6>
                @if ($refund->payment)
                    <ul class="list-unstyled mb-0" style="font-size: 14px;">
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Référence</span><strong style="font-family: monospace;">{{ $refund->payment->reference }}</strong></li>
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Passerelle</span><strong>{{ $refund->payment->gateway }}</strong></li>
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Txn ID</span><strong style="font-family: monospace;">{{ $refund->payment->gateway_txn_id ?? '—' }}</strong></li>
                        <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Statut</span><strong>{!! \App\Support\AdminLabels::paymentStatusBadge($refund->payment->status->value) !!}</strong></li>
                    </ul>
                @else
                    <p class="mb-0" style="color: var(--text-muted);">Aucun paiement associé.</p>
                @endif
            </div>
        </div>

        @if ($canExecute && $refund->status->value !== 'executed')
            <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px; border-left: 4px solid var(--benin-green);">
                <div class="card-body">
                    <h6 class="font-weight-bold mb-2" style="color: #2E7D32;">Exécution manuelle par la porteuse</h6>
                    <p style="color: var(--text-muted); font-size: 14px;">
                        Confirmer l'exécution : la passerelle est appelée si configurée (mode manuel = trace), le paiement et
                        la commande passent au statut « remboursé », et le client est notifié.
                    </p>
                    <form method="POST" action="{{ route('admin.refunds.execute', $refund) }}"
                          onsubmit="return confirm('Exécuter ce remboursement de {{ \App\Support\AdminLabels::priceLabel($refund->amount) }} ?');">
                        @csrf
                        <button type="submit" class="btn" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                            <i class="ti ti-check"></i> Exécuter le remboursement
                        </button>
                    </form>
                </div>
            </div>
        @endif
    </div>
</div>
@endsection