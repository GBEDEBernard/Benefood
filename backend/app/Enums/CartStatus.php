<?php

namespace App\Enums;

/**
 * Cycle de vie d'un panier (J29 §4).
 */
enum CartStatus: string
{
    case Open = 'open';
    case Converted = 'converted';
    case Expired = 'expired';
    case Cancelled = 'cancelled';
}
