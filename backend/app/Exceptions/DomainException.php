<?php

namespace App\Exceptions;

use Exception;

/**
 * Erreur métier avec code de domaine et statut HTTP adapté (J31 §3).
 */
class DomainException extends Exception
{
    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly int $status = 400,
    ) {
        parent::__construct($message);
    }
}
