<?php

namespace App\Enums;

enum VendorDocumentStatus: string
{
    case Submitted = 'submitted';
    case Valid = 'valid';
    case Invalid = 'invalid';
}
