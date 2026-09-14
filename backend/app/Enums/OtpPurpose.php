<?php

namespace App\Enums;

use App\Enums\Concerns\HasValues;

/**
 * Finalités des codes OTP (J49).
 */
enum OtpPurpose: string
{
    use HasValues;

    case PhoneVerification = 'phone_verification';
    case PasswordReset = 'password_reset';
}
