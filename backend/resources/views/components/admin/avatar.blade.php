@props([
    'user' => null,
    'name' => null,
    'size' => 'md',
    'online' => false,
])

@php
    $displayName = $name ?: $user?->name ?: 'Utilisateur';
    $photoUrl = \App\Support\AdminMedia::url($user?->avatar_path);
    $initials = \App\Support\AdminMedia::initials($displayName);
    $tone = \App\Support\AdminMedia::tone($displayName);
@endphp

<span {{ $attributes->class(['bf-avatar', 'bf-avatar--'.$size, 'bf-avatar--'.$tone]) }}>
    <span class="bf-avatar__initials" aria-hidden="true">{{ $initials }}</span>
    @if ($photoUrl)
        <img src="{{ $photoUrl }}"
             alt="Photo de {{ $displayName }}"
             loading="lazy"
             decoding="async"
             onerror="this.hidden = true;">
    @endif
    @if ($online)
        <span class="bf-avatar__status" aria-label="En ligne"></span>
    @endif
</span>
