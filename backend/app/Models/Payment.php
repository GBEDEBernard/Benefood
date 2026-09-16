<?php

namespace App\Models;

use App\Enums\PaymentStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Payment extends Model
{
    use HasFactory, HasUuids;

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected $casts = [
        'amount' => 'integer',
        'status' => PaymentStatus::class,
        'payload' => 'array',
        'paid_at' => 'datetime',
        'expires_at' => 'datetime',
    ];

    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function events()
    {
        return $this->hasMany(PaymentEvent::class);
    }

    public function scopeForGateway(string $gateway)
    {
        return fn ($query) => $query->where('gateway', $gateway);
    }

    public function scopePending($query)
    {
        return $query->whereIn('status', [PaymentStatus::Initiated, PaymentStatus::Pending]);
    }
}
