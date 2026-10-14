<?php

namespace App\Enums;

/**
 * État d'un livreur favori : demande en attente, acceptée ou refusée.
 */
enum FavoriteDriverStatus: string
{
    case Pending = 'pending';
    case Accepted = 'accepted';
    case Declined = 'declined';
}
