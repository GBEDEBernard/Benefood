<?php

namespace App\Models;

use App\Enums\DeliveryStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Delivery extends Model
{
    use HasFactory, HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'status' => DeliveryStatus::class,
            'fee' => 'integer',
            'partner_amount' => 'integer',
            'reassignment_count' => 'integer',
            'pickup_latitude' => 'float',
            'pickup_longitude' => 'float',
            'dropoff_latitude' => 'float',
            'dropoff_longitude' => 'float',
            'assigned_at' => 'datetime',
            'picked_up_at' => 'datetime',
            'delivered_at' => 'datetime',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function driverProfile(): BelongsTo
    {
        return $this->belongsTo(DriverProfile::class);
    }

    public function targetedDriverProfile(): BelongsTo
    {
        return $this->belongsTo(DriverProfile::class, 'targeted_driver_profile_id');
    }

    public function vendor(): BelongsTo
    {
        return $this->belongsTo(Vendor::class);
    }

    public function zone(): BelongsTo
    {
        return $this->belongsTo(DeliveryZone::class);
    }

    public function statusHistory(): HasMany
    {
        return $this->hasMany(DeliveryStatusHistory::class);
    }

    public function locations(): HasMany
    {
        return $this->hasMany(DeliveryLocation::class);
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(DeliveryAssignment::class)->orderBy('sequence');
    }

    public function activeAssignment(): HasOne
    {
        return $this->hasOne(DeliveryAssignment::class)
            ->whereIn('status', [DeliveryAssignment::STATUS_ACTIVE, DeliveryAssignment::STATUS_PENDING_HANDOVER])
            ->latestOfMany('sequence');
    }

    public function incidents(): HasMany
    {
        return $this->hasMany(DeliveryIncident::class)->latest();
    }

    public function reassignments(): HasMany
    {
        return $this->hasMany(DeliveryReassignmentRequest::class)->latest();
    }

    public function isAvailable(): bool
    {
        return $this->driver_profile_id === null
            && $this->status === DeliveryStatus::Assigned;
    }
}
