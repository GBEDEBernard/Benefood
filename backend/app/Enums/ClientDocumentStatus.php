<?php

namespace App\Enums;

enum ClientDocumentStatus: string
{
    case Submitted = 'submitted';
    case Valid = 'valid';
    case Invalid = 'invalid';
}
