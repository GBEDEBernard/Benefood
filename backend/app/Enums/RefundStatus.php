<?php

namespace App\Enums;

enum RefundStatus: string
{
    case Pending = 'pending';
    case Executed = 'executed';
    case Failed = 'failed';
}
