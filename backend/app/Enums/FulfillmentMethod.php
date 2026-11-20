<?php

namespace App\Enums;

enum FulfillmentMethod: string
{
    case Delivery = 'delivery';
    case Pickup = 'pickup';

    public function isPickup(): bool
    {
        return $this === self::Pickup;
    }

    public function isDelivery(): bool
    {
        return $this === self::Delivery;
    }
}
