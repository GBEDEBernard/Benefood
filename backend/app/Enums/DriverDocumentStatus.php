<?php

namespace App\Enums;

enum DriverDocumentStatus: string
{
    case Submitted = 'submitted';
    case Valid = 'valid';
    case Invalid = 'invalid';
}
