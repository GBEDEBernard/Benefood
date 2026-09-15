<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\Pivot;

class VendorZone extends Pivot
{
    use HasUuids;

    protected $table = 'vendor_zones';

    public $incrementing = false;
}