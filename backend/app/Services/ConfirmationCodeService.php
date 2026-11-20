<?php

namespace App\Services;

use App\Exceptions\DomainException;
use Illuminate\Database\Eloquent\Model;

/**
 * Codes de confirmation de livraison et de collecte (commandes et colis).
 *
 * Le code est stocké chiffré et n'est jamais renvoyé à la personne qui doit le
 * saisir (livreur). Il est validé côté serveur avant toute libération de fonds,
 * avec expiration, nombre de tentatives limité et usage unique.
 *
 * Le paramètre `$field` permet de gérer deux codes distincts sur la même
 * commande : `confirmation_code` (client → livreur/retrait) et `pickup_code`
 * (vendeur → livreur lors de la collecte).
 */
class ConfirmationCodeService
{
    public function generate(Model $model, string $errorPrefix = 'order', string $field = 'confirmation_code'): string
    {
        $code = (string) random_int(100000, 999999);

        $model->forceFill([
            $field => $code,
            $field.'_expires_at' => now()->addHours(
                (int) config('beninfood.orders.confirmation_code_ttl_hours', 72),
            ),
            $field.'_attempts' => 0,
            $field.'_confirmed_at' => null,
        ])->save();

        return $code;
    }

    /**
     * Vérifie le code soumis. Incrémente le compteur en cas d'échec (persisté
     * immédiatement) et lève une DomainException.
     */
    public function validate(Model $model, ?string $code, string $errorPrefix = 'order', string $field = 'confirmation_code'): void
    {
        if ($model->{$field.'_confirmed_at'} !== null) {
            throw new DomainException(
                $errorPrefix.'.already_confirmed',
                'Cette opération est déjà confirmée.',
                409,
            );
        }

        if ($model->{$field.'_expires_at'} !== null && $model->{$field.'_expires_at'}->isPast()) {
            throw new DomainException(
                $errorPrefix.'.confirmation_code_expired',
                $field === 'pickup_code'
                    ? 'Le code de collecte a expiré. Demandez un nouveau code au vendeur.'
                    : 'Le code de confirmation a expiré. Demandez un nouveau code au client.',
                422,
            );
        }

        $maxAttempts = (int) config('beninfood.orders.confirmation_code_max_attempts', 5);

        if ((int) $model->{$field.'_attempts'} >= $maxAttempts) {
            throw new DomainException(
                $errorPrefix.'.confirmation_code_locked',
                'Trop de tentatives. Contactez le support pour débloquer l\'opération.',
                429,
            );
        }

        $expected = (string) $model->{$field};
        $submitted = trim((string) $code);

        if ($expected === '' || $submitted === '' || ! hash_equals($expected, $submitted)) {
            $model->increment($field.'_attempts');

            throw new DomainException(
                $errorPrefix.'.wrong_confirmation_code',
                $field === 'pickup_code'
                    ? 'Le code de collecte ne correspond pas.'
                    : 'Le code de confirmation ne correspond pas.',
                422,
            );
        }
    }

    public function markConfirmed(Model $model, string $field = 'confirmation_code'): void
    {
        $model->forceFill([
            $field.'_confirmed_at' => now(),
            $field.'_attempts' => 0,
        ])->save();
    }
}
