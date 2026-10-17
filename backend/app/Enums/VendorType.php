<?php

namespace App\Enums;

use App\Enums\Concerns\HasValues;

/**
 * Type d'activité du vendeur : boutique, restaurant ou maquis.
 */
enum VendorType: string
{
    use HasValues;

    case Boutique = 'boutique';
    case Restaurant = 'restaurant';
    case Maquis = 'maquis';

    public function label(): string
    {
        return match ($this) {
            self::Boutique => 'Boutique',
            self::Restaurant => 'Restaurant',
            self::Maquis => 'Maquis',
        };
    }
}
