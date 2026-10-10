<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/**
 * Portefeuille interne (J29 §7) rattaché à un vendeur ou un livreur.
 *
 * Le solde est scindé (cahier de conception v1.0) :
 * - `pending_balance`   : séquestre (commandes payées, non encore livrées) ;
 * - `available_balance` : retirable (commandes livrées/libérées) ;
 * - `balance`           : total (pending + available), conservé pour compat.
 */
class Wallet extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'balance' => 'integer',
            'pending_balance' => 'integer',
            'available_balance' => 'integer',
        ];
    }

    public function owner(): MorphTo
    {
        return $this->morphTo();
    }

    public function payouts(): HasMany
    {
        return $this->hasMany(Payout::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(WalletTransaction::class);
    }

    /** Nom lisible du propriétaire (vendeur ou livreur), résolu sans morphTo. */
    public function ownerName(): string
    {
        return match ($this->owner_type) {
            'vendor', Vendor::class => Vendor::query()->whereKey($this->owner_id)->value('business_name') ?? 'Vendeur',
            'driver', DriverProfile::class => DriverProfile::query()->whereKey($this->owner_id)->with('user')->first()?->user?->name ?? 'Livreur',
            default => '—',
        };
    }

    /** Libellé du rôle du propriétaire : « Vendeur » ou « Livreur ». */
    public function ownerRoleLabel(): string
    {
        return match ($this->owner_type) {
            'vendor', Vendor::class => 'Vendeur',
            'driver', DriverProfile::class => 'Livreur',
            default => '—',
        };
    }
}
