<?php

namespace App\Enums;

use App\Enums\Concerns\HasValues;

/**
 * Types de documents justificatifs du client (J19).
 */
enum ClientDocumentType: string
{
    use HasValues;

    case IdCard = 'id_card';
    case ProofOfAddress = 'proof_of_address';
    case Selfie = 'selfie';
}
