<?php

namespace App\Enums;

/**
 * Machine à états du compte vendeur (J09).
 */
enum VendorStatus: string
{
    case Registered = 'registered';
    case PendingVerification = 'pending_verification';
    case Verified = 'verified';
    case Active = 'active';
    case Suspended = 'suspended';
    case Closed = 'closed';
}
