@props([
    'label',
    'tone' => 'neutral',
    'dot' => true,
])

<span {{ $attributes->class(['orders-badge', 'orders-badge--'.$tone]) }}>
    @if ($dot)
        <span class="orders-badge__dot" aria-hidden="true"></span>
    @endif
    {{ $label }}
</span>
