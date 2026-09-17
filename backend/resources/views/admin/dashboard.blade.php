@extends('layouts.app')

@section('content')
<!-- begin page-title -->
<div class="row">
    <div class="col-md-12 m-b-30">
        <div class="d-block d-lg-flex flex-nowrap align-items-center">
            <div class="page-title mr-4 pr-4 border-right">
                <h1 style="color: var(--text-dark); font-weight: 700;">Dashboard</h1>
            </div>
            <div class="breadcrumb-bar align-items-center">
                <nav>
                    <ol class="breadcrumb p-0 m-b-0">
                        <li class="breadcrumb-item">
                            <a href="{{ route('admin.dashboard') }}"><i class="ti ti-home" style="color: var(--benin-green);"></i></a>
                        </li>
                        <li class="breadcrumb-item active" aria-current="page" style="color: var(--text-muted);">Dashboard</li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
</div>
<!-- end page-title -->

@php
    $kpiCards = [
        ['label' => 'Commandes aujourd’hui', 'value' => number_format($kpis['orders_today']['value']), 'icon' => 'ti-shopping-cart', 'bg' => '#E8F5E9', 'fg' => '#2E7D32'],
        ['label' => 'CA aujourd’hui', 'value' => \App\Support\AdminLabels::priceLabel($kpis['ca_today']['value']), 'icon' => 'ti-wallet', 'bg' => '#FFF3E0', 'fg' => '#E65100'],
        ['label' => 'Commandes ce mois', 'value' => number_format($kpis['orders_month']['value']), 'icon' => 'ti-shopping-cart', 'bg' => '#E1F5FE', 'fg' => '#0277BD'],
        ['label' => 'CA ce mois', 'value' => \App\Support\AdminLabels::priceLabel($kpis['ca_month']['value']), 'icon' => 'ti-wallet', 'bg' => '#E1F5FE', 'fg' => '#0277BD'],
        ['label' => 'Commissions ce mois', 'value' => \App\Support\AdminLabels::priceLabel($kpis['commissions_month']), 'icon' => 'ti-percentage', 'bg' => '#F3E5F5', 'fg' => '#6A1B9A'],
        ['label' => 'Vendeurs actifs', 'value' => number_format($kpis['active_vendors']), 'icon' => 'ti-briefcase', 'bg' => '#E8F5E9', 'fg' => '#2E7D32'],
        ['label' => 'Livreurs en ligne', 'value' => number_format($kpis['online_drivers']), 'icon' => 'ti-truck', 'bg' => '#E0F7FA', 'fg' => '#00838F'],
        ['label' => 'Remboursements en attente', 'value' => number_format($kpis['pending_refunds']), 'icon' => 'ti-refresh', 'bg' => '#FFEBEE', 'fg' => '#C62828'],
    ];
@endphp

<!-- begin KPI Cards -->
<div class="row">
    @foreach ($kpiCards as $kpi)
        <div class="col-md-6 col-xl-3">
            <div class="card card-statistics h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                <div class="card-body">
                    <div class="d-flex align-items-center justify-content-between">
                        <div>
                            <p class="mb-0 font-weight-bold text-muted" style="color: var(--text-muted) !important;">{{ $kpi['label'] }}</p>
                            <h3 class="mt-2 mb-0" style="color: var(--text-dark); font-weight: 700;">{{ $kpi['value'] }}</h3>
                            @if (isset($kpi['trend']))
                                <small class="font-weight-bold" style="color: {{ $kpi['trend'] >= 0 ? '#2E7D32' : '#C62828' }};">
                                    {{ $kpi['trend'] >= 0 ? '+' : '' }}{{ $kpi['trend'] }}% vs 7j précédents
                                </small>
                            @endif
                        </div>
                        <div class="icon-box rounded-circle d-flex align-items-center justify-content-center" style="background-color: {{ $kpi['bg'] }}; width: 50px; height: 50px;">
                            <i class="ti {{ $kpi['icon'] }}" style="color: {{ $kpi['fg'] }}; font-size: 24px;"></i>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    @endforeach
</div>

