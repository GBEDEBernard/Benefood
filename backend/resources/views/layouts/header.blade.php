<!-- begin app-header -->
<header class="app-header top-bar" style="background-color: #FFFFFF; box-shadow: 0 1px 3px rgba(0,0,0,0.05);">
    <nav class="navbar navbar-expand-md">
        <div class="navbar-header d-flex align-items-center">
            <a href="javascript:void(0)" class="mobile-toggle"><i class="ti ti-align-right"></i></a>

            <!-- LOGO BÉNINFOOD -->
            <a class="navbar-brand d-flex align-items-center" href="{{ route('admin.dashboard') }}" style="text-decoration: none;">
                <!-- Logo Rond -->
                <img src="{{ asset('assets/img/logo.jpeg') }}"
                     class="img-fluid logo-desktop"
                     alt="BéninFood"
                     style="height: 45px; width: 45px; border-radius: 50%; object-fit: cover; border: 2px solid var(--benin-green); margin-right: 12px;" />

                <!-- Nom de la marque -->
                <div class="d-flex flex-column" style="line-height: 1.1;">
                    <span style="font-family: 'Roboto', sans-serif; font-weight: 700; font-size: 20px; color: var(--benin-green);">
                        Bénin<span style="color: var(--benin-orange);">Food</span>
                    </span>
                    <small style="font-size: 10px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 1px;">Back-office</small>
                </div>
            </a>
        </div>

        <div class="collapse navbar-collapse" id="navbarSupportedContent">
            <div class="navigation d-flex">
                <ul class="navbar-nav nav-left">
                    <li class="nav-item">
                        <a href="javascript:void(0)" class="nav-link sidebar-toggle">
                            <i class="ti ti-align-right" style="color: var(--text-dark);"></i>
                        </a>
                    </li>
                </ul>
                <ul class="navbar-nav nav-right ml-auto align-items-center">
                    <li class="nav-item mr-3">
                        <a class="nav-link" href="javascript:void(0)">
                            <i class="ti ti-bell" style="color: var(--text-dark); font-size: 20px;"></i>
                            <span class="notify">
                                <span class="blink" style="background-color: var(--benin-red);"></span>
                                <span class="dot" style="background-color: var(--benin-red);"></span>
                            </span>
                        </a>
                    </li>
                    <li class="nav-item dropdown user-profile">
                        <a href="javascript:void(0)" class="nav-link dropdown-toggle d-flex align-items-center" id="navbarDropdown4" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                            <img src="{{ asset('assets/img/avtar/02.jpg') }}" alt="Admin" style="height: 40px; width: 40px; border-radius: 50%; object-fit: cover;">
                            <span class="bg-success user-status" style="background-color: var(--benin-green) !important;"></span>
                        </a>
                        <div class="dropdown-menu animated fadeIn" aria-labelledby="navbarDropdown">
                            <div class="bg-gradient px-4 py-3" style="background: linear-gradient(135deg, var(--benin-green), var(--benin-orange));">
                                <div class="d-flex align-items-center justify-content-between">
                                    <div class="mr-1">
                                        @auth
                                            <h4 class="text-white mb-0" style="font-size: 16px;">{{ Auth::user()->name }}</h4>
                                            <small class="text-white">{{ Auth::user()->email }}</small>
                                        @endauth
                                    </div>
                                    <a href="#" class="text-white font-20" onclick="event.preventDefault(); document.getElementById('logout-form').submit();">
                                        <i class="ti ti-power"></i>
                                    </a>
                                    <form id="logout-form" action="{{ route('logout') }}" method="POST" style="display:none">@csrf</form>
                                </div>
                            </div>
                            <div class="p-4">
                                <a class="dropdown-item d-flex nav-link" href="javascript:void(0)">
                                    <i class="fa fa-user pr-2" style="color: var(--benin-green);"></i> Mon profil
                                </a>
                                <a class="dropdown-item d-flex nav-link" href="javascript:void(0)">
                                    <i class="ti ti-settings pr-2" style="color: var(--benin-orange);"></i> Paramètres
                                </a>
                                <div class="dropdown-divider"></div>
                                <a class="dropdown-item d-flex nav-link" href="#" onclick="event.preventDefault(); document.getElementById('logout-form').submit();">
                                    <i class="fa fa-power-off pr-2" style="color: var(--benin-red);"></i> Déconnexion
                                </a>
                            </div>
                        </div>
                    </li>
                </ul>
            </div>
        </div>
    </nav>
</header>
<!-- end app-header -->
