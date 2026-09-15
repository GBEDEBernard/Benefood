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
        ];
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
            'city' => $this->city,
            'area' => ($this->zone?->terms ?: [])[0] ?? null,
            'address_text' => $this->full_address,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
        ];
    }
}
