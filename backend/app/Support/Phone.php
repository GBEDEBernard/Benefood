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
}
