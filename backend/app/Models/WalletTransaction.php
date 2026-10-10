<?php

namespace App\Models;

use App\Enums\WalletTransactionType;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Mouvement de wallet (J29 §7) : écrit une seule fois, jamais modifié.
 * `balance_after` correspond au solde disponible après le mouvement.
 */
class WalletTransaction extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'type' => WalletTransactionType::class,
            'amount' => 'integer',
            'balance_after' => 'integer',
        ];
    }

    public function wallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class);
    }
}
