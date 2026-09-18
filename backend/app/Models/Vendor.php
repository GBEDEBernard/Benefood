<?php

namespace App\Models;

use App\Enums\VendorStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Carbon;

class Vendor extends Model
{
    use HasFactory;
    use HasUuids;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'approved_at' => 'datetime',
            'closed_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function documents(): HasMany
    {
        return $this->hasMany(VendorDocument::class);
    }

    public function hours(): HasMany
    {
        return $this->hasMany(VendorHour::class);
    }

    public function settings(): HasOne
    {
        return $this->hasOne(VendorSetting::class);
    }

    public function statusHistory(): HasMany
    {
        return $this->hasMany(VendorStatusHistory::class);
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function contacts(): HasMany
    {
        return $this->hasMany(VendorContact::class);
    }

    public function zones(): BelongsToMany
    {
        return $this->belongsToMany(DeliveryZone::class, 'vendor_zones', 'vendor_id', 'zone_id')->using(VendorZone::class);
    }

    /**
     * La boutique accepte-t-elle des commandes à l'instant donné ?
     * Un vendeur sans horaire défini pour le jour est considéré ouvert.
     */
    public function isOpenNow(?\DateTimeInterface $at = null): bool
    {
        $at ??= now();

        if ($this->status !== VendorStatus::Active->value || $this->closed_at !== null) {
            return false;
        }

        $day = (new Carbon($at))->dayOfWeek; // 0 = dimanche
        $hour = $this->hours()->where('day_of_week', $day)->first();

        if ($hour === null) {
            return true;
        }

        if ($hour->is_closed) {
            return false;
        }

        $time = $at->format('H:i:s');

        $opensAt = $hour->opens_at?->format('H:i:s');
        $closesAt = $hour->closes_at?->format('H:i:s');

        return ($opensAt === null || $time >= $opensAt)
            && ($closesAt === null || $time <= $closesAt);
    }
}
