@extends('layouts.app')

@section('content')
<x-admin.page-header title="Détail produit" :subtitle="$product->name" :back="route('admin.products.index')">
    <div class="d-flex align-items-center" style="gap: 8px;">
        {!! \App\Support\AdminLabels::productStatusBadge($product->is_active) !!}
        {!! \App\Support\AdminLabels::stockBadge($product->stock_qty, $product->is_available) !!}

        <a href="{{ route('admin.products.edit', $product) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
            <i class="ti ti-pencil"></i> Modifier
        </a>

        <form method="POST" action="{{ route('admin.products.active', $product) }}" onsubmit="return confirm('{{ $product->is_active ? 'Désactiver' : 'Activer' }} ce produit ?');">
            @csrf
            <button type="submit" class="btn btn-sm" style="background-color: {{ $product->is_active ? 'var(--benin-orange)' : 'var(--benin-green)' }}; color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                <i class="ti ti-power"></i> {{ $product->is_active ? 'Désactiver' : 'Activer' }}
            </button>
        </form>

        <button class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);" data-toggle="modal" data-target="#availability-modal">
            <i class="ti ti-box"></i> Stock & disponibilité
        </button>

        <form method="POST" action="{{ route('admin.products.destroy', $product) }}" onsubmit="return confirm('Désactiver ce produit (sans suppression) ?');">
            @csrf
            @method('DELETE')
            <button type="submit" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--benin-red);" {{ $product->is_active ? '' : 'disabled' }}>
                <i class="ti ti-trash"></i>
            </button>
        </form>
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

<!-- Tabs -->
<ul class="nav nav-tabs mb-4" role="tablist" style="border-bottom-color: var(--border-color);">
    <li class="nav-item">
        <a class="nav-link active" id="infos-tab" data-toggle="tab" href="#infos" role="tab" style="color: var(--text-dark); font-weight: 600;">
            <i class="ti ti-info-alt mr-1"></i> Informations
        </a>
    </li>
    <li class="nav-item">
        <a class="nav-link" id="photos-tab" data-toggle="tab" href="#photos" role="tab" style="color: var(--text-muted); font-weight: 600;">
            <i class="ti ti-photo mr-1"></i> Photos
        </a>
    </li>
    <li class="nav-item">
        <a class="nav-link" id="prices-tab" data-toggle="tab" href="#prices" role="tab" style="color: var(--text-muted); font-weight: 600;">
            <i class="ti ti-currency-frank mr-1"></i> Historique des prix
        </a>
    </li>
    <li class="nav-item">
        <a class="nav-link" id="stock-tab" data-toggle="tab" href="#stock" role="tab" style="color: var(--text-muted); font-weight: 600;">
            <i class="ti ti-box mr-1"></i> Stock
        </a>
    </li>
</ul>

