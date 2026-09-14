<?php

namespace App\Enums;

use App\Enums\Concerns\HasValues;

/**
 * Types de documents justificatifs du livreur (J10 §5.2).
 */
enum DriverDocumentType: string
{
    use HasValues;

    case IdCard = 'id_card';
    case DriverLicense = 'driver_license';
    case VehicleRegistration = 'vehicle_registration';
    case Insurance = 'insurance';
    case Photo = 'photo';
}
