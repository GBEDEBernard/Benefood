<?php

namespace App\Enums;

use App\Enums\Concerns\HasValues;

/**
 * Types de documents justificatifs du vendeur (J09 §5.2).
 */
enum VendorDocumentType: string
{
    use HasValues;

    case IdCard = 'id_card';
    case BusinessRegistration = 'business_registration';
    case Ifu = 'ifu';
    case StorePhoto = 'store_photo';
}
