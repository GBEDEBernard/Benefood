<?php

namespace App\Models;

use Database\Factories\ProductPromotionFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

class ProductPromotion extends Model
{
    /** @use HasFactory<ProductPromotionFactory> */
    use HasFactory;

    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'promo_price' => 'integer',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'is_active' => 'boolean',
        ];
    }

    public function vendor(): BelongsTo
    {
        return $this->belongsTo(Vendor::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    /**
     * Promotion en cours à l'instant donné (active et dans sa plage de dates).
     */
    public function scopeCurrentlyActive(Builder $query): Builder
    {
        $now = Carbon::now();

        return $query
            ->where('is_active', true)
            ->where('starts_at', '<=', $now)
            ->where('ends_at', '>=', $now);
    }

    public function isCurrentlyActive(?Carbon $at = null): bool
    {
        $at ??= Carbon::now();

        return (bool) $this->is_active
            && $this->starts_at?->lessThanOrEqualTo($at) === true
            && $this->ends_at?->greaterThanOrEqualTo($at) === true;
    }

    /**
     * Pourcentage d'économie affiché sur les cartes et bannières client.
     */
    public function discountPercent(): int
    {
        $basePrice = (int) ($this->product?->price ?? 0);
        $promoPrice = (int) $this->promo_price;

        if ($basePrice <= 0 || $promoPrice <= 0 || $promoPrice >= $basePrice) {
            return 0;
        }

        return (int) round((($basePrice - $promoPrice) / $basePrice) * 100);
    }
}
