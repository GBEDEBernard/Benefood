<?php

namespace App\Enums;

/**
 * Machine à états du dossier client (J19).
 */
enum ClientStatus: string
{
    case Pending = 'pending';
    case Active = 'active';
    case Suspended = 'suspended';
}
