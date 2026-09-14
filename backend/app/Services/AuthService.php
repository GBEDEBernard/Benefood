<?php

namespace App\Services;

use App\Enums\OtpPurpose;
use App\Enums\UserStatus;
use App\Exceptions\DomainException;
use App\Models\Role;
use App\Models\User;
use App\Support\Phone;
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

    public function assignRole(User $user, string $slug, bool $isActive = false): void
    {
        $role = Role::where('slug', $slug)->first();

        if ($role === null) {
            throw new DomainException('auth.invalid_role', "Le rôle « {$slug} » n'existe pas.", 422);
        }

        $user->roles()->syncWithoutDetaching([$role->id => ['is_active' => $isActive]]);
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
