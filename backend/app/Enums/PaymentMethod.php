<?php

namespace App\Enums;

enum PaymentMethod: string
{
    case Online = 'online';
    case Cash = 'cash';

    public function isCash(): bool
    {
        return $this === self::Cash;
    }

    public function isOnline(): bool
    {
        return $this === self::Online;
    }
}
