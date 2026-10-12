<?php

namespace App\Services;

use App\Enums\OtpPurpose;
use App\Enums\UserStatus;
use App\Exceptions\DomainException;
use App\Models\Role;
use App\Models\User;
use App\Support\Phone;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Hash;

/**
 * Inscription, connexion, gestion de session et codes OTP (J45, J49).
 */
class AuthService
{
    public function __construct(private readonly OtpService $otp) {}

    public function register(array $data): array
    {
        $phone = Phone::normalize($data['phone']);

        if (User::where('phone', $phone)->exists()) {
            throw new DomainException('auth.phone_taken', 'Ce numéro de téléphone est déjà utilisé.', 409);
        }

        if (isset($data['email']) && $data['email'] !== null && User::where('email', $data['email'])->exists()) {
            throw new DomainException('auth.email_taken', 'Cet email est déjà utilisé.', 409);
        }

        $user = User::create([
            'name' => $data['name'],
            'phone' => $phone,
            'email' => $data['email'] ?? null,
            'password' => $data['password'],
            'status' => UserStatus::Active->value,
            'locale' => $data['locale'] ?? 'fr',
        ]);

        $roleSlugs = $data['roles'] ?? ['client'];

        foreach (array_values(array_unique($roleSlugs)) as $index => $slug) {
            $this->assignRole($user, $slug, isActive: $index === 0);
        }

        $payload = $this->tokenPayload($user);

        if (! app()->isProduction()) {
            $payload['phone_code'] = $this->issuePhoneVerification($user);
        }

        return $payload;
    }

    public function attempt(string $login, string $password): array
    {
        $login = trim($login);

        $user = str_contains($login, '@')
            ? User::where('email', $login)->first()
            : User::where('phone', Phone::normalize($login))->first();

        if ($user === null || ! Hash::check($password, $user->password)) {
            throw new DomainException('auth.invalid_credentials', 'Identifiants invalides.', 401);
        }

        $this->assertCanLogin($user);

        if ($user->requiresTwoFactor()) {
            return $this->twoFactorChallenge($user);
        }

        return $this->tokenPayload($user);
    }

    public function assertCanLogin(User $user): void
    {
        if ($user->status === UserStatus::Suspended->value || $user->status === UserStatus::Closed->value) {
            throw new DomainException('auth.account_suspended', 'Ce compte est suspendu.', 403);
        }
    }

    public function refresh(User $user): array
    {
        $user->currentAccessToken()?->delete();

        return $this->tokenPayload($user);
    }

    public function logout(User $user): void
    {
        $user->currentAccessToken()?->delete();
    }

    /**
     * Émet un défi 2FA (code OTP + jeton signé) pour un compte back-office.
     *
     * @return array{two_factor_required: bool, challenge_token: string, expires_at: string, code: ?string}
     */
    public function twoFactorChallenge(User $user): array
    {
        $ttl = (int) config('beninfood.two_factor.challenge_ttl_minutes', 10);
        $expiresAt = now()->addMinutes($ttl);
        $code = $this->otp->generate($this->twoFactorIdentifier($user), OtpPurpose::LoginTwoFactor);

        $challenge = Crypt::encryptString(json_encode([
            'uid' => $user->id,
            'exp' => $expiresAt->timestamp,
        ]));

        return [
            'two_factor_required' => true,
            'challenge_token' => $challenge,
            'expires_at' => $expiresAt->toIso8601String(),
            'code' => app()->isProduction() ? null : $code,
        ];
    }

    public function verifyTwoFactor(string $challengeToken, string $code): array
    {
        try {
            $payload = json_decode(Crypt::decryptString($challengeToken), true, 512, JSON_THROW_ON_ERROR);
        } catch (\Throwable) {
            throw new DomainException('auth.invalid_challenge', 'La session de connexion a expiré, reconnectez-vous.', 422);
        }

        if (! is_array($payload) || (int) ($payload['exp'] ?? 0) < now()->timestamp) {
            throw new DomainException('auth.invalid_challenge', 'La session de connexion a expiré, reconnectez-vous.', 422);
        }

        $user = User::find($payload['uid'] ?? null);

        if ($user === null) {
            throw new DomainException('auth.invalid_challenge', 'La session de connexion a expiré, reconnectez-vous.', 422);
        }

        $this->assertCanLogin($user);

        $ok = $this->otp->verify($this->twoFactorIdentifier($user), OtpPurpose::LoginTwoFactor, $code);

        if (! $ok) {
            throw new DomainException('auth.invalid_code', 'Le code de vérification est invalide ou expiré.', 422);
        }

        return $this->tokenPayload($user);
    }

