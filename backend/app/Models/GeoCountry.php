<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Pays et configuration de son arborescence administrative.
 *
 * Le découpage n'est pas codé en dur : chaque pays décrit ses niveaux dans
 * `levels` (region, province, department, state, district…).
 */
class GeoCountry extends Model
{
    use HasFactory;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'levels' => 'array',
            'data_updated_at' => 'date',
            'is_active' => 'boolean',
        ];
    }

    public function divisions(): HasMany
    {
        return $this->hasMany(GeoDivision::class, 'country_id');
    }

    public function localities(): HasMany
    {
        return $this->hasMany(GeoLocality::class, 'country_id');
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    /**
     * @return array<int, array{slug: string, label: string, plural: string}>
     */
    public function hierarchy(): array
    {
        return is_array($this->levels) ? $this->levels : [];
    }

    public function levelLabel(?string $slug): ?string
    {
        foreach ($this->hierarchy() as $level) {
            if (($level['slug'] ?? null) === $slug) {
                return $level['label'] ?? $slug;
            }
        }

        return $slug;
    }

    public function childLevel(?string $slug): ?string
    {
        $levels = array_column($this->hierarchy(), 'slug');
        $index = array_search($slug, $levels, true);

        return $index === false ? null : ($levels[$index + 1] ?? null);
    }

    public function firstLevel(): ?string
    {
        return array_column($this->hierarchy(), 'slug')[0] ?? null;
    }

    public function lastLevel(): ?string
    {
        $levels = array_column($this->hierarchy(), 'slug');

        return $levels === [] ? null : $levels[count($levels) - 1];
    }
}
