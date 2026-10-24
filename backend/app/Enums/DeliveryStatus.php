<?php

namespace App\Enums;

enum DeliveryStatus: string
{
    case Assigned = 'assigned';
    case EnRoutePickup = 'en_route_pickup';
    case PickedUp = 'picked_up';
    case InDelivery = 'in_delivery';
    case Delivered = 'delivered';
    case Cancelled = 'cancelled';
}
