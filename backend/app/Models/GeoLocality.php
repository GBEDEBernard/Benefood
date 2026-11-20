<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Localité ponctuelle rattachée à la division de dernier niveau
 * (village, quartier, hameau, ville…).
 */
class GeoLocality extends Model
{
    use HasFactory;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'latitude' => 'float',
            'longitude' => 'float',
            'data_updated_at' => 'date',
            'is_verified' => 'boolean',
            'is_active' => 'boolean',
        ];
    }

    public function country(): BelongsTo
    {
        return $this->belongsTo(GeoCountry::class, 'country_id');
    }

    public function division(): BelongsTo
    {
        return $this->belongsTo(GeoDivision::class, 'division_id');
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    public function scopeVerified(Builder $query): Builder
    {
        return $query->where('is_verified', true);
    }

    public function displayPath(): string
    {
        $parts = $this->division?->path() ?? [];
        $parts[] = $this->name;

        return implode(' / ', $parts);
    }
}
