<?php

namespace App\Models;

use App\Enums\ParcelStatus;
use App\Enums\PaymentMethod;
use App\Enums\PaymentPurpose;
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
            'approach_fee' => 'integer',
            'approach_distance_km' => 'decimal:3',
            'approach_pricing_snapshot' => 'array',
            'approach_commission_amount' => 'integer',
            'approach_partner_amount' => 'integer',
            'approach_payment_method' => PaymentMethod::class,
            'approach_payment_status' => PaymentStatus::class,
            'approach_paid_at' => 'datetime',
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
            'reassignment_count' => 'integer',
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
        return $this->hasOne(Payment::class)
            ->where(fn ($query) => $query->where('purpose', PaymentPurpose::Parcel->value)->orWhereNull('purpose'));
    }

    public function approachPayment(): HasOne
    {
        return $this->hasOne(Payment::class)->where('purpose', PaymentPurpose::ParcelApproach->value);
    }

    public function statusHistory(): HasMany
    {
        return $this->hasMany(ParcelStatusHistory::class);
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(ParcelAssignment::class);
    }

    public function incidents(): HasMany
    {
        return $this->hasMany(ParcelIncident::class)->latest();
    }

    public function reassignments(): HasMany
    {
        return $this->hasMany(ParcelReassignmentRequest::class)->latest();
    }

    /** Dernière demande explicite adressée à un livreur proche. */
    public function driverAssignmentRequest(): MorphOne
    {
        return $this->morphOne(DriverAssignmentRequest::class, 'assignable')->latestOfMany('created_at');
    }

    /** Montant total payé par l'expéditeur (livraison + création + approche). */
    public function totalAmount(): int
    {
        return (int) $this->delivery_fee + (int) $this->creation_fee + (int) $this->approach_fee;
    }

    public function hasApproachFee(): bool
    {
        return (int) $this->approach_fee > 0;
    }

    public function approachIsPaid(): bool
    {
        return $this->approach_payment_status === PaymentStatus::Confirmed;
    }

    /** Montant cash à encaisser par le livreur à la livraison. */
    public function cashAmountDue(): int
    {
        return $this->totalAmount();
    }

    public function isPaid(): bool
    {
        return $this->payment_status === PaymentStatus::Confirmed;
    }

    public function isCancelled(): bool
    {
        return $this->status === ParcelStatus::Cancelled;
    }

    public function isDelivered(): bool
    {
        return $this->status === ParcelStatus::Delivered;
    }

    public function isCash(): bool
    {
        return $this->payment_method?->isCash() ?? false;
    }
}
