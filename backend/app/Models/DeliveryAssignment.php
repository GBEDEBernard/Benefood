<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Segment de livraison attribué à un livreur. Une commande réassignée possède
 * plusieurs segments : les parts sont figées au prorata des distances réelles.
 */
class DeliveryAssignment extends Model
{
    use HasUuids;

    public const STATUS_ACTIVE = 'active';

    public const STATUS_COMPLETED = 'completed';

    public const STATUS_REASSIGNED = 'reassigned';

    public const STATUS_PENDING_HANDOVER = 'pending_handover';

    public const STATUS_CANCELLED = 'cancelled';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'sequence' => 'integer',
            'base_fee' => 'integer',
            'approach_fee' => 'integer',
            'gross_amount' => 'integer',
            'commission_amount' => 'integer',
            'partner_amount' => 'integer',
            'base_partner_amount' => 'integer',
            'approach_partner_amount' => 'integer',
            'base_distance_km' => 'float',
            'approach_distance_km' => 'float',
            'handover_latitude' => 'float',
            'handover_longitude' => 'float',
            'accepted_at' => 'datetime',
            'handover_confirmed_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    public function delivery(): BelongsTo
    {
        return $this->belongsTo(Delivery::class);
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function driverProfile(): BelongsTo
    {
        return $this->belongsTo(DriverProfile::class);
    }

    public function isActive(): bool
    {
        return $this->status === self::STATUS_ACTIVE;
    }
}
