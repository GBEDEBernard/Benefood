<?php

namespace App\Models;

use App\Enums\ParcelStatus;
use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\MorphOne;

/**
 * Envoi de colis (cahier de conception v1.0, phase 3) : prix par distance,
 * frais fixe de création payé par l'expéditeur, répartition 80 % livreur /
 * 20 % plateforme sur les frais de livraison.
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
            'payment_method' => PaymentMethod::class,
            'pickup_snapshot' => 'array',
            'dropoff_snapshot' => 'array',
            'pricing_snapshot' => 'array',
            'distance_km' => 'decimal:2',
            'delivery_fee' => 'integer',
            'creation_fee' => 'integer',
            'commission_rate' => 'integer',
            'commission_amount' => 'integer',
            'partner_amount' => 'integer',
            'platform_amount' => 'integer',
            'confirmation_code' => 'encrypted',
            'confirmation_code_expires_at' => 'datetime',
            'confirmation_code_attempts' => 'integer',
            'confirmation_code_confirmed_at' => 'datetime',
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

    public function targetedDriverProfile(): BelongsTo
    {
        return $this->belongsTo(DriverProfile::class, 'targeted_driver_profile_id');
    }

    public function payment(): HasOne
    {
        return $this->hasOne(Payment::class);
    }

    public function statusHistory(): HasMany
    {
        return $this->hasMany(ParcelStatusHistory::class);
    }

    /** Dernière demande explicite adressée à un livreur proche. */
    public function driverAssignmentRequest(): MorphOne
    {
        return $this->morphOne(DriverAssignmentRequest::class, 'assignable')->latestOfMany('created_at');
    }

    /** Montant total payé par l'expéditeur (livraison + création). */
    public function totalAmount(): int
    {
        return (int) $this->delivery_fee + (int) $this->creation_fee;
    }

    public function isPaid(): bool
    {
        return $this->payment_status === PaymentStatus::Confirmed;
    }

    public function isCash(): bool
    {
        return $this->payment_method?->isCash() ?? false;
    }
}
