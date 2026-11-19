<?php

namespace App\Services;

use App\Enums\UserStatus;
use App\Exceptions\DomainException;
use App\Models\Role;
use App\Models\SocialAccount;
use App\Models\User;
use App\Models\UserDevice;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

/**
 * Authentification sociale (Google, Facebook, LinkedIn) via échange/validation de jeton côté serveur.
 */
class SocialAuthService
{
    public const PROVIDERS = ['google', 'facebook', 'linkedin'];

    /**
     * Connexion ou inscription via un fournisseur OAuth (API/mobile : jeton + émission Sanctum).
     *
     * @param  array<string, mixed>  $data
     * @return array{user: User, access_token: string, token_type: string, expires_at: string, is_new: bool, linked_provider: string}
     */
    public function authenticate(string $provider, array $data): array
    {
        $resolved = $this->resolveAuthenticatedUser($provider, $data);
        $user = $resolved['user'];

        $this->registerDevice($user, $data);
        $tokenPayload = $this->issueToken($user, $data['device_name'] ?? 'mobile');

        return [
            'user' => $user->loadMissing('roles'),
            'access_token' => $tokenPayload['access_token'],
            'token_type' => $tokenPayload['token_type'],
            'expires_at' => $tokenPayload['expires_at'],
            'is_new' => $resolved['is_new'],
            'linked_provider' => $resolved['linked_provider'],
        ];
    }

    /**
     * Résout (ou crée) l'utilisateur à partir d'un flux OAuth, sans émettre de jeton API.
     * Utilisé par le flux web (session) et par l'API.
     *
     * @param  array<string, mixed>  $data
     * @return array{user: User, is_new: bool, linked_provider: string}
     */
    public function resolveAuthenticatedUser(string $provider, array $data): array
    {
        $provider = $this->normalizeProvider($provider);
        $profile = $this->fetchProfile($provider, $data);

        return DB::transaction(function () use ($provider, $profile): array {
            $account = SocialAccount::query()
                ->where('provider', $provider)
                ->where('provider_user_id', $profile['id'])
                ->lockForUpdate()
                ->first();

            $isNew = false;

            if ($account !== null) {
                $user = $account->user()->firstOrFail();
                $this->assertUserCanLogin($user);
                $this->syncAccount($account, $profile);
                $this->syncUserFromProfile($user, $profile, false);
            } else {
                $user = $this->resolveOrCreateUser($provider, $profile, $isNew);
                $user->socialAccounts()->create($this->accountAttributes($provider, $profile));
            }

            $this->touchLastUsedRole($user);

            return [
                'user' => $user,
                'is_new' => $isNew,
                'linked_provider' => $provider,
            ];
        });
    }

    /**
     * Lie un fournisseur OAuth au compte authentifié courant.
     *
     * @param  array<string, mixed>  $data
     */
    public function link(User $user, string $provider, array $data): SocialAccount
    {
        $provider = $this->normalizeProvider($provider);
        $profile = $this->fetchProfile($provider, $data);

        return DB::transaction(function () use ($user, $provider, $profile): SocialAccount {
            $existing = SocialAccount::query()
                ->where('provider', $provider)
                ->where('provider_user_id', $profile['id'])
                ->lockForUpdate()
                ->first();

            if ($existing !== null && $existing->user_id !== $user->id) {
                throw new DomainException(
                    'auth.social_already_linked',
                    'Ce compte '.$this->providerLabel($provider).' est déjà associé à un autre utilisateur.',
                    409,
                );
            }

            $email = $this->normalizeEmail($profile['email'] ?? null);
            if ($email !== null) {
                $emailOwner = User::query()
                    ->where('email', $email)
                    ->where('id', '!=', $user->id)
                    ->lockForUpdate()
                    ->first();

                if ($emailOwner !== null && ! $this->isVerifiedProviderEmail($profile)) {
                    throw new DomainException(
                        'auth.email_not_verified',
                        'L’adresse e-mail du fournisseur doit être vérifiée avant toute association.',
                        422,
                    );
                }
            }

            $account = $existing ?? new SocialAccount(['user_id' => $user->id]);
            $account->fill($this->accountAttributes($provider, $profile));
            $account->user_id = $user->id;
            $account->save();

            $this->syncUserFromProfile($user, $profile, true);

            return $account->fresh();
        });
    }

