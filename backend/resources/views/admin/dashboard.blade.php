@extends('layouts.app')

@section('content')
<style>
    .bf-dashboard{--bf-ink:#26332f;--bf-muted:#78817e;--bf-border:#e5e9e7;--bf-green:#087b46;--bf-orange:#ff8c00;--bf-blue:#2f6fed;--bf-purple:#7d4ce0;color:var(--bf-ink);font-family:Roboto,sans-serif}
    .bf-dashboard-heading{display:flex;align-items:center;justify-content:space-between;gap:20px;margin:0 0 18px}
    .bf-dashboard-heading h1{font-size:25px;line-height:1.2;font-weight:700;margin:3px 0 5px;color:var(--bf-ink)!important;letter-spacing:-.45px}
    .bf-dashboard-heading p{margin:0;color:var(--bf-muted);font-size:12px;line-height:1.5}
    .bf-eyebrow{font-size:9px;letter-spacing:1.35px;font-weight:800;color:var(--bf-green)}
    .bf-date-filter{display:flex;align-items:center;gap:8px;padding:5px 9px;border:1px solid var(--bf-border);border-radius:9px;background:#fff;box-shadow:0 2px 7px rgba(29,48,75,.035)}
    .bf-date-filter>i{color:var(--bf-green);font-size:15px}.bf-date-filter span{color:#a5aebb;font-size:11px}
    .bf-date-filter input{border:0;background:transparent;color:#4c5868;font-size:10px;width:108px;outline:none}.bf-date-filter button{border:0;background:#eef8f0;color:var(--bf-green);border-radius:6px;width:27px;height:27px;cursor:pointer}
    .bf-kpis{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:10px;margin-bottom:12px}
    .bf-kpi-card,.bf-panel{background:#fff;border:1px solid var(--bf-border);border-radius:11px;box-shadow:0 2px 8px rgba(23,45,71,.035);min-width:0}
    .bf-kpi-card{min-height:88px;padding:14px 13px;display:flex;align-items:center;justify-content:space-between;gap:8px}
    .bf-kpi-copy{min-width:0;display:flex;flex-direction:column}.bf-kpi-label{font-size:9px;text-transform:uppercase;letter-spacing:.22px;font-weight:700;color:#647184;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .bf-kpi-value{font-size:18px;line-height:1.3;margin:7px 0 4px;letter-spacing:-.45px;color:var(--bf-ink);white-space:nowrap}.bf-kpi-foot{font-size:9px;color:var(--bf-green);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bf-kpi-foot i{font-size:9px}
    .bf-kpi-icon{width:33px;height:33px;border-radius:9px;display:flex;align-items:center;justify-content:center;flex:none;font-size:16px}.bf-kpi-icon.green{background:#e8f5eb;color:var(--bf-green)}.bf-kpi-icon.blue{background:#eaf3ff;color:var(--bf-blue)}.bf-kpi-icon.purple{background:#f2ecff;color:var(--bf-purple)}.bf-kpi-icon.orange{background:#fff1e4;color:var(--bf-orange)}
    .bf-grid{display:grid;gap:10px;margin-bottom:12px}.bf-grid-top{grid-template-columns:1.55fr 1fr 1.22fr}.bf-grid-leaderboards{grid-template-columns:repeat(3,minmax(0,1fr))}.bf-grid-bottom{grid-template-columns:1.2fr 1fr 1fr .9fr}
    .bf-panel{padding:14px 14px 12px}.bf-panel-head{display:flex;align-items:flex-start;justify-content:space-between;gap:8px;margin-bottom:8px;min-height:31px}.bf-panel-head h2{font-size:11px;line-height:1.4;font-weight:700;margin:0;color:#243043!important}.bf-panel-head p{font-size:9px;margin:3px 0 0;color:#929cab;line-height:1.3}.bf-panel-head>a{font-size:9px;white-space:nowrap;color:var(--bf-green);font-weight:700}.bf-panel-head>a i{font-size:9px;margin-left:2px}.bf-chart-unit{font-size:8px;color:#737f8f;background:#f7f9fb;padding:4px 7px;border:1px solid #edf0f3;border-radius:5px;white-space:nowrap}
    .bf-chart-area{height:154px;position:relative}.bf-panel-commission .bf-chart-area{height:158px}.bf-chart-bar{height:146px}
    .bf-donut-layout{display:flex;align-items:center;justify-content:center;gap:12px;min-height:150px}.bf-donut-wrap{width:135px;height:135px;position:relative;flex:none}.bf-donut-wrap canvas{position:relative;z-index:1}.bf-donut-center{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);z-index:2;pointer-events:none;text-align:center;width:74px}.bf-donut-center strong{display:block;font-size:11px;line-height:1.25;color:#273346;white-space:nowrap}.bf-donut-center span{display:block;margin-top:3px;font-size:8px;color:#8993a0;white-space:nowrap}.bf-legend-list{display:flex;flex-direction:column;gap:10px;min-width:0;flex:1}.bf-legend-list>div{display:grid;grid-template-columns:8px minmax(0,1fr);align-items:center;column-gap:6px;row-gap:2px;font-size:9px;color:#697586}.bf-legend-list b{grid-column:2;font-size:9px;color:#344053;white-space:nowrap}.bf-dot{width:7px;height:7px;border-radius:50%;background:#aaa}.bf-dot.green{background:var(--bf-green)}.bf-dot.orange{background:var(--bf-orange)}.bf-dot.blue{background:var(--bf-blue)}
    .bf-table-panel{padding-bottom:4px}.bf-table-panel .bf-panel-head{align-items:center;min-height:23px;margin-bottom:7px}.bf-table-scroll{width:100%;overflow-x:auto}.bf-table{width:100%;border-collapse:collapse;font-size:9px;white-space:nowrap}.bf-table thead th{padding:7px 5px;text-align:left;text-transform:uppercase;font-size:8px;letter-spacing:.25px;color:#8791a0;background:#f8fafb;border:0;border-bottom:1px solid var(--bf-border)}.bf-table tbody td{padding:8px 5px;border:0;border-bottom:1px solid #f0f2f5;color:#586476;vertical-align:middle}.bf-table tbody tr:last-child td{border-bottom:0}.bf-table tbody td strong{font-size:9px;color:#3c4758;font-weight:600}.bf-table-avatar{display:inline-flex;width:20px;height:20px;border-radius:6px;align-items:center;justify-content:center;margin-right:5px;font-size:10px;vertical-align:middle}.bf-table-avatar.green{background:#e9f5ec;color:var(--bf-green)}.bf-table-avatar.blue{background:#edf4ff;color:var(--bf-blue)}.bf-table-avatar.orange{background:#fff2e6;color:var(--bf-orange)}.bf-share{color:var(--bf-green);font-weight:700}.bf-empty{text-align:center!important;color:#929cab!important;padding:19px 6px!important}
    .bf-panel-bottom-donut .bf-donut-layout-small{gap:6px;min-height:145px}.bf-panel-bottom-donut .bf-donut-wrap{width:120px;height:120px}.bf-panel-bottom-donut .bf-legend-list{gap:8px}.bf-panel-bottom-donut .bf-legend-list>div{font-size:8px}.bf-panel-bottom-donut .bf-legend-list b{font-size:8px}.bf-panel-growth{display:flex;flex-direction:column}.bf-growth-stat{display:flex;align-items:baseline;gap:7px;padding:8px 1px 4px}.bf-growth-stat strong{font-size:26px;letter-spacing:-1px;color:#253245}.bf-growth-stat span{font-size:9px;color:#8c96a4}.bf-mini-bars{height:85px;display:flex;align-items:flex-end;gap:5px;padding:8px 3px 0;border-bottom:1px solid #edf0f3}.bf-mini-bars span{flex:1;min-width:3px;border-radius:3px 3px 0 0;background:linear-gradient(180deg,#34a45b,#b6e0c3);opacity:.92}.bf-growth-foot{display:flex;justify-content:space-between;gap:5px;margin-top:auto;padding-top:9px;font-size:8px;color:#8a94a1}.bf-orders-panel{padding-bottom:5px}.bf-orders-panel .bf-table{font-size:10px}.bf-orders-panel .bf-table thead th{padding:9px}.bf-orders-panel .bf-table tbody td{padding:9px}.bf-order-ref{font-weight:700;color:var(--bf-green)}
    .bf-dashboard .badge{font-size:8px;padding:5px 8px;border-radius:20px}
    @media(max-width:1500px){.bf-kpis{grid-template-columns:repeat(3,minmax(0,1fr))}.bf-grid-top{grid-template-columns:1.4fr 1fr}.bf-panel-distribution{grid-column:span 2}.bf-grid-bottom{grid-template-columns:repeat(2,minmax(0,1fr))}}
    @media(max-width:1000px){.bf-grid-top,.bf-grid-leaderboards{grid-template-columns:repeat(2,minmax(0,1fr))}.bf-panel-distribution{grid-column:auto}.bf-grid-leaderboards .bf-panel:last-child{grid-column:span 2}}
    @media(max-width:767px){.bf-top-search{display:none}}
    @media(max-width:680px){.bf-dashboard-heading{align-items:flex-start;flex-direction:column}.bf-date-filter{width:100%;justify-content:space-between}.bf-date-filter input{width:calc(50% - 35px)}.bf-kpis{grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.bf-kpi-card{padding:11px 9px;min-height:82px}.bf-kpi-value{font-size:14px}.bf-kpi-label{font-size:8px}.bf-grid-top,.bf-grid-leaderboards,.bf-grid-bottom{grid-template-columns:1fr}.bf-grid-leaderboards .bf-panel:last-child{grid-column:auto}.bf-panel-distribution{grid-column:auto}.bf-panel{padding:12px}.bf-panel-commission .bf-chart-area{height:180px}.bf-donut-layout{justify-content:flex-start}.bf-panel-bottom-donut .bf-donut-layout-small{justify-content:flex-start}.bf-dashboard-heading h1{font-size:22px}}
    .bf-dashboard .bf-eyebrow,.bf-dashboard .bf-panel-head>a,.bf-dashboard .bf-share,.bf-dashboard .bf-order-ref{color:var(--bf-orange)}
    .bf-dashboard .bf-panel-head>a:hover{color:#d97700}
    .bf-dashboard .bf-mini-bars span{background:linear-gradient(180deg,#ffa63d,#ffe0bd)}
    .bf-dashboard .bf-table .bf-avatar,.bf-dashboard .bf-table .bf-product-thumb{width:22px;height:22px;min-width:22px;margin-right:5px;border-radius:6px;font-size:8px}
    .bf-dashboard .bf-table .bf-avatar__status{display:none}
    .bf-inline-person{display:inline-flex;align-items:center;gap:5px;min-width:0}
</style>
@php
    $money = fn ($amount) => number_format((int) $amount, 0, ',', ' ').' FCFA';
    $number = fn ($amount) => number_format((int) $amount, 0, ',', ' ');
    $commissionTotal = array_sum($chartData['commission_split']);
    $revenueDistributionTotal = array_sum($chartData['revenue_split']);
    $statusColors = ['#087b46', '#ff8c00', '#2f6fed', '#d64545', '#9aa4b2', '#7d4ce0'];
    $statusLabels = array_column($chartData['order_statuses'], 'label');
    $statusValues = array_column($chartData['order_statuses'], 'value');
    $paymentLabels = array_column($chartData['payment_methods'], 'label');
    $paymentValues = array_column($chartData['payment_methods'], 'value');
@endphp

<div class="bf-dashboard">
    <div class="bf-dashboard-heading">
        <div>
            <div class="bf-eyebrow">BÉNINFOOD · VUE D’ENSEMBLE</div>
            <h1>Tableau de bord <span aria-hidden="true">👋</span></h1>
            <p>Bienvenue sur l’administration Béninfood. Voici un aperçu de votre plateforme.</p>
        </div>
        <form class="bf-date-filter" method="GET" action="{{ route('admin.dashboard') }}">
            <i class="ti ti-calendar"></i>
            <label class="sr-only" for="dashboard-from">Du</label>
            <input id="dashboard-from" type="date" name="from" value="{{ $period['from'] }}">
            <span>—</span>
            <label class="sr-only" for="dashboard-to">Au</label>
            <input id="dashboard-to" type="date" name="to" value="{{ $period['to'] }}">
            <button type="submit" aria-label="Appliquer la période"><i class="ti ti-arrow-right"></i></button>
        </form>
    </div>

    @if ($errors->any())
        <div class="alert alert-danger mb-3">{{ $errors->first() }}</div>
    @endif

    <section class="bf-kpis" aria-label="Indicateurs clés">
        @php
            $kpiCards = [
                ['label' => 'Chiffre d’affaires', 'value' => $money($kpis['ca_month']['value']), 'trend' => 'Période sélectionnée', 'icon' => 'ti-wallet', 'tone' => 'green'],
                ['label' => 'Montant total traité', 'value' => $money($kpis['ca_month']['value']), 'trend' => $number($kpis['orders_month']['value']).' commandes', 'icon' => 'ti-exchange-vertical', 'tone' => 'blue'],
                ['label' => 'Revenus plateforme', 'value' => $money($kpis['commissions_month']), 'trend' => 'Commissions et frais', 'icon' => 'ti-tag', 'tone' => 'purple'],
                ['label' => 'Commandes totales', 'value' => $number($kpis['orders_month']['value']), 'trend' => 'Sur la période', 'icon' => 'ti-shopping-cart', 'tone' => 'green'],
                ['label' => 'Utilisateurs inscrits', 'value' => $number($users), 'trend' => 'Comptes enregistrés', 'icon' => 'ti-user', 'tone' => 'blue'],
                ['label' => 'Livreurs actifs', 'value' => $number($kpis['online_drivers']), 'trend' => 'En ligne maintenant', 'icon' => 'ti-truck', 'tone' => 'orange'],
            ];
        @endphp
        @foreach ($kpiCards as $card)
            <article class="bf-kpi-card">
                <div class="bf-kpi-copy">
                    <span class="bf-kpi-label">{{ $card['label'] }}</span>
                    <strong class="bf-kpi-value">{{ $card['value'] }}</strong>
                    <span class="bf-kpi-foot"><i class="ti ti-arrow-up"></i> {{ $card['trend'] }}</span>
                </div>
                <span class="bf-kpi-icon {{ $card['tone'] }}"><i class="ti {{ $card['icon'] }}"></i></span>
            </article>
        @endforeach
    </section>

    <section class="bf-grid bf-grid-top" aria-label="Tendances et répartitions">
        <article class="bf-panel bf-panel-commission">
            <div class="bf-panel-head">
                <div><h2>Évolution des revenus plateforme</h2><p>Commissions et frais de création cumulés</p></div>
                <span class="bf-chart-unit">FCFA</span>
            </div>
            <div class="bf-chart-area"><canvas id="commissionTrendChart" aria-label="Évolution des commissions par jour"></canvas></div>
        </article>

        <article class="bf-panel bf-panel-donut">
            <div class="bf-panel-head"><div><h2>Revenus par service</h2><p>Commandes, colis et frais de création</p></div></div>
            <div class="bf-donut-layout">
                <div class="bf-donut-wrap"><canvas id="commissionSplitChart" aria-label="Revenus par service"></canvas><div class="bf-donut-center"><strong>{{ $money($commissionTotal) }}</strong><span>Total période</span></div></div>
                <div class="bf-legend-list">
                    <div><i class="bf-dot green"></i><span>Commandes</span><b>{{ $money($chartData['commission_split'][0]) }}</b></div>
                    <div><i class="bf-dot orange"></i><span>Colis + frais</span><b>{{ $money($chartData['commission_split'][1]) }}</b></div>
                </div>
            </div>
        </article>

        <article class="bf-panel bf-panel-donut bf-panel-distribution">
            <div class="bf-panel-head"><div><h2>Répartition des revenus</h2><p>Montants nets distribués</p></div></div>
            <div class="bf-donut-layout">
                <div class="bf-donut-wrap"><canvas id="revenueSplitChart" aria-label="Répartition des montants par bénéficiaire"></canvas><div class="bf-donut-center"><strong>{{ $money($revenueDistributionTotal) }}</strong><span>Total période</span></div></div>
                <div class="bf-legend-list">
                    <div><i class="bf-dot green"></i><span>Boutiques</span><b>{{ $money($chartData['revenue_split'][0]) }}</b></div>
                    <div><i class="bf-dot orange"></i><span>Livreurs</span><b>{{ $money($chartData['revenue_split'][1]) }}</b></div>
                    <div><i class="bf-dot blue"></i><span>Plateforme</span><b>{{ $money($chartData['revenue_split'][2]) }}</b></div>
                </div>
            </div>
        </article>
    </section>

    <section class="bf-grid bf-grid-leaderboards" aria-label="Meilleurs contributeurs">
        <article class="bf-panel bf-table-panel">
            <div class="bf-panel-head"><h2>Chiffre d’affaires par boutique</h2><a href="{{ route('admin.vendors.index') }}">Voir tout <i class="ti ti-arrow-right"></i></a></div>
            <div class="bf-table-scroll"><table class="bf-table"><thead><tr><th>Boutique</th><th>CA (FCFA)</th><th>Commandes</th><th>Part</th></tr></thead><tbody>
                @forelse ($leaderboards['vendors'] as $vendor)
                    <tr><td><span class="bf-inline-person"><x-admin.vendor-logo :vendor="$vendor" size="sm" /><strong>{{ $vendor->business_name }}</strong></span></td><td>{{ $money($vendor->revenue) }}</td><td>{{ $number($vendor->orders_count) }}</td><td><span class="bf-share">{{ number_format(((int) $vendor->revenue / max((int) $kpis['ca_month']['value'], 1)) * 100, 1, ',', ' ') }}%</span></td></tr>
                @empty
                    <tr><td colspan="4" class="bf-empty">Aucune vente sur cette période.</td></tr>
                @endforelse
            </tbody></table></div>
        </article>

        <article class="bf-panel bf-table-panel">
            <div class="bf-panel-head"><h2>Chiffre d’affaires par client</h2><a href="{{ route('admin.clients.index') }}">Voir tout <i class="ti ti-arrow-right"></i></a></div>
            <div class="bf-table-scroll"><table class="bf-table"><thead><tr><th>Client</th><th>Dépense totale</th><th>Commandes</th></tr></thead><tbody>
                @forelse ($leaderboards['clients'] as $client)
                    <tr><td><span class="bf-inline-person"><x-admin.avatar :user="$client" size="sm" /><strong>{{ $client->name }}</strong></span></td><td>{{ $money($client->revenue) }}</td><td>{{ $number($client->orders_count) }}</td></tr>
                @empty
                    <tr><td colspan="3" class="bf-empty">Aucune commande payée sur cette période.</td></tr>
                @endforelse
            </tbody></table></div>
        </article>

        <article class="bf-panel bf-table-panel">
            <div class="bf-panel-head"><h2>Revenus par livreur</h2><a href="{{ route('admin.drivers.index') }}">Voir tout <i class="ti ti-arrow-right"></i></a></div>
            <div class="bf-table-scroll"><table class="bf-table"><thead><tr><th>Livreur</th><th>Part livreur</th><th>Courses</th></tr></thead><tbody>
                @forelse ($leaderboards['drivers'] as $driver)
                    <tr><td><span class="bf-inline-person"><x-admin.avatar :user="$driver" size="sm" /><strong>{{ $driver->name }}</strong></span></td><td>{{ $money($driver->revenue) }}</td><td>{{ $number($driver->deliveries_count) }}</td></tr>
                @empty
                    <tr><td colspan="3" class="bf-empty">Aucune course terminée sur cette période.</td></tr>
                @endforelse
            </tbody></table></div>
        </article>
    </section>

    <section class="bf-grid bf-grid-bottom" aria-label="Analyses détaillées">
        <article class="bf-panel bf-panel-bottom-chart">
            <div class="bf-panel-head"><div><h2>Évolution du chiffre d’affaires</h2><p>Montant quotidien (FCFA)</p></div><span class="bf-chart-unit">Période</span></div>
            <div class="bf-chart-area bf-chart-bar"><canvas id="revenueTrendChart" aria-label="Chiffre d’affaires quotidien"></canvas></div>
        </article>
        <article class="bf-panel bf-panel-bottom-donut">
            <div class="bf-panel-head"><div><h2>Commandes par statut</h2><p>{{ $number($kpis['orders_month']['value']) }} commandes</p></div></div>
            <div class="bf-donut-layout bf-donut-layout-small">
                <div class="bf-donut-wrap"><canvas id="orderStatusChart" aria-label="Commandes par statut"></canvas><div class="bf-donut-center"><strong>{{ $number($kpis['orders_month']['value']) }}</strong><span>Commandes</span></div></div>
                <div class="bf-legend-list">@foreach ($chartData['order_statuses'] as $index => $status)<div><i class="bf-dot" style="background:{{ $statusColors[$index % count($statusColors)] }}"></i><span>{{ $status['label'] }}</span><b>{{ $number($status['value']) }}</b></div>@endforeach</div>
            </div>
        </article>
        <article class="bf-panel bf-panel-bottom-donut">
            <div class="bf-panel-head"><div><h2>Méthodes de paiement</h2><p>Encaissements confirmés</p></div></div>
            <div class="bf-donut-layout bf-donut-layout-small">
                <div class="bf-donut-wrap"><canvas id="paymentMethodChart" aria-label="Répartition des encaissements par méthode"></canvas><div class="bf-donut-center"><strong>{{ $money(array_sum($paymentValues)) }}</strong><span>Encaissé</span></div></div>
                <div class="bf-legend-list">@foreach ($chartData['payment_methods'] as $index => $method)<div><i class="bf-dot {{ $index === 0 ? 'green' : 'orange' }}"></i><span>{{ $method['label'] }}</span><b>{{ $money($method['value']) }}</b></div>@endforeach</div>
            </div>
        </article>
        <article class="bf-panel bf-panel-growth">
            <div class="bf-panel-head"><div><h2>Activité de la période</h2><p>Commandes par jour</p></div></div>
            <div class="bf-growth-stat"><strong>{{ $number($kpis['orders_month']['value']) }}</strong><span>commandes</span></div>
            <div class="bf-mini-bars" aria-hidden="true">@foreach ($chartData['revenue'] as $value)<span style="height:{{ $chartData['max_revenue'] > 0 ? max(8, (int) round($value / $chartData['max_revenue'] * 100)) : 8 }}%"></span>@endforeach</div>
            <div class="bf-growth-foot"><span>{{ $number($kpis['active_vendors']) }} boutiques actives</span><span>{{ $number($products) }} produits</span></div>
        </article>
    </section>

    <section class="bf-panel bf-orders-panel">
        <div class="bf-panel-head"><div><h2>Dernières commandes</h2><p>Activité récente dans la période choisie</p></div><a href="{{ route('admin.orders.index') }}">Toutes les commandes <i class="ti ti-arrow-right"></i></a></div>
        <div class="bf-table-scroll"><table class="bf-table bf-orders-table"><thead><tr><th>Référence</th><th>Client</th><th>Boutique</th><th>Montant</th><th>Statut</th><th>Date</th></tr></thead><tbody>
            @forelse ($latestOrders as $order)
                <tr><td><a class="bf-order-ref" href="{{ route('admin.orders.show', $order) }}">{{ $order->reference }}</a></td><td><span class="bf-inline-person"><x-admin.avatar :user="$order->user" size="sm" /><span>{{ $order->user?->name ?? '—' }}</span></span></td><td><span class="bf-inline-person"><x-admin.vendor-logo :vendor="$order->vendor" size="sm" /><span>{{ $order->vendor?->business_name ?? '—' }}</span></span></td><td><strong>{{ $money($order->total) }}</strong></td><td>{!! \App\Support\AdminLabels::orderStatusBadge($order->status->value) !!}</td><td>{{ $order->created_at?->format('d/m/Y H:i') ?? '—' }}</td></tr>
            @empty
                <tr><td colspan="6" class="bf-empty">Aucune commande sur la période sélectionnée.</td></tr>
            @endforelse
        </tbody></table></div>
    </section>
</div>
@endsection

@push('scripts')
<script>
(function () {
    var palette = { green: '#087b46', orange: '#ff8c00', blue: '#2f6fed', purple: '#7d4ce0', red: '#d64545', gray: '#a9b1bd' };
    var labels = @json($chartData['labels']);
    var revenue = @json($chartData['revenue']);
    var commissions = @json($chartData['commissions']);
    var commissionSplit = @json($chartData['commission_split']);
    var revenueSplit = @json($chartData['revenue_split']);
    var orderStatus = @json($statusValues);
    var orderStatusLabels = @json($statusLabels);
    var paymentValues = @json($paymentValues);
    var paymentLabels = @json($paymentLabels);
    var chartColors = [palette.orange, palette.green, palette.blue, palette.red, palette.purple, palette.gray];

    if (typeof Chart === 'undefined') return;

    Chart.defaults.global.defaultFontFamily = "Roboto, sans-serif";
    Chart.defaults.global.defaultFontColor = '#8791a0';
    Chart.defaults.global.defaultFontSize = 10;

    var commissionCanvas = document.getElementById('commissionTrendChart');
    if (commissionCanvas) {
        var ctx = commissionCanvas.getContext('2d');
        var gradient = ctx.createLinearGradient(0, 0, 0, 220);
        gradient.addColorStop(0, 'rgba(255,140,0,.2)');
        gradient.addColorStop(1, 'rgba(255,140,0,0)');
        new Chart(ctx, {
            type: 'line',
            data: { labels: labels, datasets: [{ data: commissions, borderColor: palette.orange, backgroundColor: gradient, borderWidth: 2, pointRadius: 2, pointHoverRadius: 5, pointBackgroundColor: palette.orange, fill: true, lineTension: .35 }] },
            options: { maintainAspectRatio: false, legend: { display: false }, tooltips: { callbacks: { label: function (item) { return ' '+Number(item.yLabel).toLocaleString('fr-FR')+' FCFA'; } } }, scales: { xAxes: [{ gridLines: { display: false }, ticks: { maxTicksLimit: 8, maxRotation: 0 } }], yAxes: [{ ticks: { beginAtZero: true, maxTicksLimit: 5, callback: function (value) { return Number(value).toLocaleString('fr-FR'); } }, gridLines: { color: '#edf0f3', drawBorder: false } }] } }
        });
    }

    function doughnut(id, values, colors) {
        var canvas = document.getElementById(id);
        if (!canvas) return;
        new Chart(canvas.getContext('2d'), {
            type: 'doughnut', data: { labels: [], datasets: [{ data: values.length ? values : [1], backgroundColor: values.some(function (value) { return value > 0; }) ? colors : ['#edf0f3'], borderWidth: 0, hoverBorderWidth: 0 }] },
            options: { cutoutPercentage: 74, maintainAspectRatio: false, legend: { display: false }, tooltips: { enabled: values.some(function (value) { return value > 0; }), callbacks: { label: function (item, data) { return ' '+Number(data.datasets[0].data[item.index]).toLocaleString('fr-FR')+' FCFA'; } } } }
        });
    }
    doughnut('commissionSplitChart', commissionSplit, [palette.green, palette.orange]);
    doughnut('revenueSplitChart', revenueSplit, [palette.green, palette.orange, palette.blue]);
    doughnut('orderStatusChart', orderStatus, chartColors);
    doughnut('paymentMethodChart', paymentValues, [palette.green, palette.orange]);

    var revenueCanvas = document.getElementById('revenueTrendChart');
    if (revenueCanvas) {
        new Chart(revenueCanvas.getContext('2d'), {
            type: 'bar', data: { labels: labels, datasets: [{ data: revenue, backgroundColor: palette.orange, hoverBackgroundColor: '#e97800', borderRadius: 3, maxBarThickness: 12 }] },
            options: { maintainAspectRatio: false, legend: { display: false }, tooltips: { callbacks: { label: function (item) { return ' '+Number(item.yLabel).toLocaleString('fr-FR')+' FCFA'; } } }, scales: { xAxes: [{ gridLines: { display: false }, ticks: { maxTicksLimit: 8, maxRotation: 0 } }], yAxes: [{ ticks: { beginAtZero: true, maxTicksLimit: 4, callback: function (value) { return Number(value).toLocaleString('fr-FR'); } }, gridLines: { color: '#edf0f3', drawBorder: false } }] } }
        });
    }
})();
</script>
@endpush
