@extends('layouts.app')

@section('content')
<x-admin.page-header title="Vendeurs" subtitle="Phase 07 — Validation, suspension, activation">
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

<!-- Status tabs -->
<div class="row mb-4">
    <div class="col-12">
        <ul class="nav" style="gap: 8px; flex-wrap: wrap; list-style: none; padding: 0; margin: 0;">
            <li class="nav-item">
                <a class="btn btn-sm {{ ($filters['status'] ?? '') === '' ? '' : '' }}" href="{{ route('admin.vendors.index', array_merge(['q' => $filters['q'] ?? null])) }}"
                   style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === '' ? 'background-color: var(--benin-green); color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                    Tous <span class="ml-1" style="font-weight: 700;">{{ $counts['all'] }}</span>
                </a>
            </li>
            <li class="nav-item">
                <a class="btn btn-sm" href="{{ route('admin.vendors.index', array_merge(['status' => 'pending_verification', 'q' => $filters['q'] ?? null])) }}"
                   style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === 'pending_verification' ? 'background-color: var(--benin-orange); color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                    En attente <span class="ml-1" style="font-weight: 700;">{{ $counts['pending_verification'] }}</span>
                </a>
            </li>
            <li class="nav-item">
                <a class="btn btn-sm" href="{{ route('admin.vendors.index', array_merge(['status' => 'active', 'q' => $filters['q'] ?? null])) }}"
                   style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === 'active' ? 'background-color: var(--benin-green); color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                    Actifs <span class="ml-1" style="font-weight: 700;">{{ $counts['active'] }}</span>
                </a>
            </li>
            <li class="nav-item">
                <a class="btn btn-sm" href="{{ route('admin.vendors.index', array_merge(['status' => 'suspended', 'q' => $filters['q'] ?? null])) }}"
                   style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === 'suspended' ? 'background-color: var(--benin-red); color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                    Suspendus <span class="ml-1" style="font-weight: 700;">{{ $counts['suspended'] }}</span>
                </a>
            </li>
            <li class="nav-item">
                <a class="btn btn-sm" href="{{ route('admin.vendors.index', array_merge(['status' => 'closed', 'q' => $filters['q'] ?? null])) }}"
                   style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === 'closed' ? 'background-color: var(--text-dark); color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                    Fermés <span class="ml-1" style="font-weight: 700;">{{ $counts['closed'] }}</span>
                </a>
            </li>
        </ul>
    </div>
</div>

<!-- Search -->
<form method="GET" action="{{ route('admin.vendors.index') }}">
    @if (! empty($filters['status']))
        <input type="hidden" name="status" value="{{ $filters['status'] }}">
    @endif
    <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body py-3">
            <div class="row align-items-center">
                <div class="col-md-8">
                    <input type="text" name="q" value="{{ $filters['q'] ?? '' }}" class="form-control" placeholder="Rechercher par nom, IFU, ville, propriétaire...">
                </div>
                <div class="col-md-4 d-flex">
                    <button type="submit" class="btn mr-2" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-search"></i> Filtrer
                    </button>
                    <a href="{{ route('admin.vendors.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                        Réinitialiser
                    </a>
                </div>
            </div>
        </div>
    </div>
</form>

<!-- Table -->
<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover mb-0">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Boutique</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">IFU</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Ville</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Responsable</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Produits</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Créé le</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($vendors as $vendor)
                        <tr>
                            <td class="py-3">
                                <div>
                                    <div style="color: var(--text-dark); font-weight: 600;">{{ $vendor->business_name }}</div>
                                    @if ($vendor->legal_name)
                                        <small style="color: var(--text-muted);">{{ $vendor->legal_name }}</small>
                                    @endif
                                </div>
                            </td>
                            <td class="py-3" style="color: var(--text-muted); font-family: monospace;">{{ $vendor->ifu ?? '—' }}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $vendor->city ?? '—' }}</td>
                            <td class="py-3" style="color: var(--text-dark);">{{ $vendor->user?->name ?? '—' }}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $vendor->products->count() }}</td>
                            <td class="py-3">{!! \App\Support\AdminLabels::vendorStatusBadge($vendor->status) !!}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $vendor->created_at?->format('d/m/Y') ?? '—' }}</td>
                            <td class="py-3 text-right">
                                <a href="{{ route('admin.vendors.show', $vendor) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                    <i class="ti ti-eye"></i> Voir
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="8" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-briefcase" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucun vendeur trouvé.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($vendors->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $vendors->links() }}
        </div>
    @endif
</div>
@endsection