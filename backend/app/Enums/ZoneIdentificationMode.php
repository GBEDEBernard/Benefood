<?php

namespace App\Enums;

/**
 * J70 — Modes d'identification d'une zone de livraison.
 */
enum ZoneIdentificationMode: string
{
    /** Zone nomnée (ex. "Cotonou Centre"). */
    case Zone = 'zone';

    /** Quartier(s) listé(s) dans `terms`. */
    case Quarter = 'quarter';

    /** Secteur(s) listé(s) dans `terms`. */
    case Sector = 'sector';

    /** Rayon autour d'un point central (lat/long + rayon). */
    case Distance = 'distance';

    /** Combinaison de modes (terms et/ou distance). */
    case Combination = 'combination';

    public function label(): string
    {
        return match ($this) {
            self::Zone => 'Zone',
            self::Quarter => 'Quartier',
            self::Sector => 'Secteur',
            self::Distance => 'Distance',
            self::Combination => 'Combinaison',
        };
    }
}
