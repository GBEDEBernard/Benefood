<?php

namespace App\Services;

use App\Enums\OtpPurpose;
use App\Models\OtpCode;
use Illuminate\Support\Facades\Hash;

/**
 * Génération, vérification et nettoyage des codes OTP (J49).
 */
class OtpService
{
    public const CODE_LENGTH = 6;

    public const TTL_MINUTES = 10;

    public function generate(string $identifier, OtpPurpose $purpose): string
    {
        $code = (string) random_int(10 ** (self::CODE_LENGTH - 1), 10 ** self::CODE_LENGTH - 1);

        OtpCode::create([
            'identifier' => $identifier,
            'code_hash' => Hash::make($code),
            'purpose' => $purpose->value,
            'expires_at' => now()->addMinutes(self::TTL_MINUTES),
        ]);

        return $code;
    }

    public function verify(string $identifier, OtpPurpose $purpose, string $code): bool
    {
        $otp = OtpCode::query()
            ->where('identifier', $identifier)
            ->where('purpose', $purpose->value)
            ->whereNull('used_at')
            ->where('expires_at', '>', now())
            ->latest('created_at')
            ->get()
            ->first(fn (OtpCode $otpCode) => Hash::check($code, $otpCode->code_hash));

        if ($otp === null) {
            return false;
        }

        $otp->update(['used_at' => now()]);

        return true;
    }

    public function purgeExpired(): void
    {
        OtpCode::where('expires_at', '<', now())
            ->orWhere('used_at', '<', now()->subDay())
            ->delete();
    }
}
