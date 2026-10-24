@props([
    'product' => null,
    'size' => 'md',
])

@php
    $name = $product?->name ?: 'Produit';
    $path = $product?->image_main;

    if ($product !== null && $product->relationLoaded('images')) {
        $primaryImage = $product->images->firstWhere('is_main', true) ?? $product->images->first();
        $path = $primaryImage?->path ?? $path;
    }

    $imageUrl = \App\Support\AdminMedia::url($path);
@endphp

<span {{ $attributes->class(['bf-product-thumb', 'bf-product-thumb--'.$size]) }}>
    @if ($imageUrl)
        <img src="{{ $imageUrl }}"
             alt="{{ $name }}"
             loading="lazy"
             decoding="async"
             onerror="this.hidden = true; this.parentElement.classList.add('is-empty');">
    @endif
    <span class="bf-product-thumb__fallback" aria-hidden="true">
        <i class="ti ti-package"></i>
    </span>
</span>
