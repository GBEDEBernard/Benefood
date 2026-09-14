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

        if (str_starts_with($phone, '+')) {
            return $phone;
        }

        if (str_starts_with($phone, '00229')) {
            return '+'.substr($phone, 2);
        }

        if (str_starts_with($phone, '0')) {
            return '+229'.substr($phone, 1);
        }

        if (preg_match('/^(\d{8})$/', $phone, $matches)) {
            return '+229'.$matches[1];
        }

        return $phone;
    }
}
