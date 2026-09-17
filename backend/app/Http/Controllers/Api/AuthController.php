<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Services\AuthService;
use App\Support\Api;
use App\Support\Phone;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function __construct(private readonly AuthService $auth) {}

    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'regex:/^(?:\+?229|00229|0)?0?1?[0-9]{8}$/'],
            'email' => ['nullable', 'email', 'max:255'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'locale' => ['sometimes', 'string', 'in:fr,en'],
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
