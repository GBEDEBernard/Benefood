<?php

namespace App\Models;

use App\Enums\PayoutBatchStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Lot de retraits groupés (cahier de conception v1.0, Mode B) : l'admin
 * regroupe des demandes de retrait en attente et les exécute en une fois.
 */
class PayoutBatch extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'status' => PayoutBatchStatus::class,
            'total_amount' => 'integer',
            'payouts_count' => 'integer',
            'executed_count' => 'integer',
            'failed_count' => 'integer',
            'executed_at' => 'datetime',
        ];
    }

    public function payouts(): HasMany
    {
        return $this->hasMany(Payout::class, 'batch_id');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
