<!-- begin sidebar -->
<aside class="app-navbar" style="background-color: var(--sidebar-bg);">
    <div class="sidebar-nav scrollbar scroll_light">
        <ul class="metismenu" id="sidebarNav">
            <li class="nav-static-title" style="color: var(--sidebar-text); font-size: 11px; text-transform: uppercase; letter-spacing: 1px; padding: 20px 20px 10px;">{{ __('admin.navigation') }}</li>
            
            <li class="{{ request()->routeIs('admin.dashboard') ? 'active' : '' }}">
                <a href="{{ route('admin.dashboard') }}" style="color: {{ request()->routeIs('admin.dashboard') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.dashboard') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-home" style="color: {{ request()->routeIs('admin.dashboard') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.dashboard') }}</span>
                </a>
            </li>
            
            <li class="{{ request()->routeIs('admin.vendors.*') ? 'active' : '' }}">
                <a href="{{ route('admin.vendors.index') }}" style="color: {{ request()->routeIs('admin.vendors.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.vendors.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-briefcase" style="color: {{ request()->routeIs('admin.vendors.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.vendors') }}</span>
                </a>
            </li>
            
            <li class="{{ request()->routeIs('admin.clients.*') ? 'active' : '' }}">
                <a href="{{ route('admin.clients.index') }}" style="color: {{ request()->routeIs('admin.clients.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.clients.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-user" style="color: {{ request()->routeIs('admin.clients.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.clients') }}</span>
                </a>
            </li>
            
            <li class="{{ request()->routeIs('admin.drivers.*') ? 'active' : '' }}">
                <a href="{{ route('admin.drivers.index') }}" style="color: {{ request()->routeIs('admin.drivers.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.drivers.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-truck" style="color: {{ request()->routeIs('admin.drivers.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.drivers') }}</span>
                </a>
            </li>
            
            <li class="{{ request()->routeIs('admin.orders.*') ? 'active' : '' }}">
                <a href="{{ route('admin.orders.index') }}" style="color: {{ request()->routeIs('admin.orders.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.orders.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-shopping-cart" style="color: {{ request()->routeIs('admin.orders.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.orders') }}</span>
                </a>
            </li>
            
            <li class="{{ request()->routeIs('admin.products.*') || request()->routeIs('admin.shops.*') ? 'active' : '' }}">
                <a class="has-arrow" href="javascript:void(0)" aria-expanded="false" style="color: {{ request()->routeIs('admin.products.*') || request()->routeIs('admin.shops.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.products.*') || request()->routeIs('admin.shops.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-store" style="color: {{ request()->routeIs('admin.products.*') || request()->routeIs('admin.shops.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.products_shops') }}</span>
                </a>
                <ul aria-expanded="false" style="background-color: rgba(0,0,0,0.2);">
                    <li class="{{ request()->routeIs('admin.shops.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.shops.index') }}" style="color: {{ request()->routeIs('admin.shops.*') ? 'var(--benin-orange)' : 'var(--sidebar-text)' }};">{{ __('admin.shops') }}</a>
                    </li>
                    <li class="{{ request()->routeIs('admin.products.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.products.index') }}" style="color: {{ request()->routeIs('admin.products.*') ? 'var(--benin-orange)' : 'var(--sidebar-text)' }};">{{ __('admin.products') }}</a>
                    </li>
                </ul>
            </li>
            
            <li class="{{ request()->routeIs('admin.commissions.*') ? 'active' : '' }}">
                <a href="{{ route('admin.commissions.index') }}" style="color: {{ request()->routeIs('admin.commissions.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.commissions.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-wallet" style="color: {{ request()->routeIs('admin.commissions.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.commissions') }}</span>
                </a>
            </li>
            
            <li class="{{ request()->routeIs('admin.zones.*') || request()->routeIs('admin.rates.*') ? 'active' : '' }}">
                <a class="has-arrow" href="javascript:void(0)" aria-expanded="false" style="color: {{ request()->routeIs('admin.zones.*') || request()->routeIs('admin.rates.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.zones.*') || request()->routeIs('admin.rates.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-map-alt" style="color: {{ request()->routeIs('admin.zones.*') || request()->routeIs('admin.rates.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.delivery') }}</span>
                </a>
                <ul aria-expanded="false" style="background-color: rgba(0,0,0,0.2);">
                    <li class="{{ request()->routeIs('admin.zones.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.zones.index') }}" style="color: {{ request()->routeIs('admin.zones.*') ? 'var(--benin-orange)' : 'var(--sidebar-text)' }};">{{ __('admin.zones') }}</a>
                    </li>
                    <li class="{{ request()->routeIs('admin.rates.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.rates.index') }}" style="color: {{ request()->routeIs('admin.rates.*') ? 'var(--benin-orange)' : 'var(--sidebar-text)' }};">{{ __('admin.rates') }}</a>
                    </li>
                </ul>
            </li>
            
            <li class="{{ request()->routeIs('admin.payments.*') || request()->routeIs('admin.refunds.*') ? 'active' : '' }}">
                <a class="has-arrow" href="javascript:void(0)" aria-expanded="false" style="color: {{ request()->routeIs('admin.payments.*') || request()->routeIs('admin.refunds.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.payments.*') || request()->routeIs('admin.refunds.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-credit-card" style="color: {{ request()->routeIs('admin.payments.*') || request()->routeIs('admin.refunds.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.payments') }}</span>
                </a>
                <ul aria-expanded="false" style="background-color: rgba(0,0,0,0.2);">
                    <li class="{{ request()->routeIs('admin.payments.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.payments.index') }}" style="color: {{ request()->routeIs('admin.payments.*') ? 'var(--benin-orange)' : 'var(--sidebar-text)' }};">{{ __('admin.transactions') }}</a>
                    </li>
                    <li class="{{ request()->routeIs('admin.refunds.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.refunds.index') }}" style="color: {{ request()->routeIs('admin.refunds.*') ? 'var(--benin-orange)' : 'var(--sidebar-text)' }};">{{ __('admin.refunds') }}</a>
                    </li>
                </ul>
            </li>
            
            <li class="{{ request()->routeIs('admin.complaints.*') ? 'active' : '' }}">
                <a href="{{ route('admin.complaints.index') }}" style="color: {{ request()->routeIs('admin.complaints.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.complaints.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-headphone" style="color: {{ request()->routeIs('admin.complaints.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">Réclamations</span>
                </a>
            </li>
            
                    <li class="nav-static-title" style="color: var(--sidebar-text); font-size: 11px; text-transform: uppercase; letter-spacing: 1px; padding: 20px 20px 10px;">{{ __('admin.configuration') }}</li>
            
            <li class="{{ request()->routeIs('admin.users.*') ? 'active' : '' }}">
                <a href="{{ route('admin.users.index') }}" style="color: {{ request()->routeIs('admin.users.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.users.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-user" style="color: {{ request()->routeIs('admin.users.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.users') }}</span>
                </a>
            </li>

            <li class="{{ request()->routeIs('admin.roles.*') ? 'active' : '' }}">
                <a href="{{ route('admin.roles.index') }}" style="color: {{ request()->routeIs('admin.roles.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.roles.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-lock" style="color: {{ request()->routeIs('admin.roles.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.roles_permissions') }}</span>
                </a>
            </li>

            <li class="{{ request()->routeIs('admin.settings.*') ? 'active' : '' }}">
                <a href="{{ route('admin.settings.index') }}" style="color: {{ request()->routeIs('admin.settings.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.settings.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-settings" style="color: {{ request()->routeIs('admin.settings.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.settings') }}</span>
                </a>
            </li>

            <li class="{{ request()->routeIs('admin.audit.*') || request()->routeIs('admin.reports.*') ? 'active' : '' }}">
                <a class="has-arrow" href="javascript:void(0)" aria-expanded="false" style="color: {{ request()->routeIs('admin.audit.*') || request()->routeIs('admin.reports.*') ? '#FFFFFF' : 'var(--sidebar-text)' }}; background-color: {{ request()->routeIs('admin.audit.*') || request()->routeIs('admin.reports.*') ? 'var(--sidebar-active-bg)' : 'transparent' }};">
                    <i class="nav-icon ti ti-pie-chart" style="color: {{ request()->routeIs('admin.audit.*') || request()->routeIs('admin.reports.*') ? '#FFFFFF' : 'var(--sidebar-text)' }};"></i>
                    <span class="nav-title">{{ __('admin.audit_reports') }}</span>
                </a>
                <ul aria-expanded="false" style="background-color: rgba(0,0,0,0.2);">
                    <li class="{{ request()->routeIs('admin.audit.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.audit.index') }}" style="color: {{ request()->routeIs('admin.audit.*') ? 'var(--benin-orange)' : 'var(--sidebar-text)' }};">{{ __('admin.audit') }}</a>
                    </li>
                    <li class="{{ request()->routeIs('admin.reports.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.reports.index') }}" style="color: {{ request()->routeIs('admin.reports.*') ? 'var(--benin-orange)' : 'var(--sidebar-text)' }};">{{ __('admin.reports') }}</a>
                    </li>
                </ul>
            </li>
        </ul>
    </div>
</aside>
<!-- end sidebar -->