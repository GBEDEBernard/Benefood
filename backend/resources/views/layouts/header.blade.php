@php
    $currentUser = auth()->user();
@endphp

<header class="app-header top-bar">
    <nav class="navbar navbar-expand-md">
        <div class="navbar-header d-flex align-items-center">
            <a href="javascript:void(0)" class="mobile-toggle" aria-label="Ouvrir la navigation">
                <i class="ti ti-menu-alt" aria-hidden="true"></i>
            </a>

            <a class="navbar-brand d-flex align-items-center" href="{{ route('admin.dashboard') }}">
                <span class="bf-brand-mark">
                    <img src="{{ asset('assets/img/logo.jpeg') }}" alt="Logo Béninfood" width="42" height="42">
                </span>
                <span class="bf-brand-copy">
                    <span class="bf-brand-name"><span>BÉNI</span><strong>NFOOD</strong></span>
                    <small>Back-office</small>
                </span>
            </a>
        </div>

        <div class="collapse navbar-collapse" id="navbarSupportedContent">
            <div class="navigation d-flex">
                <ul class="navbar-nav nav-left">
                    <li class="nav-item">
                        <a href="javascript:void(0)" class="nav-link sidebar-toggle" aria-label="Réduire la navigation">
                            <i class="ti ti-layout-sidebar-left" aria-hidden="true"></i>
                        </a>
                    </li>
                </ul>

                @if (request()->routeIs('admin.dashboard'))
                    <form class="bf-top-search" method="GET" action="{{ route('admin.orders.index') }}" role="search">
                        <i class="ti ti-search" aria-hidden="true"></i>
                        <input type="search" name="q" value="{{ request()->routeIs('admin.orders.*') ? request('q') : '' }}" aria-label="Rechercher une commande" placeholder="Rechercher une commande par référence...">
                        <kbd>Entrée</kbd>
                    </form>
                @endif

                <ul class="navbar-nav nav-right ml-auto align-items-center">
                    <li class="nav-item">
                        <a class="nav-link bf-header-icon" href="{{ route('admin.complaints.index') }}" aria-label="Ouvrir les réclamations" title="Réclamations">
                            <i class="ti ti-bell" aria-hidden="true"></i>
                            <span class="bf-notify-dot"></span>
                        </a>
                    </li>
                    <li class="nav-item dropdown user-profile">
                        <a href="javascript:void(0)" class="nav-link dropdown-toggle bf-user-toggle d-flex align-items-center" id="navbarDropdown4" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                            <x-admin.avatar :user="$currentUser" size="sm" :online="true" />
                            <span class="bf-user-meta d-none d-md-flex">
                                <strong>{{ $currentUser?->name ?? 'Administrateur' }}</strong>
                                <small>{{ $currentUser?->activeRoleSlug() ? ucfirst(str_replace('-', ' ', $currentUser->activeRoleSlug())) : 'Back-office' }}</small>
                            </span>
                            <i class="ti ti-angle-down bf-user-chevron" aria-hidden="true"></i>
                        </a>

                        <div class="dropdown-menu dropdown-menu-right animated fadeIn" aria-labelledby="navbarDropdown4">
                            <div class="bf-user-card">
                                <x-admin.avatar :user="$currentUser" size="lg" />
                                <div>
                                    <strong>{{ $currentUser?->name ?? 'Administrateur' }}</strong>
                                    <span>{{ $currentUser?->email ?? '' }}</span>
                                </div>
                            </div>
                            <div class="bf-user-links">
                                <a class="dropdown-item d-flex align-items-center" href="{{ route('admin.users.index') }}">
                                    <i class="ti ti-user" aria-hidden="true"></i>
                                    Mon profil
                                </a>
                                <a class="dropdown-item d-flex align-items-center" href="{{ route('admin.settings.index') }}">
                                    <i class="ti ti-settings" aria-hidden="true"></i>
                                    Paramètres
                                </a>
                                <div class="dropdown-divider"></div>
                                <a class="dropdown-item d-flex align-items-center bf-logout" href="#" onclick="event.preventDefault(); document.getElementById('logout-form').submit();">
                                    <i class="ti ti-power-off" aria-hidden="true"></i>
                                    Déconnexion
                                </a>
                                <form id="logout-form" action="{{ route('logout') }}" method="POST" class="d-none">@csrf</form>
                            </div>
                        </div>
                    </li>
                </ul>
            </div>
        </div>
    </nav>
</header>
