<?php

namespace App\Enums;

enum DriverAssignmentRequestStatus: string
{
    case Pending = 'pending';
    case Accepted = 'accepted';
    case Refused = 'refused';
    case Expired = 'expired';
    case Cancelled = 'cancelled';
}
