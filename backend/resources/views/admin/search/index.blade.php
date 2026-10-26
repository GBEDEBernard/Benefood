@extends('layouts.app')

@section('content')
    <x-admin.page-header title="Recherche globale" subtitle="Pages, commandes, clients, boutiques et bien plus">
        <a href="{{ route('admin.dashboard') }}" class="btn btn-sm btn-light d-inline-flex align-items-center" style="gap: 8px; border: 1px solid var(--bf-border);">
            <i class="ti ti-arrow-left" aria-hidden="true"></i>
            Tableau de bord
        </a>
    </x-admin.page-header>

    <div class="card bf-search-page-card">
        <div class="card-body">
            <form class="bf-search-page-form" method="GET" action="{{ route('admin.search.index') }}" role="search">
                <div class="bf-search-page-field">
                    <i class="ti ti-search" aria-hidden="true"></i>
                    <input
                        type="search"
                        name="q"
                        value="{{ $query }}"
                        placeholder="Rechercher une page, une commande, un client, un produit..."
                        aria-label="Recherche globale"
                        autocomplete="off"
                        autofocus
                    >
                    @if ($query !== '')
                        <a href="{{ route('admin.search.index') }}" class="bf-search-page-clear" aria-label="Effacer la recherche">
                            <i class="ti ti-close" aria-hidden="true"></i>
                        </a>
                    @endif
                </div>
                <button type="submit" class="btn btn-primary">
                    <i class="ti ti-search" aria-hidden="true"></i>
                    Rechercher
                </button>
            </form>
            <p class="bf-search-page-hint">
                Astuce : utilisez <kbd>Ctrl</kbd> + <kbd>K</kbd> depuis n’importe quelle page du back-office.
            </p>
        </div>
    </div>

    @if ($query !== '' && mb_strlen($query) < 2)
        <div class="card bf-search-empty">
            <div class="card-body">
                <span class="bf-search-empty__icon"><i class="ti ti-search" aria-hidden="true"></i></span>
                <h2>Saisissez au moins 2 caractères</h2>
                <p>La recherche devient plus précise dès deux caractères.</p>
            </div>
        </div>
    @elseif ($groups === [])
        <div class="card bf-search-empty">
            <div class="card-body">
                <span class="bf-search-empty__icon"><i class="ti ti-search" aria-hidden="true"></i></span>
                <h2>Aucun résultat pour « {{ $query }} »</h2>
                <p>Essayez une référence, un nom, un téléphone, une ville ou le nom d’une page.</p>
            </div>
        </div>
    @else
        <div class="bf-search-page-grid">
            @foreach ($groups as $group)
                <section class="card bf-search-group" aria-labelledby="bf-search-group-{{ $group['key'] }}">
                    <div class="bf-search-group__head">
                        <span class="bf-search-group__icon">
                            <i class="ti {{ $group['icon'] }}" aria-hidden="true"></i>
                        </span>
                        <h2 id="bf-search-group-{{ $group['key'] }}">{{ $group['label'] }}</h2>
                        <span class="bf-search-group__count">{{ count($group['items']) }}</span>
                    </div>
                    <div class="bf-search-group__items">
                        @foreach ($group['items'] as $item)
                            <a href="{{ $item['url'] }}" class="bf-search-result">
                                <span class="bf-search-result__icon">
                                    <i class="ti {{ $item['icon'] }}" aria-hidden="true"></i>
                                </span>
                                <span class="bf-search-result__body">
                                    <strong>{{ $item['label'] }}</strong>
                                    @if ($item['description'] !== '')
                                        <small>{{ $item['description'] }}</small>
                                    @endif
                                </span>
                                <i class="ti ti-arrow-right bf-search-result__arrow" aria-hidden="true"></i>
                            </a>
                        @endforeach
                    </div>
                </section>
            @endforeach
        </div>
    @endif
@endsection
