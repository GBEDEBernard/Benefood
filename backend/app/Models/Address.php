<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Adresse de livraison d'un client (J81).
 */
class Address extends Model
{
    use HasFactory;
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'is_default' => 'boolean',
            'latitude' => 'float',
            'longitude' => 'float',
            'gps_accuracy_m' => 'float',
            'contact_phone' => 'string',
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

    public function locality(): BelongsTo
    {
        return $this->belongsTo(GeoLocality::class, 'locality_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function zone(): BelongsTo
    {
        return $this->belongsTo(DeliveryZone::class);
    }

    /** Représentation lisible utilisée pour le snapshot de commande. */
    public function toHierarchy(): array
    {
        return [
            'city' => $this->city ?: $this->division?->name,
            'area' => $this->area ?: $this->locality?->name ?: (($this->zone?->terms ?: [])[0] ?? null),
            'address_text' => $this->full_address,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'country_id' => $this->country_id,
            'division_id' => $this->division_id,
            'locality_id' => $this->locality_id,
            'geographic_path' => $this->locality?->displayPath() ?: $this->division?->displayPath(),
        ];
    }
}
