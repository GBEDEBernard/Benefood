<?php

namespace App\Models;

use App\Enums\ZoneIdentificationMode;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Zone tarifaire de livraison (M5 — J69/J70).
 *
 * Une zone peut être identifiée par nom, quartier, secteur, distance (rayon
 * autour d'un centre) ou une combinaison.
 */
class DeliveryZone extends Model
{
    use HasFactory;
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'terms' => 'array',
            'is_active' => 'boolean',
            'center_latitude' => 'float',
            'center_longitude' => 'float',
            'radius_km' => 'float',
        ];
    }

    public function identificationMode(): Attribute
    {
        return Attribute::make(
            get: fn ($value) => ZoneIdentificationMode::from($value ?? ZoneIdentificationMode::Zone->value),
        );
    }

    public function rates(): HasMany
    {
        return $this->hasMany(DeliveryRate::class, 'zone_id');
    }

    /** Tarifs de la zone réservés à un vendeur (null = tarif par défaut). */
    public function vendorRates(?string $vendorId = null): HasMany
    {
        return $this->rates()->where('vendor_id', $vendorId);
    }

    public function vendors(): BelongsToMany
    {
        return $this->belongsToMany(Vendor::class, 'vendor_zones', 'zone_id', 'vendor_id');
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }
}
