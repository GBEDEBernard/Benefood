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

<!-- begin KPI Cards -->
<div class="row">
    <!-- Carte Vendeurs (Vert) -->
    <div class="col-md-6 col-xl-3">
        <div class="card card-statistics h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <div class="d-flex align-items-center justify-content-between">
                    <div>
                        <p class="mb-0 font-weight-bold text-muted" style="color: var(--text-muted) !important;">Vendeurs actifs</p>
                        <h3 class="mt-2 mb-0" style="color: var(--text-dark); font-weight: 700;">{{ $vendors ?? 0 }}</h3>
                    </div>
                    <div class="icon-box rounded-circle d-flex align-items-center justify-content-center" style="background-color: #E8F5E9; width: 50px; height: 50px;">
                        <i class="ti ti-briefcase" style="color: var(--benin-green); font-size: 24px;"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Carte Produits (Orange) -->
    <div class="col-md-6 col-xl-3">
        <div class="card card-statistics h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <div class="d-flex align-items-center justify-content-between">
                    <div>
                        <p class="mb-0 font-weight-bold text-muted" style="color: var(--text-muted) !important;">Produits</p>
                        <h3 class="mt-2 mb-0" style="color: var(--text-dark); font-weight: 700;">{{ $products ?? 0 }}</h3>
                    </div>
                    <div class="icon-box rounded-circle d-flex align-items-center justify-content-center" style="background-color: #FFF3E0; width: 50px; height: 50px;">
                        <i class="ti ti-shopping-cart" style="color: var(--benin-orange); font-size: 24px;"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Carte Utilisateurs (Rouge) -->
    <div class="col-md-6 col-xl-3">
        <div class="card card-statistics h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <div class="d-flex align-items-center justify-content-between">
                    <div>
                        <p class="mb-0 font-weight-bold text-muted" style="color: var(--text-muted) !important;">Utilisateurs</p>
                        <h3 class="mt-2 mb-0" style="color: var(--text-dark); font-weight: 700;">{{ $users ?? 0 }}</h3>
                    </div>
                    <div class="icon-box rounded-circle d-flex align-items-center justify-content-center" style="background-color: #FFEBEE; width: 50px; height: 50px;">
                        <i class="ti ti-user" style="color: var(--benin-red); font-size: 24px;"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Carte Zones (Vert Foncé / Neutre) -->
    <div class="col-md-6 col-xl-3">
        <div class="card card-statistics h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <div class="d-flex align-items-center justify-content-between">
                    <div>
                        <p class="mb-0 font-weight-bold text-muted" style="color: var(--text-muted) !important;">Zones de livraison</p>
                        <h3 class="mt-2 mb-0" style="color: var(--text-dark); font-weight: 700;">{{ $zones ?? 0 }}</h3>
                    </div>
                    <div class="icon-box rounded-circle d-flex align-items-center justify-content-center" style="background-color: #F4F6F8; width: 50px; height: 50px;">
                        <i class="ti ti-map-alt" style="color: var(--text-dark); font-size: 24px;"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
<!-- end KPI Cards -->

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