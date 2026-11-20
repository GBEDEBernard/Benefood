<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Subdivision administrative d'un pays (département, commune,
 * arrondissement, région, province…).
 */
class GeoDivision extends Model
{
    use HasFactory;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'center_latitude' => 'float',
            'center_longitude' => 'float',
            'bbox_min_latitude' => 'float',
            'bbox_max_latitude' => 'float',
            'bbox_min_longitude' => 'float',
            'bbox_max_longitude' => 'float',
            'data_updated_at' => 'date',
            'is_active' => 'boolean',
        ];
    }

    public function country(): BelongsTo
    {
        return $this->belongsTo(GeoCountry::class, 'country_id');
    }

    public function parent(): BelongsTo
    {
        return $this->belongsTo(self::class, 'parent_id');
    }

    public function children(): HasMany
    {
        return $this->hasMany(self::class, 'parent_id');
    }

    public function localities(): HasMany
    {
        return $this->hasMany(GeoLocality::class, 'division_id');
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    public function scopeAtLevel(Builder $query, string $level): Builder
    {
        return $query->where('level', $level);
    }

    /**
     * Chaîne administrative complète, du pays à cette subdivision.
     *
     * @return array<int, string>
     */
    public function path(): array
    {
        $path = [$this->name];
        $parent = $this->parent;

        while ($parent !== null) {
            array_unshift($path, $parent->name);
            $parent = $parent->parent;
        }

        $country = $this->country;
        if ($country !== null) {
            array_unshift($path, $country->name);
        }

        return $path;
    }

    public function displayPath(): string
    {
        return implode(' / ', $this->path());
    }
}
