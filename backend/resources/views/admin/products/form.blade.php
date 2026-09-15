@extends('layouts.app')

@section('content')
<x-admin.page-header title="{{ $product ? 'Modifier le produit' : 'Nouveau produit' }}" subtitle="Phase 08 — Catalogue produits">
    <a href="{{ route('admin.products.index') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
        <i class="ti ti-arrow-left"></i> Retour aux produits
    </a>
</x-admin.page-header>

@if ($errors->any())
    <div class="alert alert-danger alert-dismissible fade show" role="alert">
        <strong>Veuillez corriger les erreurs suivantes :</strong>
        <ul class="mb-0 mt-1">
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-4">
        <form method="POST" action="{{ $product ? route('admin.products.update', $product) : route('admin.products.store') }}" enctype="multipart/form-data">
            @csrf
            @if ($product)
                @method('PUT')
            @endif

            <div class="row">
                <div class="col-md-6">
                    <div class="form-group">
                        <label style="color: var(--text-dark); font-weight: 600;">Boutique <span style="color: var(--benin-red);">*</span></label>
                        <select name="vendor_id" class="form-control" {{ $product ? 'disabled' : 'required' }}>
                            <option value="">— Sélectionner une boutique —</option>
                            @foreach ($vendors as $vendor)
                                <option value="{{ $vendor->id }}"
                                    {{ ($product ? $product->vendor_id : (old('vendor_id') ?? request('vendor_id'))) === $vendor->id ? 'selected' : '' }}>
                                    {{ $vendor->business_name }}
                                </option>
                            @endforeach
                        </select>
                        @if ($product)
                            <input type="hidden" name="vendor_id" value="{{ $product->vendor_id }}">
                        @endif
                    </div>

                    <div class="form-group">
                        <label style="color: var(--text-dark); font-weight: 600;">Catégorie <span style="color: var(--benin-red);">*</span></label>
                        <select name="category_id" class="form-control" required>
                            <option value="">— Sélectionner une catégorie —</option>
                            @foreach ($categories as $category)
                                <option value="{{ $category->id }}"
                                    {{ old('category_id', $product?->category_id) === $category->id ? 'selected' : '' }}>
                                    {{ $category->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <div class="form-group">
                        <label style="color: var(--text-dark); font-weight: 600;">Nom du produit <span style="color: var(--benin-red);">*</span></label>
                        <input type="text" name="name" class="form-control" required maxlength="255"
                               value="{{ old('name', $product?->name) }}" placeholder="Ex. Poulet braisé + riz">
                    </div>

                    <div class="form-group">
                        <label style="color: var(--text-dark); font-weight: 600;">Description</label>
                        <textarea name="description" class="form-control" rows="3" placeholder="Courte description du produit">{{ old('description', $product?->description) }}</textarea>
                    </div>
                </div>

                <div class="col-md-6">
                    <div class="form-group">
                        <label style="color: var(--text-dark); font-weight: 600;">Prix (FCFA) <span style="color: var(--benin-red);">*</span></label>
                        <input type="number" name="price" class="form-control" required min="0" step="1"
                               value="{{ old('price', $product?->price) }}" placeholder="Ex. 2500">
                        <small style="color: var(--text-muted);">Montant en FCFA (valeur entière).</small>
                    </div>

                    <div class="form-group">
                        <label style="color: var(--text-dark); font-weight: 600;">Unité</label>
                        <input type="text" name="unit" class="form-control" maxlength="20"
                               value="{{ old('unit', $product?->unit ?? 'unit') }}" placeholder="pièce, plat, kg, pack...">
                    </div>

                    <div class="form-group">
                        <label style="color: var(--text-dark); font-weight: 600;">Stock (quantité journalière)</label>
                        <input type="number" name="stock_qty" class="form-control" min="0" step="1"
                               value="{{ old('stock_qty', $product?->stock_qty ?? '') }}" placeholder="Vide = illimité">
                        <small style="color: var(--text-muted);">0 ou vide : produit non commandable (rupture de stock).</small>
                    </div>

                    <div class="form-group">
                        <label style="color: var(--text-dark); font-weight: 600;">Photo principale</label>
                        <input type="file" name="image" class="form-control-file" accept="image/jpeg,image/png,image/webp">
                        <small style="color: var(--text-muted);">JPG, PNG ou WebP — 5 Mo max. Redimensionnée en 800×800 (WebP).</small>
                    </div>

                    <div class="form-group">
                        <div class="custom-control custom-switch">
                            <input type="checkbox" name="is_active" value="1" class="custom-control-input" id="is_active"
                                   {{ old('is_active', $product?->is_active ?? true) ? 'checked' : '' }}>
                            <label class="custom-control-label" for="is_active" style="color: var(--text-dark); font-weight: 600;">Produit actif</label>
                        </div>
                    </div>
                </div>
            </div>

            @if ($product && $product->images->isNotEmpty())
                <div class="row mt-2">
                    <div class="col-12">
                        <label style="color: var(--text-dark); font-weight: 600;">Photos actuelles</label>
                        <div class="d-flex flex-wrap" style="gap: 12px;">
                            @foreach ($product->images as $image)
                                <div style="position: relative; width: 96px; height: 96px; border-radius: 10px; overflow: hidden; background: #F1F5F9; border: 2px solid {{ $image->is_main ? 'var(--benin-green)' : 'transparent' }};">
                                    <img src="{{ \Illuminate\Support\Facades\Storage::disk('public')->url($image->path) }}" alt="" style="width: 96px; height: 96px; object-fit: cover;">
                                    @if ($image->is_main)
                                        <span style="position: absolute; left: 4px; top: 4px; background: var(--benin-green); color: #FFF; border-radius: 10px; padding: 1px 8px; font-size: 10px; font-weight: 700;">Principale</span>
                                    @endif
                                    <a href="{{ route('admin.products.images.destroy', [$product, $image]) }}"
                                       onclick="event.preventDefault(); if (confirm('Supprimer cette photo ?')) document.getElementById('delete-image-{{ $image->id }}').submit();"
                                       style="position: absolute; right: 4px; top: 4px; background: var(--benin-red); color: #FFF; border-radius: 50%; width: 22px; height: 22px; display: flex; align-items: center; justify-content: center; text-decoration: none;">
                                        <i class="ti ti-x" style="font-size: 12px;"></i>
                                    </a>
                                    <form id="delete-image-{{ $image->id }}" method="POST" action="{{ route('admin.products.images.destroy', [$product, $image]) }}" class="d-none">
                                        @csrf
                                        @method('DELETE')
                                    </form>
                                </div>
                            @endforeach
                        </div>
                    </div>
                </div>
            @endif

            <div class="mt-4">
                <button type="submit" class="btn" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                    <i class="ti ti-check"></i> {{ $product ? 'Enregistrer les modifications' : 'Créer le produit' }}
                </button>
                <a href="{{ route('admin.products.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                    Annuler
                </a>
            </div>
        </form>
    </div>
</div>
@endsection