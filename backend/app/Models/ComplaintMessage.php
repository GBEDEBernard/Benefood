<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ComplaintMessage extends Model
{
    use HasFactory, HasUuids;

    protected $guarded = [];

    public function complaint(): BelongsTo
    {
        return $this->belongsTo(Complaint::class);
    }
}
