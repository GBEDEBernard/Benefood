@extends('layouts.app')

@section('content')
<x-admin.page-header title="Produits" subtitle="Phase 08 — Catalogue, disponibilité, prix">
    <div class="d-flex" style="gap: 8px;">
        <a href="{{ route('admin.categories.index') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
            <i class="ti ti-folder"></i> Catégories
        </a>
        <a href="{{ route('admin.products.create') }}" class="btn btn-sm" style="background-color: var(--benin-orange); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
            <i class="ti ti-plus"></i> Nouveau produit
        </a>
    </div>
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
                <a class="btn btn-sm" href="{{ route('admin.products.index', array_merge(['q' => $filters['q'] ?? null], ['category_id' => $filters['category_id'] ?? null])) }}"
                   style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === '' ? 'background-color: var(--benin-green); color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                    Tous <span class="ml-1" style="font-weight: 700;">{{ $counts['all'] }}</span>
                </a>
            </li>
            <li class="nav-item">
                <a class="btn btn-sm" href="{{ route('admin.products.index', array_merge(['status' => 'active', 'q' => $filters['q'] ?? null])) }}"
                   style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === 'active' ? 'background-color: var(--benin-green); color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                    Actifs <span class="ml-1" style="font-weight: 700;">{{ $counts['active'] }}</span>
                </a>
            </li>
            <li class="nav-item">
                <a class="btn btn-sm" href="{{ route('admin.products.index', array_merge(['status' => 'inactive', 'q' => $filters['q'] ?? null])) }}"
                   style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === 'inactive' ? 'background: var(--text-dark); color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                    Inactifs <span class="ml-1" style="font-weight: 700;">{{ $counts['inactive'] }}</span>
                </a>
            </li>
            <li class="nav-item">
                <a class="btn btn-sm" href="{{ route('admin.products.index', array_merge(['availability' => 'out', 'q' => $filters['q'] ?? null])) }}"
                   style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['availability'] ?? '') === 'out' ? 'background-color: var(--benin-red); color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                    En rupture <span class="ml-1" style="font-weight: 700;">{{ $counts['out_of_stock'] }}</span>
                </a>
            </li>
        </ul>
    </div>
</div>

<!-- Search & filters -->
<form method="GET" action="{{ route('admin.products.index') }}">
    @if (! empty($filters['status']))
        <input type="hidden" name="status" value="{{ $filters['status'] }}">
    @endif
    @if (! empty($filters['availability']))
        <input type="hidden" name="availability" value="{{ $filters['availability'] }}">
    @endif
    <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body py-3">
            <div class="row align-items-center">
                <div class="col-md-4">
                    <input type="text" name="q" value="{{ $filters['q'] ?? '' }}" class="form-control" placeholder="Rechercher un produit ou une boutique...">
                </div>
                <div class="col-md-3">
                    <select name="category_id" class="form-control">
                        <option value="">Toutes les catégories</option>
                        @foreach ($categories as $category)
                            <option value="{{ $category->id }}" {{ ($filters['category_id'] ?? '') === $category->id ? 'selected' : '' }}>
                                {{ $category->name }}
                            </option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-2">
                    <select name="vendor_id" class="form-control">
                        <option value="">Toutes les boutiques</option>
                        @foreach ($vendors as $vendor)
                            <option value="{{ $vendor->id }}" {{ ($filters['vendor_id'] ?? '') === $vendor->id ? 'selected' : '' }}>
                                {{ $vendor->business_name }}
                            </option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-3 d-flex">
                    <button type="submit" class="btn mr-2" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-search"></i> Filtrer
                    </button>
                    <a href="{{ route('admin.products.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
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
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Produit</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Boutique</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Catégorie</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Prix</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Stock</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($products as $product)
                        <tr>
                            <td class="py-3">
                                <div class="d-flex align-items-center" style="gap: 12px;">
                                    <div style="width: 44px; height: 44px; border-radius: 8px; overflow: hidden; background: #F1F5F9; flex-shrink: 0;">
                                        @if ($product->image_main)
                                            <img src="{{ \Illuminate\Support\Facades\Storage::disk('public')->url($product->image_main) }}" alt="" style="width: 44px; height: 44px; object-fit: cover;">
                                        @else
                                            <div class="d-flex align-items-center justify-content-center h-100" style="color: var(--text-muted);"><i class="ti ti-photo"></i></div>
                                        @endif
                                    </div>
                                    <div>
                                        <div style="color: var(--text-dark); font-weight: 600;">{{ $product->name }}</div>
                                        <small style="color: var(--text-muted);">{{ \Illuminate\Support\Str::limit($product->description ?? '', 40) }}</small>
                                    </div>
                                </div>
                            </td>
                            <td class="py-3" style="color: var(--text-dark);">{{ $product->vendor?->business_name ?? '—' }}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $product->category?->name ?? '—' }}</td>
                            <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ \App\Support\AdminLabels::priceLabel($product->price) }}</td>
                            <td class="py-3">{!! \App\Support\AdminLabels::stockBadge($product->stock_qty, $product->is_available) !!}</td>
                            <td class="py-3">{!! \App\Support\AdminLabels::productStatusBadge($product->is_active) !!}</td>
                            <td class="py-3 text-right">
                                <a href="{{ route('admin.products.show', $product) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                    <i class="ti ti-eye"></i> Voir
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="7" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-package" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucun produit trouvé.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($products->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $products->links() }}
        </div>
    @endif
</div>
@endsection