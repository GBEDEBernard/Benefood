<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Vendor extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'approved_at' => 'datetime',
            'closed_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function documents(): HasMany
    {
        return $this->hasMany(VendorDocument::class);
    }

    public function hours(): HasMany
    {
        return $this->hasMany(VendorHour::class);
    }

    public function settings(): BelongsTo
    {
        return $this->belongsTo(VendorSetting::class);
    }

    public function statusHistory(): HasMany
    {
        return $this->hasMany(VendorStatusHistory::class);
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }
}
