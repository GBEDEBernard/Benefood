<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Services\AuthService;
use App\Services\SocialAuthService;
use App\Support\Api;
use App\Support\Phone;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function __construct(
        private readonly AuthService $auth,
        private readonly SocialAuthService $socialAuth,
    ) {}

    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'regex:/^(?:\+?229|00229|0)?0?1?[0-9]{8}$/'],
            'email' => ['required', 'string', 'email', 'max:255'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'locale' => ['sometimes', 'string', 'in:fr,en,fon'],
            'roles' => ['sometimes', 'array'],
            'roles.*' => ['string', 'in:client,vendor,driver-independent'],
        ]);

        $data['phone'] = Phone::normalize($data['phone']);

        $payload = $this->auth->register($data);

        return Api::created($this->payload($payload));
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'login' => ['required', 'string', 'max:255'],
            'password' => ['required', 'string'],
        ]);

        $payload = $this->auth->attempt($data['login'], $data['password']);

        if (($payload['two_factor_required'] ?? false) === true) {
            return Api::ok([
                'two_factor_required' => true,
                'challenge_token' => $payload['challenge_token'],
                'expires_at' => $payload['expires_at'],
                ...(isset($payload['code']) ? ['code' => $payload['code']] : []),
            ]);
        }

        return Api::ok($this->payload($payload));
    }

    public function verifyTwoFactor(Request $request): JsonResponse
    {
        $data = $request->validate([
            'challenge_token' => ['required', 'string'],
            'code' => ['required', 'string', 'digits:6'],
        ]);

        $payload = $this->auth->verifyTwoFactor($data['challenge_token'], $data['code']);

        return Api::ok($this->payload($payload));
    }

    public function logout(Request $request): JsonResponse
    {
        $this->auth->logout($request->user());

        return Api::noContent();
    }

    public function refresh(Request $request): JsonResponse
    {
        $payload = $this->auth->refresh($request->user());

        return Api::ok($this->payload($payload));
    }

    public function sendPhoneCode(Request $request): JsonResponse
    {
        $code = $this->auth->issuePhoneVerification($request->user());

        $response = ['message' => 'Un code de vérification a été envoyé.'];

        if (! app()->isProduction()) {
            $response['code'] = $code;
        }

        return Api::ok($response);
    }

    public function verifyPhone(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'digits:6'],
        ]);

        $this->auth->verifyPhone($request->user(), $data['code']);

        return Api::ok(new UserResource($request->user()->fresh()));
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'login' => ['required', 'string', 'max:255'],
        ]);

        $result = $this->auth->forgotPassword($data['login']);

        return Api::accepted([
            'message' => 'Si ce compte existe, un code de réinitialisation a été envoyé.',
            'sent' => $result['sent'],
            ...($result['sent'] && $result['code'] !== null ? ['code' => $result['code']] : []),
        ]);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'login' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'digits:6'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $this->auth->resetPassword($data['login'], $data['code'], $data['password']);

        return Api::noContent();
    }

    public function socialProviders(): JsonResponse
    {
        return Api::ok($this->socialAuth->providersStatus());
    }

    public function socialLogin(Request $request, string $provider): JsonResponse
    {
        $data = $request->validate([
            'id_token' => ['sometimes', 'nullable', 'string'],
            'access_token' => ['sometimes', 'nullable', 'string'],
            'token' => ['sometimes', 'nullable', 'string'],
            'token_type' => ['sometimes', 'string', 'in:id_token,access_token'],
            'code' => ['sometimes', 'nullable', 'string'],
            'redirect_uri' => ['sometimes', 'nullable', 'string'],
            'device_name' => ['sometimes', 'string', 'max:100'],
            'fcm_token' => ['sometimes', 'nullable', 'string'],
            'platform' => ['sometimes', 'nullable', 'string', 'max:30'],
            'device_type' => ['sometimes', 'nullable', 'string', 'max:50'],
            'app_version' => ['sometimes', 'nullable', 'string', 'max:30'],
        ]);

        $result = $this->socialAuth->authenticate($provider, $data);

        return Api::ok($this->socialPayload($result));
    }

    public function socialCallback(Request $request, string $provider): JsonResponse
    {
        $data = $request->validate([
            'id_token' => ['sometimes', 'nullable', 'string'],
            'access_token' => ['sometimes', 'nullable', 'string'],
            'token' => ['sometimes', 'nullable', 'string'],
            'token_type' => ['sometimes', 'string', 'in:id_token,access_token'],
            'code' => ['sometimes', 'nullable', 'string'],
            'redirect_uri' => ['sometimes', 'nullable', 'string'],
            'state' => ['sometimes', 'nullable', 'string'],
            'device_name' => ['sometimes', 'string', 'max:100'],
        ]);

        $result = $this->socialAuth->authenticate($provider, $data);
        $payload = $this->socialPayload($result);
        $payload['state'] = $data['state'] ?? null;

        return Api::ok($payload);
    }

    public function socialLink(Request $request, string $provider): JsonResponse
    {
        $data = $request->validate([
            'id_token' => ['sometimes', 'nullable', 'string'],
            'access_token' => ['sometimes', 'nullable', 'string'],
            'token' => ['sometimes', 'nullable', 'string'],
            'token_type' => ['sometimes', 'string', 'in:id_token,access_token'],
        ]);

        $account = $this->socialAuth->link($request->user(), $provider, $data);

        return Api::ok([
            'message' => 'Compte lié avec succès.',
            'provider' => $account->provider,
        ]);
    }

    public function socialUnlink(Request $request, string $provider): JsonResponse
    {
        $this->socialAuth->unlink($request->user(), $provider);

        return Api::ok(['message' => 'Compte dissocié.']);
    }

    /**
     * @param  array<string, mixed>  $result
     * @return array<string, mixed>
     */
    protected function socialPayload(array $result): array
    {
        return [
            'user' => new UserResource($result['user']),
            'access_token' => $result['access_token'],
            'token_type' => $result['token_type'],
            'expires_at' => $result['expires_at'],
            'is_new' => (bool) ($result['is_new'] ?? false),
            'linked_provider' => $result['linked_provider'] ?? null,
        ];
    }

    protected function payload(array $payload): array
    {
        return [
            'user' => new UserResource($payload['user']),
            'access_token' => $payload['access_token'],
            'token_type' => $payload['token_type'],
            'expires_at' => $payload['expires_at'],
            ...(isset($payload['phone_code']) ? ['phone_code' => $payload['phone_code']] : []),
        ];
    }
}
