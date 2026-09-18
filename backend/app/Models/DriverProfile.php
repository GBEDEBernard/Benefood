<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DriverProfile extends Model
{
    use HasFactory, HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'available' => 'boolean',
            'last_latitude' => 'decimal:7',
            'last_longitude' => 'decimal:7',
            'last_location_at' => 'datetime',
            'rating' => 'decimal:2',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function documents(): HasMany
    {
        return $this->hasMany(DriverDocument::class);
    }

    public function availabilityLogs(): HasMany
    {
        return $this->hasMany(DriverAvailabilityLog::class);
    }

    public function statusHistory(): HasMany
    {
        return $this->hasMany(DriverStatusHistory::class, 'driver_profile_id');
    }

    public function deliveries(): HasMany
    {
        return $this->hasMany(Delivery::class, 'driver_profile_id');
    }
}