<!-- Tendance 7 jours (commandes + CA) -->
<div class="row mt-4">
    <div class="col-md-6">
        <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-header" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                <h6 class="card-title mb-0" style="color: var(--text-dark); font-weight: 700;">Tendance commandes (7 jours)</h6>
            </div>
            <div class="card-body">
                <div class="d-flex align-items-center justify-content-around text-center">
                    <div>
                        <p class="mb-1 text-muted">7 derniers jours</p>
                        <h4 class="mb-0" style="font-weight: 700;">{{ $kpis['orders_week']['value'] }}</h4>
                    </div>
                    <div>
                        <p class="mb-1 text-muted">7 jours précédents</p>
                        <h4 class="mb-0" style="font-weight: 700;">{{ $kpis['orders_week']['previous'] }}</h4>
                    </div>
                    <div>
                        <p class="mb-1 text-muted">Évolution</p>
                        <h4 class="mb-0" style="font-weight: 700; color: {{ $kpis['orders_trend'] !== null && $kpis['orders_trend'] >= 0 ? '#2E7D32' : '#C62828' }};">
                            {{ $kpis['orders_trend'] === null ? '—' : ($kpis['orders_trend'] >= 0 ? '+' : '').$kpis['orders_trend'].'%' }}
                        </h4>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class="col-md-6">
        <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-header" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                <h6 class="card-title mb-0" style="color: var(--text-dark); font-weight: 700;">Tendance CA (7 jours)</h6>
            </div>
            <div class="card-body">
                <div class="d-flex align-items-center justify-content-around text-center">
                    <div>
                        <p class="mb-1 text-muted">7 derniers jours</p>
                        <h4 class="mb-0" style="font-weight: 700;">{{ \App\Support\AdminLabels::priceLabel($kpis['ca_week']['value']) }}</h4>
                    </div>
                    <div>
                        <p class="mb-1 text-muted">7 jours précédents</p>
                        <h4 class="mb-0" style="font-weight: 700;">{{ \App\Support\AdminLabels::priceLabel($kpis['ca_week']['previous']) }}</h4>
                    </div>
                    <div>
                        <p class="mb-1 text-muted">Évolution</p>
                        <h4 class="mb-0" style="font-weight: 700; color: {{ $kpis['ca_trend'] !== null && $kpis['ca_trend'] >= 0 ? '#2E7D32' : '#C62828' }};">
                            {{ $kpis['ca_trend'] === null ? '—' : ($kpis['ca_trend'] >= 0 ? '+' : '').$kpis['ca_trend'].'%' }}
                        </h4>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Alertes + Dernières commandes -->
