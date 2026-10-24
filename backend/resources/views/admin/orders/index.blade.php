@extends('layouts.app')

@push('styles')
    <link rel="stylesheet" href="{{ asset('assets/css/admin-orders.css') }}">
@endpush

@section('content')
    @php
        $formatCount = fn (int $count): string => number_format($count, 0, ',', ' ');
        $currentStatus = $filters['status'] ?? null;
        $statusCards = [
            ['key' => null, 'label' => 'Toutes', 'hint' => 'Toutes les commandes', 'count' => (int) $counts['all'], 'icon' => 'ti-receipt-2', 'tone' => 'green'],
            ['key' => 'awaiting_payment', 'label' => 'À payer', 'hint' => 'Paiement attendu', 'count' => (int) $counts['awaiting_payment'], 'icon' => 'ti-wallet', 'tone' => 'orange'],
            ['key' => 'in_progress', 'label' => 'En cours', 'hint' => 'En préparation ou livraison', 'count' => (int) $counts['in_progress'], 'icon' => 'ti-truck-delivery', 'tone' => 'blue'],
            ['key' => 'delivered', 'label' => 'Livrées', 'hint' => 'Commandes terminées', 'count' => (int) $counts['delivered'], 'icon' => 'ti-circle-check', 'tone' => 'emerald'],
            ['key' => 'cancelled', 'label' => 'Annulées', 'hint' => 'Annulations et remboursements', 'count' => (int) $counts['cancelled'], 'icon' => 'ti-ban', 'tone' => 'red'],
        ];
        $baseQuery = array_filter([
            'q' => $filters['q'] ?? null,
            'vendor_id' => $filters['vendor_id'] ?? null,
            'from' => $filters['from'] ?? null,
            'to' => $filters['to'] ?? null,
            'per_page' => ($filters['per_page'] ?? 20) !== 20 ? $filters['per_page'] : null,
        ], fn ($value): bool => $value !== null && $value !== '');
        $filterUrl = fn (array $overrides = []): string => route('admin.orders.index', array_filter(
            array_merge($baseQuery, $overrides),
            fn ($value): bool => $value !== null && $value !== '',
        ));
        $currentStatusCard = collect($statusCards)->first(fn (array $card): bool => $card['key'] === $currentStatus);
        $activeFilters = [];

        if (! empty($filters['q'])) {
            $activeFilters[] = [
                'label' => 'Recherche',
                'value' => $filters['q'],
                'url' => $filterUrl(['q' => null]),
            ];
        }

        if ($currentStatusCard !== null) {
            $activeFilters[] = [
                'label' => 'Statut',
                'value' => $currentStatusCard['label'],
                'url' => $filterUrl(['status' => null]),
            ];
        }

        if (! empty($filters['vendor_id'])) {
            $vendorName = $vendors->firstWhere('id', $filters['vendor_id'])?->business_name;

            if ($vendorName !== null) {
                $activeFilters[] = [
                    'label' => 'Boutique',
                    'value' => $vendorName,
                    'url' => $filterUrl(['vendor_id' => null]),
                ];
            }
        }

        if (! empty($filters['from'])) {
            $activeFilters[] = [
                'label' => 'Du',
                'value' => \Illuminate\Support\Carbon::parse($filters['from'])->format('d/m/Y'),
                'url' => $filterUrl(['from' => null]),
            ];
        }

        if (! empty($filters['to'])) {
            $activeFilters[] = [
                'label' => 'Au',
                'value' => \Illuminate\Support\Carbon::parse($filters['to'])->format('d/m/Y'),
                'url' => $filterUrl(['to' => null]),
            ];
        }
    @endphp

    <div class="orders-page">
        <section class="orders-hero">
            <span class="orders-hero__halo" aria-hidden="true"></span>
            <div class="orders-hero__content">
                <span class="orders-eyebrow">
                    <span class="orders-eyebrow__dot" aria-hidden="true"></span>
                    Pilotage des ventes
                </span>
                <h1>Commandes</h1>
                <p>Suivez chaque commande, filtrez les opérations sensibles et accédez au détail en un clin d’œil.</p>
            </div>
            <div class="orders-hero__actions">
                <a href="{{ route('admin.dashboard') }}" class="orders-action orders-action--glass">
                    <i class="ti ti-layout-dashboard" aria-hidden="true"></i>
                    <span>Tableau de bord</span>
                </a>
                <a href="{{ route('admin.reports.index') }}" class="orders-action orders-action--accent">
                    <i class="ti ti-chart-bar" aria-hidden="true"></i>
                    <span>Rapports</span>
                </a>
            </div>
        </section>

        <section class="orders-stats" aria-label="Répartition des commandes">
            @foreach ($statusCards as $card)
                @php
                    $isActive = $currentStatus === $card['key'];
                @endphp
                <a href="{{ $filterUrl(['status' => $card['key']]) }}"
                   class="orders-stat{{ $isActive ? ' is-active' : '' }}"
                   data-tone="{{ $card['tone'] }}"
                   @if ($isActive) aria-current="true" @endif>
                    <span class="orders-stat__icon">
                        <i class="ti {{ $card['icon'] }}" aria-hidden="true"></i>
                    </span>
                    <span class="orders-stat__copy">
                        <span class="orders-stat__label">{{ $card['label'] }}</span>
                        <strong class="orders-stat__value">{{ $formatCount($card['count']) }}</strong>
                        <span class="orders-stat__hint">{{ $card['hint'] }}</span>
                    </span>
                    <span class="orders-stat__arrow" aria-hidden="true">
                        <i class="ti ti-arrow-up-right"></i>
                    </span>
                </a>
            @endforeach
        </section>

        @if (session('success'))
            <div class="orders-flash orders-flash--success" role="status" data-orders-flash>
                <span class="orders-flash__icon"><i class="ti ti-circle-check" aria-hidden="true"></i></span>
                <p>{{ session('success') }}</p>
                <button type="button" class="orders-flash__close" data-dismiss-flash aria-label="Fermer le message">
                    <i class="ti ti-x" aria-hidden="true"></i>
                </button>
            </div>
        @endif

        @if (session('error'))
            <div class="orders-flash orders-flash--error" role="alert" data-orders-flash>
                <span class="orders-flash__icon"><i class="ti ti-alert-circle" aria-hidden="true"></i></span>
                <p>{{ session('error') }}</p>
                <button type="button" class="orders-flash__close" data-dismiss-flash aria-label="Fermer le message">
                    <i class="ti ti-x" aria-hidden="true"></i>
                </button>
            </div>
        @endif

        <section class="orders-panel orders-filter-panel" aria-labelledby="orders-filter-title">
            <div class="orders-panel__head">
                <div>
                    <h2 id="orders-filter-title">Affiner la recherche</h2>
                    <p>Retrouvez une commande par référence, client, boutique ou période.</p>
                </div>
                @if ($activeFilters !== [])
                    <span class="orders-filter-count">
                        <i class="ti ti-filter" aria-hidden="true"></i>
                        {{ count($activeFilters) }} filtre{{ count($activeFilters) > 1 ? 's' : '' }} actif{{ count($activeFilters) > 1 ? 's' : '' }}
                    </span>
                @endif
            </div>

            <form method="GET" action="{{ route('admin.orders.index') }}" class="orders-filter-form" data-orders-filter>
                @if ($currentStatus !== null)
                    <input type="hidden" name="status" value="{{ $currentStatus }}">
                @endif
                @if (($filters['per_page'] ?? 20) !== 20)
                    <input type="hidden" name="per_page" value="{{ $filters['per_page'] }}">
                @endif

                <div class="orders-filter-row">
                    <label class="orders-field orders-field--search">
                        <span class="orders-field__label">Recherche</span>
                        <span class="orders-input-wrap">
                            <i class="ti ti-search orders-input-icon" aria-hidden="true"></i>
                            <input type="search"
                                   name="q"
                                   value="{{ $filters['q'] ?? '' }}"
                                   class="orders-input"
                                   placeholder="Référence, client ou boutique"
                                   autocomplete="off">
                        </span>
                    </label>

                    <label class="orders-field orders-field--vendor">
                        <span class="orders-field__label">Boutique</span>
                        <span class="orders-input-wrap">
                            <i class="ti ti-building-store orders-input-icon" aria-hidden="true"></i>
                            <select name="vendor_id" class="orders-input orders-select">
                                <option value="">Toutes les boutiques</option>
                                @foreach ($vendors as $vendor)
                                    <option value="{{ $vendor->id }}" @selected((string) ($filters['vendor_id'] ?? '') === (string) $vendor->id)>
                                        {{ $vendor->business_name }}
                                    </option>
                                @endforeach
                            </select>
                            <i class="ti ti-chevron-down orders-select-chevron" aria-hidden="true"></i>
                        </span>
                    </label>

                    <label class="orders-field orders-field--date">
                        <span class="orders-field__label">Du</span>
                        <span class="orders-input-wrap">
                            <input type="date" name="from" value="{{ $filters['from'] ?? '' }}" class="orders-input">
                        </span>
                    </label>

                    <label class="orders-field orders-field--date">
                        <span class="orders-field__label">Au</span>
                        <span class="orders-input-wrap">
                            <input type="date" name="to" value="{{ $filters['to'] ?? '' }}" class="orders-input">
                        </span>
                    </label>

                    <div class="orders-filter-actions">
                        <button type="submit" class="orders-button orders-button--primary" data-orders-submit>
                            <span class="orders-button__spinner" aria-hidden="true"></span>
                            <i class="ti ti-search" aria-hidden="true"></i>
                            <span>Filtrer</span>
                        </button>
                        <a href="{{ route('admin.orders.index') }}" class="orders-button orders-button--ghost">
                            <i class="ti ti-refresh" aria-hidden="true"></i>
                            <span>Réinitialiser</span>
                        </a>
                    </div>
                </div>
            </form>

            @if ($activeFilters !== [])
                <div class="orders-active-filters">
                    <span class="orders-active-filters__label">
                        <i class="ti ti-filter-check" aria-hidden="true"></i>
                        Filtres appliqués
                    </span>
                    @foreach ($activeFilters as $activeFilter)
                        <a href="{{ $activeFilter['url'] }}" class="orders-filter-chip" title="Retirer ce filtre">
                            <span>{{ $activeFilter['label'] }}</span>
                            <strong>{{ $activeFilter['value'] }}</strong>
                            <i class="ti ti-x" aria-hidden="true"></i>
                        </a>
                    @endforeach
                </div>
            @endif
        </section>

        <section class="orders-panel orders-table-panel" aria-labelledby="orders-list-title">
            <div class="orders-panel__head orders-table-panel__head">
                <div>
                    <div class="orders-title-row">
                        <h2 id="orders-list-title">Liste des commandes</h2>
                        <span class="orders-result-pill">{{ $formatCount($orders->total()) }}</span>
                    </div>
                    <p>
                        @if ($currentStatusCard !== null)
                            {{ $currentStatusCard['label'] }} ·
                        @endif
                        @if ($orders->total() > 0)
                            Affichage de {{ $formatCount($orders->firstItem()) }} à {{ $formatCount($orders->lastItem()) }} sur {{ $formatCount($orders->total()) }} commande{{ $orders->total() > 1 ? 's' : '' }}
                        @else
                            Aucun résultat pour cette recherche
                        @endif
                    </p>
                </div>
                <span class="orders-sort-note">
                    <i class="ti ti-arrows-sort" aria-hidden="true"></i>
                    Plus récentes d’abord
                </span>
            </div>

            @if ($orders->isEmpty())
                <div class="orders-empty">
                    <span class="orders-empty__icon">
                        <i class="ti ti-receipt-off" aria-hidden="true"></i>
                    </span>
                    <h3>Aucune commande trouvée</h3>
                    <p>Aucun résultat ne correspond aux filtres sélectionnés.</p>
                    <a href="{{ route('admin.orders.index') }}" class="orders-button orders-button--primary">
                        <i class="ti ti-refresh" aria-hidden="true"></i>
                        <span>Réinitialiser les filtres</span>
                    </a>
                </div>
            @else
                <div class="orders-table-wrap">
                    <table class="orders-table">
                        <thead>
                            <tr>
                                <th scope="col">Référence</th>
                                <th scope="col">Client</th>
                                <th scope="col">Boutique</th>
                                <th scope="col" class="orders-align-right">Total</th>
                                <th scope="col">Paiement</th>
                                <th scope="col">Statut</th>
                                <th scope="col">Date</th>
                                <th scope="col"><span class="orders-sr-only">Actions</span></th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($orders as $order)
                                @php
                                    $customerName = $order->user?->name ?? 'Client supprimé';
                                    $statusInfo = \App\Support\AdminLabels::orderStatus($order->status->value);
                                    $statusTone = match ($order->status->value) {
                                        'delivered' => 'success',
                                        'paid', 'accepted', 'preparing', 'ready', 'assigned', 'picked_up', 'in_delivery' => 'info',
                                        'awaiting_payment' => 'warning',
                                        'cancelled', 'disputed' => 'danger',
                                        'refunded' => 'violet',
                                        default => 'neutral',
                                    };
                                    $paymentInfo = $order->payment
                                        ? \App\Support\AdminLabels::paymentStatus($order->payment->status->value)
                                        : ['label' => 'Non initié'];
                                    $paymentTone = match ($order->payment?->status->value) {
                                        'confirmed' => 'success',
                                        'initiated', 'pending' => 'warning',
                                        'refunded' => 'violet',
                                        'failed' => 'danger',
                                        default => 'neutral',
                                    };
                                @endphp
                                <tr class="orders-row" style="--row-index: {{ $loop->index }}">
                                    <td class="orders-col-reference" data-label="Référence">
                                        <div class="orders-reference">
                                            <a href="{{ route('admin.orders.show', $order) }}" class="orders-reference__link">
                                                <span class="orders-reference__icon">
                                                    <i class="ti ti-receipt-2" aria-hidden="true"></i>
                                                </span>
                                                <span class="orders-reference__text">
                                                    <strong>{{ $order->reference }}</strong>
                                                    <small>Commande</small>
                                                </span>
                                            </a>
                                            <button type="button"
                                                    class="orders-copy"
                                                    data-copy-order="{{ $order->reference }}"
                                                    aria-label="Copier la référence {{ $order->reference }}"
                                                    title="Copier la référence">
                                                <i class="ti ti-copy" aria-hidden="true"></i>
                                            </button>
                                        </div>
                                    </td>
                                    <td class="orders-col-client" data-label="Client">
                                        <div class="orders-person">
                                            <x-admin.avatar :user="$order->user" :name="$customerName" size="sm" />
                                            <span class="orders-person__text">
                                                <strong>{{ $customerName }}</strong>
                                                <small>{{ $order->user?->phone ?? 'Client Béninfood' }}</small>
                                            </span>
                                        </div>
                                    </td>
                                    <td class="orders-col-vendor" data-label="Boutique">
                                        <span class="orders-vendor">
                                            <x-admin.vendor-logo :vendor="$order->vendor" size="sm" />
                                            <span>{{ $order->vendor?->business_name ?? 'Boutique supprimée' }}</span>
                                        </span>
                                    </td>
                                    <td class="orders-col-total orders-align-right" data-label="Total">
                                        <span class="orders-amount">{{ \App\Support\AdminLabels::priceLabel($order->total) }}</span>
                                    </td>
                                    <td class="orders-col-payment" data-label="Paiement">
                                        <x-admin.status-badge :label="$paymentInfo['label']" :tone="$paymentTone" />
                                    </td>
                                    <td class="orders-col-status" data-label="Statut">
                                        <x-admin.status-badge :label="$statusInfo['label']" :tone="$statusTone" />
                                    </td>
                                    <td class="orders-col-date" data-label="Date">
                                        <span class="orders-date">
                                            <strong>{{ $order->created_at?->format('d/m/Y') ?? '—' }}</strong>
                                            <small>{{ $order->created_at?->format('H:i') ?? '' }}</small>
                                        </span>
                                    </td>
                                    <td class="orders-col-action">
                                        <a href="{{ route('admin.orders.show', $order) }}" class="orders-view" aria-label="Voir la commande {{ $order->reference }}">
                                            <span>Voir</span>
                                            <i class="ti ti-arrow-up-right" aria-hidden="true"></i>
                                        </a>
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>

                @include('admin.orders.partials.pagination', ['orders' => $orders, 'filters' => $filters])
            @endif
        </section>
    </div>
@endsection

@push('scripts')
    <script src="{{ asset('assets/js/admin-orders.js') }}"></script>
@endpush
