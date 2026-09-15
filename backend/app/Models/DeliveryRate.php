<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Tarif de livraison (M5 — J71).
 *
 * Un tarif est rattaché à une zone ; `vendor_id` null = tarif par défaut de la
 * zone, renseigné = tarif spécifique au vendeur (surcharge applicable).
 */
class DeliveryRate extends Model
{
    use HasFactory;
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'price' => 'integer',
            'is_active' => 'boolean',
            'effective_from' => 'datetime',
            'effective_to' => 'datetime',
        ];
    }

    public function zone(): BelongsTo
    {
        return $this->belongsTo(DeliveryZone::class, 'zone_id');
    }

    public function vendor(): BelongsTo
    {
        return $this->belongsTo(Vendor::class);
    }

    /** Tarif applicable à une date donnée (ou maintenant). */
    public function isEffectiveAt(?\DateTimeInterface $at = null): bool
    {
        $at ??= now();

        return $this->is_active
            && ($this->effective_from === null || $this->effective_from->lte($at))
            && ($this->effective_to === null || $this->effective_to->gte($at));
    }
}