<div class="row mt-4">
    <div class="col-md-4">
        <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-header" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                <h6 class="card-title mb-0" style="color: var(--text-dark); font-weight: 700;">Alertes</h6>
            </div>
            <div class="card-body">
                <ul class="list-unstyled mb-0">
                    <li class="d-flex justify-content-between align-items-center py-2 border-bottom">
                        <span><i class="ti ti-briefcase mr-2" style="color: #E65100;"></i>Vendeurs à vérifier</span>
                        <a href="{{ route('admin.vendors.index', ['status' => 'pending_verification']) }}" class="font-weight-bold" style="color: var(--benin-green);">{{ $alerts['pending_vendors'] }}</a>
                    </li>
                    <li class="d-flex justify-content-between align-items-center py-2 border-bottom">
                        <span><i class="ti ti-headphone mr-2" style="color: #C62828;"></i>Réclamations ouvertes</span>
                        <a href="{{ route('admin.complaints.index') }}" class="font-weight-bold" style="color: var(--benin-green);">{{ $alerts['open_complaints'] }}</a>
                    </li>
                    <li class="d-flex justify-content-between align-items-center py-2 border-bottom">
                        <span><i class="ti ti-shopping-cart mr-2" style="color: #0277BD;"></i>Commandes à payer</span>
                        <a href="{{ route('admin.orders.index', ['status' => 'awaiting_payment']) }}" class="font-weight-bold" style="color: var(--benin-green);">{{ $alerts['awaiting_payment_orders'] }}</a>
                    </li>
                    <li class="d-flex justify-content-between align-items-center py-2">
                        <span><i class="ti ti-refresh mr-2" style="color: #E65100;"></i>Remboursements en attente</span>
                        <a href="{{ route('admin.refunds.index') }}" class="font-weight-bold" style="color: var(--benin-green);">{{ $alerts['pending_refunds'] }}</a>
                    </li>
                </ul>
            </div>
        </div>
    </div>
    <div class="col-md-8">
        <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-header d-flex justify-content-between align-items-center" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                <h6 class="card-title mb-0" style="color: var(--text-dark); font-weight: 700;">Dernières commandes</h6>
                <a href="{{ route('admin.orders.index') }}" style="color: var(--benin-green); font-weight: 600;">Tout voir</a>
            </div>
            <div class="card-body p-0">
                @if (count($latestOrders) > 0)
                    <div class="table-responsive">
                        <table class="table table-hover mb-0" style="font-size: 14px;">
                            <thead>
                                <tr style="color: var(--text-muted);">
                                    <th>Référence</th>
                                    <th>Client</th>
                                    <th>Boutique</th>
                                    <th>Total</th>
                                    <th>Statut</th>
                                </tr>
                            </thead>
                            <tbody>
                                @foreach ($latestOrders as $order)
                                    <tr>
                                        <td><a href="{{ route('admin.orders.show', $order) }}" style="color: var(--benin-green); font-weight: 600;">{{ $order->reference }}</a></td>
                                        <td>{{ $order->user?->name ?? '—' }}</td>
                                        <td>{{ $order->vendor?->business_name ?? '—' }}</td>
                                        <td>{{ \App\Support\AdminLabels::priceLabel($order->total) }}</td>
                                        <td>{!! \App\Support\AdminLabels::orderStatusBadge($order->status->value) !!}</td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </table>
                    </div>
                @else
                    <div class="text-center py-5" style="color: var(--text-muted);">
                        <i class="ti ti-shopping-cart" style="font-size: 32px;"></i>
                        <p class="mb-0 mt-2">Aucune commande enregistrée.</p>
                    </div>
                @endif
            </div>
        </div>
    </div>
</div>

<!-- begin Quick Actions -->
<div class="row mt-4">
    <div class="col-md-12">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-header" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                <h4 class="card-title" style="color: var(--text-dark); font-weight: 700; margin-bottom: 0;">Actions rapides</h4>
            </div>
            <div class="card-body">
                <div class="row">
                    <div class="col-md-3 col-sm-6 mb-3">
                        <a href="{{ route('admin.vendors.index') }}" class="btn btn-block" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500; padding: 12px;">
                            <i class="ti ti-briefcase"></i> Gérer les vendeurs
                        </a>
                    </div>
                    <div class="col-md-3 col-sm-6 mb-3">
                        <a href="{{ route('admin.orders.index') }}" class="btn btn-block" style="background-color: var(--benin-orange); color: #FFFFFF; border-radius: 8px; font-weight: 500; padding: 12px;">
                            <i class="ti ti-shopping-cart"></i> Voir les commandes
                        </a>
                    </div>
                    <div class="col-md-3 col-sm-6 mb-3">
                        <a href="{{ route('admin.complaints.index') }}" class="btn btn-block" style="background-color: #FFFFFF; color: var(--text-dark); border: 1px solid var(--border-color); border-radius: 8px; font-weight: 500; padding: 12px;">
                            <i class="ti ti-headphone" style="color: var(--benin-red);"></i> Réclamations
                        </a>
                    </div>
                    <div class="col-md-3 col-sm-6 mb-3">
                        <a href="{{ route('admin.settings.index') }}" class="btn btn-block" style="background-color: #FFFFFF; color: var(--text-dark); border: 1px solid var(--border-color); border-radius: 8px; font-weight: 500; padding: 12px;">
                            <i class="ti ti-settings" style="color: var(--text-muted);"></i> Paramètres
                        </a>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
<!-- end Quick Actions -->
@endsection