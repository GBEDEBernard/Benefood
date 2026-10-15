<?php

namespace App\Support;

/**
 * Normalisation des numéros de téléphone béninois (+229).
 */
final class Phone
{
    public static function normalize(string $phone): string
    {
        $phone = preg_replace('/[\s\-\.\(\)]+/', '', $phone) ?? $phone;

        // Strip country code prefix (+229 / 00229) to get the national number.
        $national = preg_replace('/^(?:\+229|00229)/', '', $phone);

        // Strip the national trunk prefix (0) when present.
        if (str_starts_with($national, '0')) {
            $national = substr($national, 1);
        }

        return '+229'.$national;
    }

    /**
     * Numéro national à 8 chiffres, ou null si le numéro n'est pas valide.
     *
     * Accepte les formes +229XXXXXXXX, 229XXXXXXXX, 0XXXXXXXX et XXXXXXXX.
     */
    public static function local(string $phone): ?string
    {
        $digits = preg_replace('/\D+/', '', $phone) ?? '';

        if (strlen($digits) === 11 && str_starts_with($digits, '229')) {
            $digits = substr($digits, 3);
        } elseif (str_starts_with($digits, '0')) {
            $digits = substr($digits, 1);
        }

        return strlen($digits) === 8 ? $digits : null;
    }

    public static function isValid(string $phone): bool
    {
        return self::local($phone) !== null;
    }
}
