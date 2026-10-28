<?php

namespace App\Enums;

enum PaymentPurpose: string
{
    case Order = 'order';
    case OrderApproach = 'order_approach';
    case Parcel = 'parcel';
    case ParcelApproach = 'parcel_approach';
    case FloatTopUp = 'float_topup';

    public function isApproach(): bool
    {
        return $this === self::OrderApproach || $this === self::ParcelApproach;
    }
}