    /**
     * Détache un fournisseur OAuth du compte courant.
     */
    public function unlink(User $user, string $provider): void
    {
        $provider = $this->normalizeProvider($provider);

        $hasPassword = filled($user->password);
        $hasPhoneLogin = filled($user->phone);
        $otherProviders = $user->socialAccounts()->where('provider', '!=', $provider)->count();
        $thisProvider = $user->socialAccounts()->where('provider', $provider)->exists();

        if (! $thisProvider) {
            throw new DomainException('auth.social_not_linked', 'Ce fournisseur n’est pas lié à votre compte.', 404);
        }

        if (! $hasPassword && ! $hasPhoneLogin && $otherProviders < 1) {
            throw new DomainException(
                'auth.last_login_method',
                'Vous devez conserver au moins une méthode de connexion active.',
                422,
            );
        }

        $user->socialAccounts()->where('provider', $provider)->delete();
    }

    /**
     * @return array{supported: list<string>}
     */
    public function providersStatus(): array
    {
        $supported = [];
        foreach (self::PROVIDERS as $provider) {
            if ($this->isConfigured($provider)) {
                $supported[] = $provider;
            }
        }

        return ['supported' => $supported];
    }

    public function isConfigured(string $provider): bool
    {
        return match ($this->normalizeProvider($provider)) {
            'google' => filled(config('services.google.client_id')),
            'facebook' => filled(config('services.facebook.client_id')) && filled(config('services.facebook.client_secret')),
            'linkedin' => filled(config('services.linkedin-openid.client_id')) || filled(config('services.linkedin.client_id')),
            default => false,
        };
    }

    /**
     * Indique si le fournisseur est configuré pour le flux web (échange de code serveur).
     */
    public function isConfiguredForWeb(string $provider): bool
    {
        return match ($this->normalizeProvider($provider)) {
            'google' => filled(config('services.google.client_id')) && filled(config('services.google.client_secret')),
            'facebook' => filled(config('services.facebook.client_id')) && filled(config('services.facebook.client_secret')),
            'linkedin' => (filled(config('services.linkedin-openid.client_id')) || filled(config('services.linkedin.client_id')))
                && (filled(config('services.linkedin-openid.client_secret')) || filled(config('services.linkedin.client_secret'))),
            default => false,
        };
    }

    /**
     * URL d'autorisation OAuth pour le flux web (redirection navigateur).
     */
    public function authorizationUrl(string $provider, string $state): string
    {
        $provider = $this->normalizeProvider($provider);

        if (! $this->isConfiguredForWeb($provider)) {
            throw new DomainException(
                'auth.provider_not_configured',
                'Le fournisseur '.$this->providerLabel($provider).' n’est pas configuré sur ce serveur.',
                503,
            );
        }

        $redirectUri = $this->webRedirectUri($provider);
        if ($redirectUri === '') {
            throw new DomainException(
                'auth.provider_not_configured',
                'La redirection OAuth de '.$this->providerLabel($provider).' n’est pas configurée.',
                503,
            );
        }

        return match ($provider) {
            'google' => 'https://accounts.google.com/o/oauth2/v2/auth?'.http_build_query([
                'client_id' => (string) config('services.google.client_id'),
                'redirect_uri' => $redirectUri,
                'response_type' => 'code',
                'scope' => 'openid email profile',
                'state' => $state,
                'prompt' => 'select_account',
            ]),
            'facebook' => 'https://www.facebook.com/v19.0/dialog/oauth?'.http_build_query([
                'client_id' => (string) config('services.facebook.client_id'),
                'redirect_uri' => $redirectUri,
                'response_type' => 'code',
                'scope' => 'email,public_profile',
                'state' => $state,
            ]),
            'linkedin' => 'https://www.linkedin.com/oauth/v2/authorization?'.http_build_query([
                'response_type' => 'code',
                'client_id' => (string) (config('services.linkedin-openid.client_id') ?: config('services.linkedin.client_id')),
                'redirect_uri' => $redirectUri,
                'state' => $state,
                'scope' => 'openid profile email',
            ]),
        };
    }

    public function webRedirectUri(string $provider): string
    {
        $provider = $this->normalizeProvider($provider);
        $configured = (string) match ($provider) {
            'google' => config('services.google.redirect', ''),
            'facebook' => config('services.facebook.redirect', ''),
            'linkedin' => config('services.linkedin-openid.redirect') ?: config('services.linkedin.redirect', ''),
        };

        return trim($configured) !== '' ? trim($configured) : route('auth.social.callback', ['provider' => $provider]);
    }

