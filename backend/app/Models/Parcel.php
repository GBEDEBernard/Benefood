<?php

namespace App\Models;

use App\Enums\ParcelStatus;
use App\Enums\PaymentStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * Envoi de colis (cahier de conception v1.0, phase 3) : prix par distance,
 * répartition 80 % livreur / 20 % plateforme.
 */
class Parcel extends Model
{
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'status' => ParcelStatus::class,
            'payment_status' => PaymentStatus::class,
            'pickup_snapshot' => 'array',
            'dropoff_snapshot' => 'array',
            'distance_km' => 'decimal:2',
            'delivery_fee' => 'integer',
            'commission_rate' => 'integer',
            'commission_amount' => 'integer',
            'partner_amount' => 'integer',
            'platform_amount' => 'integer',
            'payment_deadline_at' => 'datetime',
            'assigned_at' => 'datetime',
            'picked_up_at' => 'datetime',
            'delivered_at' => 'datetime',
            'cancelled_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function driverProfile(): BelongsTo
    {
        return $this->belongsTo(DriverProfile::class);
    }

    public function payment(): HasOne
    {
        return $this->hasOne(Payment::class);
    }

    public function statusHistory(): HasMany
    {
        return $this->hasMany(ParcelStatusHistory::class);
    }

    public function isPaid(): bool
    {
        return $this->payment_status === PaymentStatus::Confirmed;
    }
}
