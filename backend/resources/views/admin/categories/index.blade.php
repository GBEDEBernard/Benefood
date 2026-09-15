@extends('layouts.app')

@section('content')
<x-admin.page-header title="Catégories" subtitle="Phase 08 — Arborescence du catalogue">
    <div class="d-flex" style="gap: 8px;">
        <a href="{{ route('admin.products.index') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
            <i class="ti ti-package"></i> Produits
        </a>
        <a href="{{ route('admin.categories.create') }}" class="btn btn-sm" style="background-color: var(--benin-orange); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
            <i class="ti ti-plus"></i> Nouvelle catégorie
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

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover mb-0">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Catégorie</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Catégorie parente</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Sous-catégories</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Produits</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Ordre</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($categories as $category)
                        <tr>
                            <td class="py-3">
                                <div style="color: var(--text-dark); font-weight: 600;">
                                    @if ($category->icon_path)
                                        <img src="{{ $category->icon_path }}" alt="" style="width: 20px; height: 20px; margin-right: 8px; vertical-align: middle;">
                                    @endif
                                    {{ $category->name }}
                                </div>
                                <small style="color: var(--text-muted);">/{{ $category->slug }}</small>
                            </td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $category->parent?->name ?? '—' }}</td>
                            <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ $category->children_count }}</td>
                            <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ $category->products_count }}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $category->sort_order }}</td>
                            <td class="py-3">{!! \App\Support\AdminLabels::categoryStatusBadge($category->is_active) !!}</td>
                            <td class="py-3 text-right">
                                <div class="d-flex justify-content-end" style="gap: 6px;">
                                    <a href="{{ route('admin.categories.edit', $category) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                        <i class="ti ti-pencil"></i>
                                    </a>
                                    <form method="POST" action="{{ route('admin.categories.destroy', $category) }}" class="d-inline"
                                          onsubmit="return confirm('Désactiver la catégorie « {{ $category->name }} » ?');">
                                        @csrf
                                        @method('DELETE')
                                        <button class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: {{ $category->is_active ? 'var(--benin-red)' : 'var(--text-muted)' }};"
                                                {{ $category->is_active ? '' : 'disabled' }}>
                                            <i class="ti ti-trash"></i>
                                        </button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="7" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-folder-open" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucune catégorie — créez-en une pour structurer le catalogue.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
</div>
@endsection