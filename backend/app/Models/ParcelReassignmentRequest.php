<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ParcelReassignmentRequest extends Model
{
    use HasUuids;

    public const STATUS_PENDING = 'pending';

    public const STATUS_ACCEPTED = 'accepted';

    public const STATUS_CANCELLED = 'cancelled';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'handover_latitude' => 'float',
            'handover_longitude' => 'float',
            'responded_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    public function parcel(): BelongsTo
    {
        return $this->belongsTo(Parcel::class);
    }

    public function incident(): BelongsTo
    {
        return $this->belongsTo(ParcelIncident::class, 'incident_id');
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(User::class, 'client_id');
    }

    public function oldDriverProfile(): BelongsTo
    {
        return $this->belongsTo(DriverProfile::class, 'old_driver_profile_id');
    }

    public function newDriverProfile(): BelongsTo
    {
        return $this->belongsTo(DriverProfile::class, 'new_driver_profile_id');
    }
}