<div class="tab-content">
    <!-- ========== INFOS ========== -->
    <div class="tab-pane fade show active" id="infos" role="tabpanel">
        <div class="row">
            <div class="col-lg-6 mb-4">
                <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                    <div class="card-header" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                        <h6 class="mb-0" style="color: var(--text-dark); font-weight: 700;">Produit</h6>
                    </div>
                    <div class="card-body">
                        <table class="table table-borderless mb-0" style="color: var(--text-dark);">
                            <tr>
                                <td style="color: var(--text-muted); width: 190px;">Image principale</td>
                                <td>
                                    @if ($product->image_main)
                                        <img src="{{ \Illuminate\Support\Facades\Storage::disk('public')->url($product->image_main) }}" alt="" style="width: 72px; height: 72px; border-radius: 10px; object-fit: cover;">
                                    @else
                                        — 
                                    @endif
                                </td>
                            </tr>
                            <tr><td style="color: var(--text-muted);">Nom</td><td style="font-weight: 600;">{{ $product->name }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Description</td><td>{{ $product->description ?? '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Catégorie</td><td>{{ $product->category?->name ?? '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Prix</td><td style="font-weight: 600;">{{ \App\Support\AdminLabels::priceLabel($product->price) }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Unité</td><td>{{ $product->unit }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Statut</td><td>{!! \App\Support\AdminLabels::productStatusBadge($product->is_active) !!} </td></tr>
                            <tr><td style="color: var(--text-muted);">Disponibilité</td><td>{!! \App\Support\AdminLabels::stockBadge($product->stock_qty, $product->is_available) !!}</td></tr>
                            <tr><td style="color: var(--text-muted);">Créé le</td><td>{{ $product->created_at?->format('d/m/Y H:i') }}</td></tr>
                        </table>
                    </div>
                </div>
            </div>
            <div class="col-lg-6 mb-4">
                <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                    <div class="card-header" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                        <h6 class="mb-0" style="color: var(--text-dark); font-weight: 700;">Boutique</h6>
                    </div>
                    <div class="card-body">
                        <table class="table table-borderless mb-0" style="color: var(--text-dark);">
                            <tr><td style="color: var(--text-muted); width: 190px;">Boutique</td><td style="font-weight: 600;">{{ $product->vendor?->business_name ?? '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Responsable</td><td>{{ $product->vendor?->user?->name ?? '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Ville</td><td>{{ $product->vendor?->city ?? '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Contact</td><td>{{ $product->vendor?->phone ?? '—' }}</td></tr>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- ========== PHOTOS ========== -->
    <div class="tab-pane fade" id="photos" role="tabpanel">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-header" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                <div class="d-flex justify-content-between align-items-center">
                    <h6 class="mb-0" style="color: var(--text-dark); font-weight: 700;">Galerie produit</h6>
                    <form method="POST" action="{{ route('admin.products.images.store', $product) }}" enctype="multipart/form-data">
                        @csrf
                        <div class="d-flex" style="gap: 8px;">
                            <input type="file" name="image" class="form-control form-control-sm" required accept="image/jpeg,image/png,image/webp">
                            <button type="submit" class="btn btn-sm" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                                <i class="ti ti-upload"></i> Ajouter
                            </button>
                        </div>
                    </form>
                </div>
            </div>
            <div class="card-body">
                <div class="d-flex flex-wrap" style="gap: 12px;">
                    @forelse ($product->images as $image)
                        <div style="position: relative; width: 160px; height: 160px; border-radius: 10px; overflow: hidden; background: #F1F5F9; border: 2px solid {{ $image->is_main ? 'var(--benin-green)' : 'transparent' }};">
                            <img src="{{ \Illuminate\Support\Facades\Storage::disk('public')->url($image->path) }}" alt="" style="width: 160px; height: 160px; object-fit: cover;">
                            @if ($image->is_main)
                                <span style="position: absolute; left: 6px; top: 6px; background: var(--benin-green); color: #FFF; border-radius: 10px; padding: 2px 10px; font-size: 11px; font-weight: 700;">Principale</span>
                            @endif
                            <a href="{{ route('admin.products.images.destroy', [$product, $image]) }}"
                               onclick="event.preventDefault(); if (confirm('Supprimer cette photo ?')) document.getElementById('del-img-{{ $image->id }}').submit();"
                               style="position: absolute; right: 6px; top: 6px; background: var(--benin-red); color: #FFF; border-radius: 50%; width: 26px; height: 26px; display: flex; align-items: center; justify-content: center; text-decoration: none;">
                                <i class="ti ti-trash" style="font-size: 13px;"></i>
                            </a>
                            <form id="del-img-{{ $image->id }}" method="POST" action="{{ route('admin.products.images.destroy', [$product, $image]) }}" class="d-none">
                                @csrf
                                @method('DELETE')
                            </form>
                        </div>
                    @empty
                        <div class="text-center py-4 w-100" style="color: var(--text-muted);">
                            <i class="ti ti-photo" style="font-size: 40px;"></i>
                            <p class="mt-2 mb-0">Aucune photo — ajoutez une image (JPG, PNG, WebP, 5 Mo max).</p>
                        </div>
                    @endforelse
                </div>
            </div>
        </div>
    </div>

    <!-- ========== HISTORIQUE PRIX ========== -->
    <div class="tab-pane fade" id="prices" role="tabpanel">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-hover mb-0">
                        <thead style="background-color: #F9FAFB;">
                            <tr>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Ancien prix</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Nouveau prix</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Modifié par</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Date</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($product->priceHistory as $entry)
                                <tr>
                                    <td class="py-3" style="color: var(--text-muted);">{{ \App\Support\AdminLabels::priceLabel($entry->old_price) }}</td>
                                    <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ \App\Support\AdminLabels::priceLabel($entry->new_price) }}</td>
                                    <td class="py-3" style="color: var(--text-muted);">{{ $entry->changedBy?->name ?? ($entry->changed_by === auth()->id() ? 'Vous' : '—') }}</td>
                                    <td class="py-3" style="color: var(--text-muted);">{{ $entry->changed_at?->format('d/m/Y H:i') }}</td>
                                </tr>
                            @empty
                                <tr><td colspan="4" class="text-center py-5" style="color: var(--text-muted);">Aucun changement de prix enregistré.</td></tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <!-- ========== STOCK ========== -->
    <div class="tab-pane fade" id="stock" role="tabpanel">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-hover mb-0">
                        <thead style="background-color: #F9FAFB;">
                            <tr>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Variation</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Stock après</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Raison</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Date</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($product->stockLogs as $log)
                                <tr>
                                    <td class="py-3" style="color: {{ $log->delta >= 0 ? 'var(--benin-green)' : 'var(--benin-red)' }}; font-weight: 600;">
                                        {{ $log->delta >= 0 ? '+' : '' }}{{ $log->delta }}
                                    </td>
                                    <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ $log->qty_after }}</td>
                                    <td class="py-3" style="color: var(--text-muted);">{{ ucfirst($log->reason) }}</td>
                                    <td class="py-3" style="color: var(--text-muted);">{{ $log->created_at?->format('d/m/Y H:i') }}</td>
                                </tr>
                            @empty
                                <tr><td colspan="4" class="text-center py-5" style="color: var(--text-muted);">Aucun mouvement de stock.</td></tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- ===== MODAL DISPONIBILITÉ ===== -->
<div class="modal fade" id="availability-modal" tabindex="-1" role="dialog" aria-labelledby="availability-modal-label" aria-hidden="true">
    <div class="modal-dialog" role="document">
        <div class="modal-content" style="border-radius: 12px; border: none;">
            <div class="modal-header" style="border-bottom: 1px solid var(--border-color);">
                <h5 class="modal-title" id="availability-modal-label" style="color: var(--text-dark); font-weight: 700;">Stock & disponibilité</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
            </div>
            <form method="POST" action="{{ route('admin.products.availability', $product) }}">
                @csrf
                <div class="modal-body">
                    <div class="form-group">
                        <label style="color: var(--text-dark); font-weight: 600;">Disponible à la vente</label>
                        <select name="is_available" class="form-control" required>
                            <option value="1" {{ $product->is_available ? 'selected' : '' }}>Oui</option>
                            <option value="0" {{ ! $product->is_available ? 'selected' : '' }}>Non</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label style="color: var(--text-dark); font-weight: 600;">Quantité en stock</label>
                        <input type="number" name="stock_qty" class="form-control" min="0" step="1" value="{{ $product->stock_qty ?? '' }}" placeholder="Vide = illimité">
                        <small style="color: var(--text-muted);">À 0, le produit passe automatiquement hors stock.</small>
                    </div>
                </div>
                <div class="modal-footer" style="border-top: 1px solid var(--border-color);">
                    <button type="button" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);" data-dismiss="modal">Annuler</button>
                    <button type="submit" class="btn" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-check"></i> Enregistrer
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>
@endsection