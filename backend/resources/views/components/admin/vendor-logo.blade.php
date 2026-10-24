@props([
    'vendor' => null,
    'size' => 'md',
])

@php
    $displayName = $vendor?->business_name ?: 'Boutique';
    $logoUrl = \App\Support\AdminMedia::url($vendor?->logo_url);
    $initials = \App\Support\AdminMedia::initials($displayName);
    $tone = \App\Support\AdminMedia::tone($displayName);
@endphp

<span {{ $attributes->class(['bf-avatar', 'bf-avatar--vendor', 'bf-avatar--'.$size, 'bf-avatar--'.$tone]) }}>
    <span class="bf-avatar__initials" aria-hidden="true">{{ $initials }}</span>
    @if ($logoUrl)
        <img src="{{ $logoUrl }}"
             alt="Logo de {{ $displayName }}"
             loading="lazy"
             decoding="async"
             onerror="this.hidden = true;">
    @endif
</span>
