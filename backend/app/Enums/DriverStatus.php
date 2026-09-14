<?php

namespace App\Enums;

/**
 * Machine à états du compte livreur (J10).
 */
enum DriverStatus: string
{
    case Candidate = 'candidate';
    case PendingValidation = 'pending_validation';
    case Validated = 'validated';
    case Active = 'active';
    case Suspended = 'suspended';
    case Closed = 'closed';
}
