@php
    $sections = [
        [
            'label' => __('admin.navigation'),
            'items' => [
                [
                    'label' => __('admin.dashboard'),
                    'icon' => 'ti-dashboard',
                    'route' => 'admin.dashboard',
                    'match' => ['admin.dashboard'],
                ],
                [
                    'label' => __('admin.vendors'),
                    'icon' => 'ti-briefcase',
                    'route' => 'admin.vendors.index',
                    'match' => ['admin.vendors.*'],
                ],
                [
                    'label' => __('admin.clients'),
                    'icon' => 'ti-user',
                    'route' => 'admin.clients.index',
                    'match' => ['admin.clients.*'],
                ],
                [
                    'label' => __('admin.drivers'),
                    'icon' => 'ti-truck',
                    'route' => 'admin.drivers.index',
                    'match' => ['admin.drivers.*'],
                ],
                [
                    'label' => __('admin.orders'),
                    'icon' => 'ti-shopping-cart',
                    'route' => 'admin.orders.index',
                    'match' => ['admin.orders.*'],
                ],
                [
                    'label' => 'Colis',
                    'icon' => 'ti-package',
                    'route' => 'admin.parcels.index',
                    'match' => ['admin.parcels.*'],
                ],
                [
                    'label' => __('admin.products_shops'),
                    'icon' => 'ti-package',
                    'match' => ['admin.products.*', 'admin.shops.*'],
                    'children' => [
                        ['label' => __('admin.shops'), 'route' => 'admin.shops.index', 'match' => ['admin.shops.*']],
                        ['label' => __('admin.products'), 'route' => 'admin.products.index', 'match' => ['admin.products.*']],
                    ],
                ],
                [
                    'label' => __('admin.commissions'),
                    'icon' => 'ti-pie-chart',
                    'route' => 'admin.commissions.index',
                    'match' => ['admin.commissions.*'],
                ],
                [
                    'label' => __('admin.delivery'),
                    'icon' => 'ti-direction',
                    'match' => ['admin.zones.*', 'admin.locations.*', 'admin.rates.*', 'admin.pricing.*'],
                    'children' => [
                        ['label' => __('admin.zones'), 'route' => 'admin.zones.index', 'match' => ['admin.zones.*']],
                        ['label' => __('admin.locations'), 'route' => 'admin.locations.index', 'match' => ['admin.locations.*']],
                        ['label' => __('admin.rates'), 'route' => 'admin.rates.index', 'match' => ['admin.rates.*']],
                        ['label' => 'Tarifs par distance', 'route' => 'admin.pricing.index', 'match' => ['admin.pricing.*']],
                    ],
                ],
                [
                    'label' => __('admin.payments'),
                    'icon' => 'ti-wallet',
                    'match' => ['admin.payments.*', 'admin.refunds.*', 'admin.payouts.*', 'admin.platform-wallet.*'],
                    'children' => [
                        ['label' => __('admin.transactions'), 'route' => 'admin.payments.index', 'match' => ['admin.payments.*']],
                        ['label' => __('admin.refunds'), 'route' => 'admin.refunds.index', 'match' => ['admin.refunds.*']],
                        ['label' => 'Wallets & retraits', 'route' => 'admin.payouts.index', 'match' => ['admin.payouts.*']],
                        ['label' => 'Wallet plateforme', 'route' => 'admin.platform-wallet.index', 'match' => ['admin.platform-wallet.*']],
                    ],
                ],
                [
                    'label' => 'Réclamations',
                    'icon' => 'ti-comments',
                    'route' => 'admin.complaints.index',
                    'match' => ['admin.complaints.*'],
                ],
            ],
        ],
        [
            'label' => __('admin.configuration'),
            'items' => [
                [
                    'label' => __('admin.users'),
                    'icon' => 'ti-user',
                    'route' => 'admin.users.index',
                    'match' => ['admin.users.*'],
                ],
                [
                    'label' => __('admin.roles_permissions'),
                    'icon' => 'ti-shield',
                    'route' => 'admin.roles.index',
                    'match' => ['admin.roles.*'],
                ],
                [
                    'label' => __('admin.settings'),
                    'icon' => 'ti-settings',
                    'route' => 'admin.settings.index',
                    'match' => ['admin.settings.*'],
                ],
                [
                    'label' => __('admin.audit_reports'),
                    'icon' => 'ti-stats-up',
                    'match' => ['admin.audit.*', 'admin.reports.*'],
                    'children' => [
                        ['label' => __('admin.audit'), 'route' => 'admin.audit.index', 'match' => ['admin.audit.*']],
                        ['label' => __('admin.reports'), 'route' => 'admin.reports.index', 'match' => ['admin.reports.*']],
                    ],
                ],
            ],
        ],
    ];
@endphp

<aside class="app-navbar">
    <div class="bf-sidebar-brand">
        <span class="bf-brand-mark">
            <img src="{{ asset('assets/img/logo.jpeg') }}" alt="Logo Béninfood" width="36" height="36">
        </span>
        <span class="bf-brand-copy">
            <span class="bf-brand-name"><span>BÉNI</span><strong>NFOOD</strong></span>
            <small>Back-office</small>
        </span>
    </div>

    <div class="sidebar-nav scrollbar scroll_light">
        <ul class="metismenu" id="sidebarNav">
            @foreach ($sections as $section)
                <li class="nav-static-title">{{ $section['label'] }}</li>

                @foreach ($section['items'] as $item)
                    @php
                        $isActive = collect($item['match'])->contains(fn (string $pattern): bool => request()->routeIs($pattern));
                    @endphp

                    <li class="{{ $isActive ? 'active' : '' }}">
                        @if (! empty($item['children']))
                            <a class="has-arrow" href="javascript:void(0)" aria-expanded="{{ $isActive ? 'true' : 'false' }}">
                                <i class="nav-icon ti {{ $item['icon'] }}" aria-hidden="true"></i>
                                <span class="nav-title">{{ $item['label'] }}</span>
                            </a>
                            <ul aria-expanded="{{ $isActive ? 'true' : 'false' }}">
                                @foreach ($item['children'] as $child)
                                    @php
                                        $isChildActive = request()->routeIs($child['match']);
                                    @endphp
                                    <li class="{{ $isChildActive ? 'active' : '' }}">
                                        <a href="{{ route($child['route']) }}">
                                            <span class="bf-nav-bullet" aria-hidden="true"></span>
                                            <span>{{ $child['label'] }}</span>
                                        </a>
                                    </li>
                                @endforeach
                            </ul>
                        @else
                            <a href="{{ route($item['route']) }}">
                                <i class="nav-icon ti {{ $item['icon'] }}" aria-hidden="true"></i>
                                <span class="nav-title">{{ $item['label'] }}</span>
                            </a>
                        @endif
                    </li>
                @endforeach
            @endforeach
        </ul>
    </div>

    <div class="bf-sidebar-foot">
        <span class="bf-sidebar-foot__dot" aria-hidden="true"></span>
        <span>Plateforme opérationnelle</span>
    </div>
</aside>
