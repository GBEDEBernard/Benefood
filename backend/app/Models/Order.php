<?php

namespace App\Models;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * Commande (J29 §5, J83/J84) : totaux recalculés côté serveur et snapshot
 * fiable des lignes au moment de la création.
 */
class Order extends Model
{
    use HasFactory;
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'status' => OrderStatus::class,
            'payment_status' => PaymentStatus::class,
            'subtotal' => 'integer',
            'discount' => 'integer',
            'delivery_fee' => 'integer',
            'total' => 'integer',
            'address_snapshot' => 'array',
            'delivery_rate_snapshot' => 'array',
            'payment_deadline_at' => 'datetime',
            'vendor_acceptance_deadline_at' => 'datetime',
            'accepted_at' => 'datetime',
            'delivered_at' => 'datetime',
            'cancelled_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function vendor(): BelongsTo
    {
        return $this->belongsTo(Vendor::class);
    }

    public function cart(): BelongsTo
    {
        return $this->belongsTo(Cart::class);
    }

    public function zone(): BelongsTo
    {
        return $this->belongsTo(DeliveryZone::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    public function statusHistory(): HasMany
    {
        return $this->hasMany(OrderStatusHistory::class);
    }

    public function payment(): HasOne
    {
        return $this->hasOne(Payment::class);
    }

    public function financials(): HasOne
    {
        return $this->hasOne(OrderFinancial::class);
    }

    public function delivery(): HasOne
    {
        return $this->hasOne(Delivery::class);
    }

    public function refunds(): HasMany
    {
        return $this->hasMany(Refund::class);
    }

    public function complaints(): HasMany
    {
        return $this->hasMany(Complaint::class);
    }

    /** La commande attend-elle encore le paiement ? */
    public function isAwaitingPayment(): bool
    {
        return $this->status === OrderStatus::AwaitingPayment;
    }

    public function isCancelled(): bool
    {
        return $this->status === OrderStatus::Cancelled || $this->status === OrderStatus::Refunded;
    }

    public function isReady(): bool
    {
        return $this->status === OrderStatus::Ready;
    }

    public function isPaid(): bool
    {
        return $this->payment_status === PaymentStatus::Confirmed;
    }
}
