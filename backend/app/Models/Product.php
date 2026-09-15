<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Product extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'is_available' => 'boolean',
        ];
    }

    public function vendor(): BelongsTo
    {
        return $this->belongsTo(Vendor::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function images(): HasMany
    {
        return $this->hasMany(ProductImage::class)->orderBy('sort_order')->orderBy('created_at');
    }

    public function mainImage(): HasOne
    {
        return $this->hasOne(ProductImage::class)->where('is_main', true);
    }

    public function priceHistory(): HasMany
    {
        return $this->hasMany(ProductPriceHistory::class)->orderByDesc('changed_at');
    }

    public function stockLogs(): HasMany
    {
        return $this->hasMany(StockLog::class)->orderByDesc('created_at');
    }

    /**
     * Le produit peut-il être commandé (actif, disponible et en stock) ?
     */
    public function isOrderable(): bool
    {
        return (bool) $this->is_active
            && (bool) $this->is_available
            && ($this->stock_qty === null || $this->stock_qty > 0);
    }

    public function scopeOrderable(Builder $query): Builder
    {
        return $query
            ->where('is_active', true)
            ->where('is_available', true)
            ->where(fn (Builder $q) => $q->whereNull('stock_qty')->orWhere('stock_qty', '>', 0));
    }
}
