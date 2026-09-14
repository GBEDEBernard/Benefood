<?php

namespace App\Enums;

enum JournalEntryType: string
{
    case Payment = 'payment';
    case Commission = 'commission';
    case Reversal = 'reversal';
    case Transfer = 'transfer';
    case Refund = 'refund';
    case Adjustment = 'adjustment';
}
