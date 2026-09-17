@extends('layouts.app')

@section('content')
<x-admin.page-header title="Rapports & statistiques" subtitle="Phase 16 — Export CSV">
    <a href="{{ route('admin.dashboard') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
        <i class="ti ti-home"></i> Dashboard
    </a>
</x-admin.page-header>

<form method="GET" action="{{ route('admin.reports.index') }}">
    <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body py-3">
            <div class="row align-items-center">
                <div class="col-md-4">
                    <label class="mb-1" style="color: var(--text-muted); font-size: 13px;">Du</label>
                    <input type="date" name="from" value="{{ $filters['from'] }}" class="form-control">
                </div>
                <div class="col-md-4">
                    <label class="mb-1" style="color: var(--text-muted); font-size: 13px;">Au</label>
                    <input type="date" name="to" value="{{ $filters['to'] }}" class="form-control">
                </div>
                <div class="col-md-4 d-flex align-items-end">
                    <button type="submit" class="btn" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-calendar"></i> Mettre à jour la période
                    </button>
                </div>
            </div>
        </div>
    </div>
</form>

@php
    $exports = [
        ['label' => 'Commandes', 'desc' => 'Référence, client, boutique, totaux et statut sur la période.', 'route' => route('admin.reports.export.orders', ['from' => $filters['from'], 'to' => $filters['to']]), 'icon' => 'ti-shopping-cart'],
        ['label' => 'Commissions', 'desc' => 'Base, taux, commission perçue et répartition vendeur/livreur.', 'route' => route('admin.reports.export.commissions', ['from' => $filters['from'], 'to' => $filters['to']]), 'icon' => 'ti-wallet'],
        ['label' => 'Remboursements', 'desc' => 'Montants, motifs, statuts et références passerelle.', 'route' => route('admin.reports.export.refunds', ['from' => $filters['from'], 'to' => $filters['to']]), 'icon' => 'ti-refresh'],
    ];
@endphp

<div class="row">
    @foreach ($exports as $export)
        <div class="col-md-4">
            <div class="card mb-4 h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                <div class="card-body d-flex flex-column">
                    <div class="icon-box rounded-circle d-flex align-items-center justify-content-center mb-3" style="background-color: #E8F5E9; width: 48px; height: 48px;">
                        <i class="ti {{ $export['icon'] }}" style="color: var(--benin-green); font-size: 22px;"></i>
                    </div>
                    <h6 class="font-weight-bold mb-1" style="color: var(--text-dark);">{{ $export['label'] }}</h6>
                    <p class="mb-3" style="color: var(--text-muted); font-size: 13px;">{{ $export['desc'] }}</p>
                    <a href="{{ $export['route'] }}" class="btn btn-sm mt-auto" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-download"></i> Exporter CSV
                    </a>
                </div>
            </div>
        </div>
    @endforeach
</div>
@endsection