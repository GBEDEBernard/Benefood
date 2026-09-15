@extends('layouts.app')

@section('content')
<x-admin.page-header
    :title="$category ? 'Modifier la catégorie' : 'Nouvelle catégorie'"
    :subtitle="$category ? $category->name : 'Créer une catégorie ou sous-catégorie'"
    :back="route('admin.categories.index')">
</x-admin.page-header>

@if ($errors->any())
    <div class="alert alert-danger">
        <ul class="mb-0">
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
    </div>
@endif

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px; max-width: 720px;">
    <div class="card-body p-4">
        <form method="POST" action="{{ $category ? route('admin.categories.update', $category) : route('admin.categories.store') }}">
            @csrf
            @if ($category)
                @method('PUT')
            @endif

            <div class="form-group">
                <label for="name" style="color: var(--text-dark); font-weight: 600;">Nom *</label>
                <input type="text" id="name" name="name" class="form-control" required maxlength="255"
                       value="{{ old('name', $category?->name) }}" placeholder="Ex : Légumes">
            </div>

            <div class="form-group">
                <label for="parent_id" style="color: var(--text-dark); font-weight: 600;">Catégorie parente</label>
                <select id="parent_id" name="parent_id" class="form-control">
                    <option value="">— Aucune (catégorie racine) —</option>
                    @foreach ($parents as $parent)
                        <option value="{{ $parent->id }}" {{ old('parent_id', $category?->parent_id) === $parent->id ? 'selected' : '' }}>
                            {{ $parent->name }}
                        </option>
                    @endforeach
                </select>
                <small style="color: var(--text-muted);">Choisir une catégorie pour créer une sous-catégorie.</small>
            </div>

            <div class="form-group">
                <label for="icon_path" style="color: var(--text-dark); font-weight: 600;">Icône (URL)</label>
                <input type="text" id="icon_path" name="icon_path" class="form-control" maxlength="255"
                       value="{{ old('icon_path', $category?->icon_path) }}" placeholder="Ex : /icons/legumes.png">
            </div>

            <div class="form-group">
                <label for="sort_order" style="color: var(--text-dark); font-weight: 600;">Ordre d'affichage</label>
                <input type="number" id="sort_order" name="sort_order" class="form-control" min="0" step="1"
                       value="{{ old('sort_order', $category?->sort_order ?? 0) }}">
            </div>

            <div class="form-check mb-4">
                <input class="form-check-input" type="checkbox" id="is_active" name="is_active" value="1"
                       {{ old('is_active', $category?->is_active ?? true) ? 'checked' : '' }}>
                <label class="form-check-label" for="is_active" style="color: var(--text-dark); font-weight: 600;">
                    Catégorie active (visible dans le catalogue)
                </label>
            </div>

            <div class="d-flex" style="gap: 8px;">
                <button type="submit" class="btn" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                    <i class="ti ti-check"></i> {{ $category ? 'Enregistrer' : 'Créer la catégorie' }}
                </button>
                <a href="{{ route('admin.categories.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                    Annuler
                </a>
            </div>
        </form>
    </div>
</div>
@endsection