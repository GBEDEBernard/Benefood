<?php

namespace App\Models;

use App\Enums\JournalEntryType;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FinancialJournal extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'financial_journal';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'entry_type' => JournalEntryType::class,
            'debit' => 'integer',
            'credit' => 'integer',
            'balance_after' => 'integer',
            'occurred_at' => 'datetime',
        ];
    }
}
