@php
    $currentPage = $orders->currentPage();
    $lastPage = $orders->lastPage();
    $startPage = max(1, $currentPage - 1);
    $endPage = min($lastPage, $currentPage + 1);
    $pageUrls = $orders->getUrlRange($startPage, $endPage);
    $formatCount = fn (int $count): string => number_format($count, 0, ',', ' ');
@endphp

<footer class="orders-pagination">
    <div class="orders-pagination__summary">
        <span>
            Affichage de <strong>{{ $formatCount($orders->firstItem()) }}</strong>
            à <strong>{{ $formatCount($orders->lastItem()) }}</strong>
            sur <strong>{{ $formatCount($orders->total()) }}</strong> commande{{ $orders->total() > 1 ? 's' : '' }}
        </span>
        <span class="orders-pagination__page">Page {{ $currentPage }} sur {{ $lastPage }}</span>
    </div>

    <div class="orders-pagination__controls">
        <form method="GET" action="{{ route('admin.orders.index') }}" class="orders-page-size">
            @foreach (['q', 'status', 'vendor_id', 'from', 'to'] as $filterKey)
                @if (! empty($filters[$filterKey]))
                    <input type="hidden" name="{{ $filterKey }}" value="{{ $filters[$filterKey] }}">
                @endif
            @endforeach
            <label for="orders-per-page">Par page</label>
            <span class="orders-page-size__select">
                <select id="orders-per-page" name="per_page" data-orders-page-size>
                    @foreach ([10, 20, 50] as $option)
                        <option value="{{ $option }}" @selected((int) ($filters['per_page'] ?? 20) === $option)>{{ $option }}</option>
                    @endforeach
                </select>
                <i class="ti ti-chevron-down" aria-hidden="true"></i>
            </span>
            <button type="submit" class="orders-page-size__apply" aria-label="Appliquer le nombre de lignes">
                <i class="ti ti-check" aria-hidden="true"></i>
            </button>
        </form>

        @if ($orders->hasPages())
            <nav class="orders-page-nav" aria-label="Pagination des commandes">
                @if ($orders->onFirstPage())
                    <span class="orders-page-btn is-disabled" aria-disabled="true">
                        <i class="ti ti-chevron-left" aria-hidden="true"></i>
                    </span>
                @else
                    <a href="{{ $orders->previousPageUrl() }}" class="orders-page-btn" rel="prev" aria-label="Page précédente">
                        <i class="ti ti-chevron-left" aria-hidden="true"></i>
                    </a>
                @endif

                @if ($startPage > 1)
                    <a href="{{ $orders->url(1) }}" class="orders-page-btn" aria-label="Page 1">1</a>
                    @if ($startPage > 2)
                        <span class="orders-page-ellipsis" aria-hidden="true">…</span>
                    @endif
                @endif

                @foreach ($pageUrls as $page => $url)
                    @if ($page === $currentPage)
                        <span class="orders-page-btn is-current" aria-current="page">{{ $page }}</span>
                    @else
                        <a href="{{ $url }}" class="orders-page-btn" aria-label="Page {{ $page }}">{{ $page }}</a>
                    @endif
                @endforeach

                @if ($endPage < $lastPage)
                    @if ($endPage < $lastPage - 1)
                        <span class="orders-page-ellipsis" aria-hidden="true">…</span>
                    @endif
                    <a href="{{ $orders->url($lastPage) }}" class="orders-page-btn" aria-label="Page {{ $lastPage }}">{{ $lastPage }}</a>
                @endif

                @if ($orders->hasMorePages())
                    <a href="{{ $orders->nextPageUrl() }}" class="orders-page-btn" rel="next" aria-label="Page suivante">
                        <i class="ti ti-chevron-right" aria-hidden="true"></i>
                    </a>
                @else
                    <span class="orders-page-btn is-disabled" aria-disabled="true">
                        <i class="ti ti-chevron-right" aria-hidden="true"></i>
                    </span>
                @endif
            </nav>
        @endif
    </div>
</footer>
