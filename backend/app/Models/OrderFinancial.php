<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Répartition financière interne d'une commande (J82) : commission porteuse,
 * montant vendeur et part livreur, recalculés côté serveur.
 */
class OrderFinancial extends Model
{
    use HasFactory;
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'subtotal' => 'integer',
            'discount' => 'integer',
            'delivery_fee' => 'integer',
            'payment_fee' => 'integer',
            'commission_base' => 'integer',
            'commission_rate' => 'integer',
            'commission_amount' => 'integer',
            'vendor_amount' => 'integer',
            'delivery_partner_amount' => 'integer',
            'platform_amount' => 'integer',
            'total_client' => 'integer',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }
}
