<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class DistancePricingRule extends Model
{
    use HasUuids;

    public const ORDER_DELIVERY = 'order';

    public const PARCEL_DELIVERY = 'parcel';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'max_km' => 'float',
            'base_fee' => 'integer',
            'per_km' => 'integer',
            'discount_percentage' => 'integer',
            'sort_order' => 'integer',
            'is_active' => 'boolean',
        ];
    }
}
