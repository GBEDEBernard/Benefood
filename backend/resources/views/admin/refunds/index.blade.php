@extends('layouts.app')

@section('content')
<x-admin.page-header title="Remboursements" subtitle="Phase 16 — Suivi et exécution manuelle">
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

@php
    $statusChips = [
        ['key' => '', 'label' => 'Tous', 'count' => $counts['all'], 'fg' => 'var(--benin-green)'],
        ['key' => 'pending', 'label' => 'En attente', 'count' => $counts['pending'], 'fg' => 'var(--benin-orange)'],
        ['key' => 'executed', 'label' => 'Exécutés', 'count' => $counts['executed'], 'fg' => 'var(--benin-green)'],
        ['key' => 'failed', 'label' => 'Échoués', 'count' => $counts['failed'], 'fg' => 'var(--benin-red)'],
    ];
@endphp
<div class="row mb-4">
    <div class="col-12">
        <ul class="nav" style="gap: 8px; flex-wrap: wrap; list-style: none; padding: 0; margin: 0;">
            @foreach ($statusChips as $chip)
                <li class="nav-item">
                    <a class="btn btn-sm"
                       href="{{ route('admin.refunds.index', array_merge(['status' => $chip['key'] ?: null, 'q' => $filters['q'] ?? null])) }}"
                       style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === $chip['key'] ? 'background-color: '.$chip['fg'].'; color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                        {{ $chip['label'] }} <span class="ml-1" style="font-weight: 700;">{{ $chip['count'] }}</span>
                    </a>
                </li>
            @endforeach
        </ul>
    </div>
</div>

<form method="GET" action="{{ route('admin.refunds.index') }}">
    @if (! empty($filters['status']))
        <input type="hidden" name="status" value="{{ $filters['status'] }}">
    @endif
    <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body py-3">
            <div class="row align-items-center">
                <div class="col-md-8">
                    <input type="text" name="q" value="{{ $filters['q'] ?? '' }}" class="form-control" placeholder="Rechercher par référence de commande ou client...">
                </div>
                <div class="col-md-4 d-flex">
                    <button type="submit" class="btn mr-2" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-search"></i> Filtrer
                    </button>
                    <a href="{{ route('admin.refunds.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                        Réinitialiser
                    </a>
                </div>
            </div>
        </div>
    </div>
</form>

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover mb-0">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Commande</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Client</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Montant</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Créé le</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($refunds as $refund)
                        <tr>
                            <td class="py-3"><a href="{{ route('admin.orders.show', $refund->order) }}" style="color: var(--benin-green); font-weight: 600; font-family: monospace;">{{ $refund->order->reference }}</a></td>
                            <td class="py-3" style="color: var(--text-dark);">{{ $refund->order->user?->name ?? '—' }}</td>
                            <td class="py-3" style="font-weight: 600;">{{ \App\Support\AdminLabels::priceLabel($refund->amount) }}</td>
                            <td class="py-3">{!! \App\Support\AdminLabels::refundStatusBadge($refund->status->value) !!}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $refund->created_at?->format('d/m/Y H:i') ?? '—' }}</td>
                            <td class="py-3 text-right">
                                <a href="{{ route('admin.refunds.show', $refund) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                    <i class="ti ti-eye"></i> Voir
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-refresh" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucun remboursement trouvé.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($refunds->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $refunds->links() }}
        </div>
    @endif
</div>
@endsection