    public function normalizeProviderName(string $provider): string
    {
        return $this->normalizeProvider($provider);
    }

    private function normalizeProvider(string $provider): string
    {
        $provider = strtolower(trim($provider));
        if (! in_array($provider, self::PROVIDERS, true)) {
            throw new DomainException('auth.provider_invalid', 'Fournisseur d’authentification invalide.', 422);
        }

        return $provider;
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array{id: string, email: ?string, email_verified: bool, name: string, avatar_url: ?string, raw: array<string, mixed>}
     */
    private function fetchProfile(string $provider, array $data): array
    {
        $code = trim((string) ($data['code'] ?? ''));
        if ($code !== '') {
            if (! $this->isConfiguredForWeb($provider)) {
                throw new DomainException(
                    'auth.provider_not_configured',
                    'Le fournisseur '.$this->providerLabel($provider).' n’est pas configuré sur ce serveur.',
                    503,
                );
            }

            $redirectUri = trim((string) ($data['redirect_uri'] ?? ''));
            $exchanged = $this->exchangeCode($provider, $code, $redirectUri);

            return match ($provider) {
                'google' => $this->fetchGoogleProfile(
                    (string) ($exchanged['id_token'] ?? $exchanged['access_token'] ?? ''),
                    isset($exchanged['id_token']) ? 'id_token' : 'access_token',
                ),
                'facebook' => $this->fetchFacebookProfile((string) ($exchanged['access_token'] ?? '')),
                'linkedin' => $this->fetchLinkedInProfile((string) ($exchanged['access_token'] ?? '')),
            };
        }

        if (! $this->isConfigured($provider)) {
            throw new DomainException(
                'auth.provider_not_configured',
                'Le fournisseur '.$this->providerLabel($provider).' n’est pas configuré sur ce serveur.',
                503,
            );
        }

        $token = trim((string) ($data['id_token'] ?? $data['access_token'] ?? $data['token'] ?? ''));

        if ($token === '') {
            throw new DomainException('auth.social_token_required', 'Le jeton du fournisseur est requis.', 422);
        }

        return match ($provider) {
            'google' => $this->fetchGoogleProfile($token, (string) ($data['token_type'] ?? 'id_token')),
            'facebook' => $this->fetchFacebookProfile($token),
            'linkedin' => $this->fetchLinkedInProfile($token),
        };
    }

    /**
     * Échange un code d'autorisation (flux web) contre des jetons.
     *
     * @return array<string, mixed>
     */
    private function exchangeCode(string $provider, string $code, string $redirectUri): array
    {
        if ($redirectUri === '') {
            throw new DomainException('auth.social_redirect_required', 'La redirection OAuth est invalide.', 422);
        }

        return match ($provider) {
            'google' => $this->exchangeGoogleCode($code, $redirectUri),
            'facebook' => $this->exchangeFacebookCode($code, $redirectUri),
            'linkedin' => $this->exchangeLinkedInCode($code, $redirectUri),
        };
    }

    /**
     * @return array<string, mixed>
     */
    private function exchangeGoogleCode(string $code, string $redirectUri): array
    {
        $response = Http::timeout(10)->asForm()->acceptJson()->post('https://oauth2.googleapis.com/token', [
            'code' => $code,
            'client_id' => (string) config('services.google.client_id'),
            'client_secret' => (string) config('services.google.client_secret'),
            'redirect_uri' => $redirectUri,
            'grant_type' => 'authorization_code',
        ]);

        if ($response->failed()) {
            $this->throwInvalidProviderToken('google');
        }

        return is_array($response->json()) ? $response->json() : [];
    }

    /**
     * @return array<string, mixed>
     */
    private function exchangeFacebookCode(string $code, string $redirectUri): array
    {
        $response = Http::timeout(10)->acceptJson()->get('https://graph.facebook.com/v19.0/oauth/access_token', [
            'client_id' => (string) config('services.facebook.client_id'),
            'client_secret' => (string) config('services.facebook.client_secret'),
            'redirect_uri' => $redirectUri,
            'code' => $code,
        ]);

        if ($response->failed()) {
            $this->throwInvalidProviderToken('facebook');
        }

        return is_array($response->json()) ? $response->json() : [];
    }

    /**
     * @return array<string, mixed>
     */
    private function exchangeLinkedInCode(string $code, string $redirectUri): array
    {
        $clientId = (string) (config('services.linkedin-openid.client_id') ?: config('services.linkedin.client_id'));
        $clientSecret = (string) (config('services.linkedin-openid.client_secret') ?: config('services.linkedin.client_secret'));

        $response = Http::timeout(10)->asForm()->acceptJson()->post('https://www.linkedin.com/oauth/v2/accessToken', [
            'grant_type' => 'authorization_code',
            'code' => $code,
            'client_id' => $clientId,
            'client_secret' => $clientSecret,
            'redirect_uri' => $redirectUri,
        ]);

        if ($response->failed()) {
            $this->throwInvalidProviderToken('linkedin');
        }

        return is_array($response->json()) ? $response->json() : [];
    }

    /**
     * @return array{id: string, email: ?string, email_verified: bool, name: string, avatar_url: ?string, raw: array<string, mixed>}
     */
    private function fetchGoogleProfile(string $token, string $tokenType): array
    {
        $payload = [];
        if ($tokenType === 'access_token') {
            $response = Http::timeout(10)->acceptJson()->withToken($token)
                ->get('https://www.googleapis.com/oauth2/v3/userinfo');
            if ($response->failed()) {
                $this->throwInvalidProviderToken('google');
            }
            $payload = $response->json();
            $id = (string) ($payload['sub'] ?? '');
        } else {
            $response = Http::timeout(10)->acceptJson()->get('https://oauth2.googleapis.com/tokeninfo', [
                'id_token' => $token,
            ]);
            if ($response->failed()) {
                $this->throwInvalidProviderToken('google');
            }
            $payload = $response->json();
            $id = (string) ($payload['sub'] ?? '');
            $this->assertGoogleAudience($payload);
            $issuer = (string) ($payload['iss'] ?? '');
            if (! in_array($issuer, ['accounts.google.com', 'https://accounts.google.com'], true)) {
                $this->throwInvalidProviderToken('google');
            }
        }

        if ($id === '') {
            $this->throwInvalidProviderToken('google');
        }

        $email = $this->normalizeEmail($payload['email'] ?? null);
        $emailVerified = filter_var($payload['email_verified'] ?? false, FILTER_VALIDATE_BOOL);

        return [
            'id' => $id,
            'email' => $email,
            'email_verified' => $emailVerified,
            'name' => trim((string) ($payload['name'] ?? $email ?? 'Utilisateur Google')) ?: 'Utilisateur Google',
            'avatar_url' => $this->nullableString($payload['picture'] ?? null),
            'raw' => is_array($payload) ? $payload : [],
        ];
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    private function assertGoogleAudience(array $payload): void
    {
        $aud = (string) ($payload['aud'] ?? '');
        $allowed = array_values(array_filter(array_map(
            static fn ($value) => trim((string) $value),
            (array) config('services.google.allowed_client_ids', []),
        )));
        $primary = trim((string) config('services.google.client_id', ''));
        if ($primary !== '') {
            $allowed[] = $primary;
        }
        $allowed = array_values(array_unique($allowed));

        if ($allowed !== [] && ! in_array($aud, $allowed, true)) {
            $this->throwInvalidProviderToken('google');
        }
    }

    /**
     * @return array{id: string, email: ?string, email_verified: bool, name: string, avatar_url: ?string, raw: array<string, mixed>}
     */
    private function fetchFacebookProfile(string $token): array
    {
        $appId = (string) config('services.facebook.client_id');
        $appSecret = (string) config('services.facebook.client_secret');

        $debug = Http::timeout(10)->acceptJson()->get('https://graph.facebook.com/debug_token', [
            'input_token' => $token,
            'access_token' => $appId.'|'.$appSecret,
        ]);

        if ($debug->failed() || ! ($debug->json('data.is_valid') === true)) {
            $this->throwInvalidProviderToken('facebook');
        }

        $debugAppId = (string) $debug->json('data.app_id', '');
        if ($debugAppId !== '' && $debugAppId !== $appId) {
            $this->throwInvalidProviderToken('facebook');
        }

        $response = Http::timeout(10)->acceptJson()->get('https://graph.facebook.com/me', [
            'fields' => 'id,name,email,picture.type(large)',
            'access_token' => $token,
        ]);

        if ($response->failed()) {
            $this->throwInvalidProviderToken('facebook');
        }

        $payload = $response->json();
        $id = (string) ($payload['id'] ?? '');
        if ($id === '') {
            $this->throwInvalidProviderToken('facebook');
        }

        $email = $this->normalizeEmail($payload['email'] ?? null);
        $avatar = data_get($payload, 'picture.data.url');

        return [
            'id' => $id,
            'email' => $email,
            'email_verified' => $email !== null,
            'name' => trim((string) ($payload['name'] ?? $email ?? 'Utilisateur Facebook')) ?: 'Utilisateur Facebook',
            'avatar_url' => $this->nullableString(is_string($avatar) ? $avatar : null),
            'raw' => is_array($payload) ? $payload : [],
        ];
    }

    /**
     * @return array{id: string, email: ?string, email_verified: bool, name: string, avatar_url: ?string, raw: array<string, mixed>}
     */
    private function fetchLinkedInProfile(string $token): array
    {
        $response = Http::timeout(10)->acceptJson()->withToken($token)
            ->get('https://api.linkedin.com/v2/userinfo');

        if ($response->failed()) {
            $this->throwInvalidProviderToken('linkedin');
        }

        $payload = $response->json();
        $id = (string) ($payload['sub'] ?? $payload['id'] ?? '');
        if ($id === '') {
            $this->throwInvalidProviderToken('linkedin');
        }

        $email = $this->normalizeEmail($payload['email'] ?? null);
        $emailVerified = filter_var($payload['email_verified'] ?? false, FILTER_VALIDATE_BOOL);
        $name = trim((string) ($payload['name'] ?? trim(((string) ($payload['given_name'] ?? '')).' '.((string) ($payload['family_name'] ?? '')))));

        return [
            'id' => $id,
            'email' => $email,
            'email_verified' => $emailVerified,
            'name' => $name !== '' ? $name : ($email ?? 'Utilisateur LinkedIn'),
            'avatar_url' => $this->nullableString($payload['picture'] ?? null),
            'raw' => is_array($payload) ? $payload : [],
        ];
    }

    /**
     * @param  array{id: string, email: ?string, email_verified: bool, name: string, avatar_url: ?string, raw: array<string, mixed>}  $profile
     */
    private function resolveOrCreateUser(string $provider, array $profile, bool &$isNew): User
    {
        $email = $profile['email'];
        $verified = $profile['email_verified'];

        if ($email !== null) {
            $existing = User::query()->where('email', $email)->lockForUpdate()->first();
            if ($existing !== null) {
                // No automatic linking/merging: require secure explicit linking.
                throw new DomainException(
                    'auth.account_exists_link_required',
                    'Un compte existe déjà avec cette adresse e-mail. Connectez-vous avec votre méthode habituelle puis liez '.$this->providerLabel($provider).' depuis votre compte.',
                    409,
                );
            }
        }

        $user = User::query()->create([
            'name' => $profile['name'],
            'email' => $email,
            'phone' => null,
            'password' => Str::random(40),
            'status' => UserStatus::Active->value,
            'locale' => 'fr',
            'email_verified_at' => ($email !== null && $verified) ? now() : null,
            'avatar_path' => $this->externalAvatarPath($profile['avatar_url']),
        ]);

        $role = Role::query()->firstOrCreate(
            ['slug' => 'client'],
            ['name' => 'Client', 'description' => 'Client de la plateforme'],
        );
        $user->roles()->syncWithoutDetaching([$role->id => ['is_active' => true, 'last_used_at' => now()]]);
        $isNew = true;

        return $user;
    }

    private function assertUserCanLogin(User $user): void
    {
        if (in_array($user->status, [UserStatus::Suspended->value, UserStatus::Closed->value], true)) {
            throw new DomainException('auth.account_suspended', 'Ce compte est suspendu.', 403);
        }
    }

    /**
     * @param  array{id: string, email: ?string, email_verified: bool, name: string, avatar_url: ?string, raw: array<string, mixed>}  $profile
     * @return array<string, mixed>
     */
    private function accountAttributes(string $provider, array $profile): array
    {
        return [
            'provider' => $provider,
            'provider_user_id' => $profile['id'],
            'provider_email' => $profile['email'],
            'name' => $profile['name'],
            'avatar_url' => $profile['avatar_url'],
            'email_verified' => $profile['email_verified'],
            'meta' => [
                'last_login_at' => now()->toIso8601String(),
            ],
        ];
    }

    /**
     * @param  array{id: string, email: ?string, email_verified: bool, name: string, avatar_url: ?string, raw: array<string, mixed>}  $profile
     */
    private function syncAccount(SocialAccount $account, array $profile): void
    {
        $account->fill($this->accountAttributes($account->provider, $profile));
        $account->save();
    }

    /**
     * @param  array{id: string, email: ?string, email_verified: bool, name: string, avatar_url: ?string, raw: array<string, mixed>}  $profile
     */
    private function syncUserFromProfile(User $user, array $profile, bool $isLink): void
    {
        $updates = [];

        if (blank($user->name) && filled($profile['name'])) {
            $updates['name'] = $profile['name'];
        }

        $email = $profile['email'];
        if ($email !== null && blank($user->email) && ! User::query()->where('email', $email)->where('id', '!=', $user->id)->exists()) {
            $updates['email'] = $email;
            if ($profile['email_verified']) {
                $updates['email_verified_at'] = $user->email_verified_at ?? now();
            }
        } elseif ($email !== null && $this->normalizeEmail($user->email) === $email && $profile['email_verified'] && $user->email_verified_at === null) {
            $updates['email_verified_at'] = now();
        }

        if (blank($user->avatar_path) && filled($profile['avatar_url'])) {
            $updates['avatar_path'] = $this->externalAvatarPath($profile['avatar_url']);
        }

        if ($updates !== []) {
            $user->fill($updates)->save();
        }
    }

    private function touchLastUsedRole(User $user): void
    {
        $active = $user->roles()->wherePivot('is_active', true)->first();
        if ($active !== null) {
            $user->roles()->updateExistingPivot($active->id, ['last_used_at' => now()]);
        }
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function registerDevice(User $user, array $data): void
    {
        $token = $data['fcm_token'] ?? null;
        if (! is_string($token) || $token === '') {
            return;
        }

        UserDevice::query()->updateOrCreate(
            ['fcm_token' => $token],
            [
                'user_id' => $user->id,
                'platform' => (string) ($data['platform'] ?? 'unknown'),
                'device_type' => $data['device_type'] ?? null,
                'app_version' => $data['app_version'] ?? null,
                'is_active' => true,
                'last_seen_at' => now(),
            ],
        );
    }

    /**
     * @return array{access_token: string, token_type: string, expires_at: string}
     */
    private function issueToken(User $user, mixed $deviceName): array
    {
        $name = is_string($deviceName) && trim($deviceName) !== '' ? trim($deviceName) : 'mobile';
        $abilities = $user->permissionSlugs() ?: ['*'];
        $expiresAt = now()->addMinutes((int) config('sanctum.expiration', 10080));
        $token = $user->createToken($name, $abilities, $expiresAt);

        return [
            'access_token' => $token->plainTextToken,
            'token_type' => 'Bearer',
            'expires_at' => $expiresAt->toIso8601String(),
        ];
    }

    /**
     * @param  array{id: string, email: ?string, email_verified: bool, name: string, avatar_url: ?string, raw: array<string, mixed>}  $profile
     */
    private function isVerifiedProviderEmail(array $profile): bool
    {
        return $profile['email'] !== null && $profile['email_verified'] === true;
    }

    private function normalizeEmail(mixed $email): ?string
    {
        if (! is_string($email)) {
            return null;
        }

        $email = mb_strtolower(trim($email));

        return $email === '' ? null : $email;
    }

    private function nullableString(mixed $value): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $value = trim($value);

        return $value === '' ? null : $value;
    }

    private function externalAvatarPath(?string $url): ?string
    {
        // Store external avatar URL as-is in avatar_path only when local path empty; UserResource
        // already turns non-storage paths/URLs into media URLs? it uses mediaUrl() which may treat as storage.
        // Keep null to avoid breaking storage-based avatar rendering; clients can still get name.
        return null;
    }

    private function providerLabel(string $provider): string
    {
        return match ($provider) {
            'google' => 'Google',
            'facebook' => 'Facebook',
            'linkedin' => 'LinkedIn',
            default => ucfirst($provider),
        };
    }

    private function throwInvalidProviderToken(string $provider): never
    {
        throw new DomainException(
            'auth.social_token_invalid',
            'Le jeton '.$this->providerLabel($provider).' est invalide ou expiré.',
            401,
        );
    }
}