    protected function twoFactorIdentifier(User $user): string
    {
        return $user->email ?: $user->phone;
    }

    public function issuePhoneVerification(User $user): string
    {
        return $this->otp->generate($user->phone, OtpPurpose::PhoneVerification);
    }

    public function verifyPhone(User $user, string $code): void
    {
        $ok = $this->otp->verify($user->phone, OtpPurpose::PhoneVerification, $code);

        if (! $ok) {
            throw new DomainException('auth.invalid_code', 'Le code de vérification est invalide ou expiré.', 422);
        }

        if ($user->phone_verified_at === null) {
            $user->update(['phone_verified_at' => now()]);
        }
    }

    public function forgotPassword(string $login): array
    {
        $login = trim($login);

        $user = str_contains($login, '@')
            ? User::where('email', $login)->first()
            : User::where('phone', Phone::normalize($login))->first();

        if ($user === null) {
            return ['sent' => false, 'code' => null];
        }

        $code = $this->otp->generate($user->phone, OtpPurpose::PasswordReset);

        return [
            'sent' => true,
            'code' => app()->isProduction() ? null : $code,
        ];
    }

    public function resetPassword(string $login, string $code, string $password): void
    {
        $login = trim($login);

        $user = str_contains($login, '@')
            ? User::where('email', $login)->first()
            : User::where('phone', Phone::normalize($login))->first();

        if ($user === null) {
            throw new DomainException('auth.invalid_code', 'Le code de réinitialisation est invalide ou expiré.', 422);
        }

        $ok = $this->otp->verify($user->phone, OtpPurpose::PasswordReset, $code);

        if (! $ok) {
            throw new DomainException('auth.invalid_code', 'Le code de réinitialisation est invalide ou expiré.', 422);
        }

        $user->update(['password' => $password]);
        $user->tokens()->delete();
    }

    public function updateProfile(User $user, array $data): User
    {
        if (isset($data['email']) && $data['email'] !== null) {
            $taken = User::where('email', $data['email'])
                ->where('id', '!=', $user->id)
                ->exists();

            if ($taken) {
                throw new DomainException('auth.email_taken', 'Cet email est déjà utilisé.', 409);
            }
        }

        $user->update(array_filter([
            'name' => $data['name'] ?? null,
            'email' => $data['email'] ?? null,
        ], fn ($value) => $value !== null));

        return $user->fresh();
    }

    public function registerDevice(User $user, array $data): UserDevice
    {
        $device = UserDevice::updateOrCreate(
            ['fcm_token' => $data['fcm_token']],
            [
                'user_id' => $user->id,
                'platform' => $data['platform'],
                'device_type' => $data['device_type'] ?? null,
                'app_version' => $data['app_version'] ?? null,
                'is_active' => true,
                'last_seen_at' => now(),
            ],
        );

        if ($device->wasRecentlyCreated) {
            $device->update(['last_seen_at' => now()]);
        }

        return $device;
    }

    public function assignRole(User $user, string $slug, bool $isActive = false): void
    {
        $role = Role::where('slug', $slug)->first();

        if ($role === null) {
            throw new DomainException('auth.invalid_role', "Le rôle « {$slug} » n'existe pas.", 422);
        }

        $user->roles()->syncWithoutDetaching([$role->id => ['is_active' => $isActive]]);
    }

    public function switchActiveRole(User $user, string $slug): string
    {
        $role = Role::where('slug', $slug)->first();

        if ($role === null || ! $user->roles()->where('slug', $slug)->exists()) {
            throw new DomainException('role.not_assigned', "Vous ne disposez pas du rôle « {$slug} ».", 422);
        }

        $user->roles()->update(['is_active' => false]);
        $user->roles()->updateExistingPivot($role->id, ['is_active' => true, 'last_used_at' => now()]);

        return $slug;
    }

    protected function tokenPayload(User $user): array
    {
        $user->loadMissing('roles');

        $abilities = $user->permissionSlugs() ?: ['*'];

        $expiresAt = now()->addMinutes((int) config('sanctum.expiration', 10080));
        $token = $user->createToken('mobile', $abilities, $expiresAt);

        return [
            'user' => $user,
            'access_token' => $token->plainTextToken,
            'token_type' => 'Bearer',
            'expires_at' => $expiresAt->toIso8601String(),
        ];
    }
}
