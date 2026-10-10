<?php

namespace App\Enums;

/**
 * Machine à états des colis (cahier de conception v1.0, phase 3).
 */
enum ParcelStatus: string
{
    case AwaitingPayment = 'awaiting_payment';
    case Paid = 'paid';
    case Assigned = 'assigned';
    case PickedUp = 'picked_up';
    case InDelivery = 'in_delivery';
    case Delivered = 'delivered';
    case Cancelled = 'cancelled';
    case Refunded = 'refunded';

    /** Le colis attend-il encore le paiement ? */
    public function isAwaitingPayment(): bool
    {
        return $this === self::AwaitingPayment;
    }
}
