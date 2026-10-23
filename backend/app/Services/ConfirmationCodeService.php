<?php

namespace App\Services;

use App\Exceptions\DomainException;
use Illuminate\Database\Eloquent\Model;

/**
 * Codes de confirmation de livraison (commandes et colis).
 *
 * Le code est stocké chiffré et n'est jamais renvoyé au livreur. Il est
 * validé côté serveur avant toute libération de fonds, avec expiration,
 * nombre de tentatives limité et usage unique.
 */
class ConfirmationCodeService
{
    public function generate(Model $model, string $errorPrefix = 'order'): string
    {
        $code = (string) random_int(100000, 999999);

        $model->forceFill([
            'confirmation_code' => $code,
            'confirmation_code_expires_at' => now()->addHours(
                (int) config('beninfood.orders.confirmation_code_ttl_hours', 72),
            ),
            'confirmation_code_attempts' => 0,
            'confirmation_code_confirmed_at' => null,
        ])->save();

        return $code;
    }

    /**
     * Vérifie le code soumis par le livreur. Incrémente le compteur en cas
     * d'échec (persisté immédiatement) et lève une DomainException.
     */
    public function validate(Model $model, ?string $code, string $errorPrefix = 'order'): void
    {
        if ($model->confirmation_code_confirmed_at !== null) {
            throw new DomainException(
                $errorPrefix.'.already_confirmed',
                'Cette livraison est déjà confirmée.',
                409,
            );
        }

        if ($model->confirmation_code_expires_at !== null && $model->confirmation_code_expires_at->isPast()) {
            throw new DomainException(
                $errorPrefix.'.confirmation_code_expired',
                'Le code de confirmation a expiré. Demandez un nouveau code au client.',
                422,
            );
        }

        $maxAttempts = (int) config('beninfood.orders.confirmation_code_max_attempts', 5);

        if ((int) $model->confirmation_code_attempts >= $maxAttempts) {
            throw new DomainException(
                $errorPrefix.'.confirmation_code_locked',
                'Trop de tentatives. Contactez le support pour débloquer la livraison.',
                429,
            );
        }

        $expected = (string) $model->confirmation_code;
        $submitted = trim((string) $code);

        if ($expected === '' || $submitted === '' || ! hash_equals($expected, $submitted)) {
            $model->increment('confirmation_code_attempts');

            throw new DomainException(
                $errorPrefix.'.wrong_confirmation_code',
                'Le code de confirmation ne correspond pas.',
                422,
            );
        }
    }

    public function markConfirmed(Model $model): void
    {
        $model->forceFill([
            'confirmation_code_confirmed_at' => now(),
            'confirmation_code_attempts' => 0,
        ])->save();
    }
}
