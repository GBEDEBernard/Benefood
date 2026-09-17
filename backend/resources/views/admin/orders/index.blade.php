@extends('layouts.app')

@section('content')
<x-admin.page-header title="Commandes" subtitle="Phase 16 — Suivi et annulation des commandes">
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
@if (session('error'))
    <div class="alert alert-danger alert-dismissible fade show" role="alert">
        {{ session('error') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif

<!-- Status tabs -->
@php
    $statusChips = [
        ['key' => '', 'label' => 'Toutes', 'count' => $counts['all'], 'fg' => 'var(--benin-green)'],
        ['key' => 'awaiting_payment', 'label' => 'À payer', 'count' => $counts['awaiting_payment'], 'fg' => 'var(--benin-orange)'],
        ['key' => 'in_progress', 'label' => 'En cours', 'count' => $counts['in_progress'], 'fg' => 'var(--text-dark)'],
        ['key' => 'delivered', 'label' => 'Livrées', 'count' => $counts['delivered'], 'fg' => 'var(--benin-green)'],
        ['key' => 'cancelled', 'label' => 'Annulées', 'count' => $counts['cancelled'], 'fg' => 'var(--benin-red)'],
    ];
@endphp
<div class="row mb-4">
    <div class="col-12">
        <ul class="nav" style="gap: 8px; flex-wrap: wrap; list-style: none; padding: 0; margin: 0;">
            @foreach ($statusChips as $chip)
                <li class="nav-item">
                    <a class="btn btn-sm"
                       href="{{ route('admin.orders.index', array_merge(['status' => $chip['key'] ?: null, 'q' => $filters['q'] ?? null])) }}"
                       style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === $chip['key'] ? 'background-color: '.$chip['fg'].'; color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                        {{ $chip['label'] }} <span class="ml-1" style="font-weight: 700;">{{ $chip['count'] }}</span>
                    </a>
                </li>
            @endforeach
        </ul>
    </div>
</div>

<!-- Filters -->
<form method="GET" action="{{ route('admin.orders.index') }}">
    @if (! empty($filters['status']))
        <input type="hidden" name="status" value="{{ $filters['status'] }}">
    @endif
    <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body py-3">
            <div class="row align-items-center">
                <div class="col-md-4">
                    <input type="text" name="q" value="{{ $filters['q'] ?? '' }}" class="form-control" placeholder="Référence, client, boutique...">
                </div>
                <div class="col-md-2">
                    <select name="vendor_id" class="form-control">
                        <option value="">Toutes les boutiques</option>
                        @foreach ($vendors as $vendor)
                            <option value="{{ $vendor->id }}" @selected(request('vendor_id') == $vendor->id)>{{ $vendor->business_name }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-2">
                    <input type="date" name="from" value="{{ $filters['from'] ?? '' }}" class="form-control" title="Du">
                </div>
                <div class="col-md-2">
                    <input type="date" name="to" value="{{ $filters['to'] ?? '' }}" class="form-control" title="Au">
                </div>
                <div class="col-md-2 d-flex">
                    <button type="submit" class="btn mr-2" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-search"></i>
                    </button>
                    <a href="{{ route('admin.orders.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                        Réinitialiser
                    </a>
                </div>
            </div>
        </div>
    </div>
</form>

<!-- Table -->
<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover mb-0">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Référence</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Client</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Boutique</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Total</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Paiement</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Date</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($orders as $order)
                        @php
                            $paymentBadge = $order->payment
                                ? \App\Support\AdminLabels::paymentStatusBadge($order->payment->status->value)
                                : '<span class="badge badge-pill" style="background:#ECEFF1;color:#37474F;">Non initié</span>';
                        @endphp
                        <tr>
                            <td class="py-3"><a href="{{ route('admin.orders.show', $order) }}" style="color: var(--benin-green); font-weight: 600; font-family: monospace;">{{ $order->reference }}</a></td>
                            <td class="py-3" style="color: var(--text-dark);">{{ $order->user?->name ?? '—' }}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $order->vendor?->business_name ?? '—' }}</td>
                            <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ \App\Support\AdminLabels::priceLabel($order->total) }}</td>
                            <td class="py-3">{!! $paymentBadge !!}</td>
                            <td class="py-3">{!! \App\Support\AdminLabels::orderStatusBadge($order->status->value) !!}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $order->created_at?->format('d/m/Y H:i') ?? '—' }}</td>
                            <td class="py-3 text-right">
                                <a href="{{ route('admin.orders.show', $order) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                    <i class="ti ti-eye"></i> Voir
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="8" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-shopping-cart" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucune commande trouvée.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($orders->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $orders->links() }}
        </div>
    @endif
</div>
@endsection