<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminTwoFactorTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function adminUser(string $phone = '+22997100000', string $email = 'porteuse@beninfood.bj'): User
    {
        $user = User::factory()->create(['phone' => $phone, 'email' => $email]);
        $user->roles()->attach(Role::where('slug', 'porteuse')->first(), ['is_active' => true]);

        return $user;
    }

    private function clientUser(string $phone = '+22997100001'): User
    {
        $user = User::factory()->create(['phone' => $phone]);
        $user->roles()->attach(Role::where('slug', 'client')->first(), ['is_active' => true]);

        return $user;
    }

    public function test_admin_login_requires_two_factor(): void
    {
        $user = $this->adminUser();

        $response = $this->postJson('/api/v1/auth/login', [
            'login' => $user->email,
            'password' => 'password',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.two_factor_required', true)
            ->assertJsonStructure(['data' => ['two_factor_required', 'challenge_token', 'expires_at', 'code']])
            ->assertJsonMissingPath('data.access_token');

        $this->assertMatchesRegularExpression('/^\d{6}$/', $response->json('data.code'));
        $this->assertDatabaseHas('otp_codes', [
            'identifier' => $user->email,
            'purpose' => 'login_two_factor',
        ]);
        $this->assertCount(0, $user->fresh()->tokens);
    }

    public function test_non_admin_login_returns_token_directly(): void
    {
        $user = $this->clientUser();

        $this->postJson('/api/v1/auth/login', [
            'login' => $user->phone,
            'password' => 'password',
        ])
            ->assertOk()
            ->assertJsonMissingPath('data.two_factor_required')
            ->assertJsonStructure(['data' => ['access_token', 'token_type', 'expires_at']]);
    }

    public function test_two_factor_verification_returns_token(): void
    {
        $user = $this->adminUser();

        $challenge = $this->postJson('/api/v1/auth/login', [
            'login' => $user->email,
            'password' => 'password',
        ])->json('data');

        $this->postJson('/api/v1/auth/login/two-factor', [
            'challenge_token' => $challenge['challenge_token'],
            'code' => $challenge['code'],
        ])
            ->assertOk()
            ->assertJsonPath('data.user.id', $user->id)
            ->assertJsonStructure(['data' => ['access_token', 'token_type', 'expires_at']]);

        $this->assertCount(1, $user->fresh()->tokens);
    }

    public function test_two_factor_rejects_wrong_code(): void
    {
        $user = $this->adminUser();

        $challenge = $this->postJson('/api/v1/auth/login', [
            'login' => $user->email,
            'password' => 'password',
        ])->json('data');

        $this->postJson('/api/v1/auth/login/two-factor', [
            'challenge_token' => $challenge['challenge_token'],
            'code' => '000000',
        ])
            ->assertUnprocessable()
            ->assertJsonPath('errors.0.code', 'auth.invalid_code');

        $this->assertCount(0, $user->fresh()->tokens);
    }

    public function test_two_factor_rejects_tampered_challenge(): void
    {
        $this->postJson('/api/v1/auth/login/two-factor', [
            'challenge_token' => 'not-a-valid-token',
            'code' => '123456',
        ])
            ->assertUnprocessable()
            ->assertJsonPath('errors.0.code', 'auth.invalid_challenge');
    }

    public function test_two_factor_code_is_single_use(): void
    {
        $user = $this->adminUser();

        $challenge = $this->postJson('/api/v1/auth/login', [
            'login' => $user->email,
            'password' => 'password',
        ])->json('data');

        $this->postJson('/api/v1/auth/login/two-factor', [
            'challenge_token' => $challenge['challenge_token'],
            'code' => $challenge['code'],
        ])->assertOk();

        $this->postJson('/api/v1/auth/login/two-factor', [
            'challenge_token' => $challenge['challenge_token'],
            'code' => $challenge['code'],
        ])
            ->assertUnprocessable()
            ->assertJsonPath('errors.0.code', 'auth.invalid_code');
    }

    public function test_expired_challenge_is_rejected(): void
    {
        $user = $this->adminUser();

        $challenge = $this->postJson('/api/v1/auth/login', [
            'login' => $user->email,
            'password' => 'password',
        ])->json('data');

        $this->travel((int) config('beninfood.two_factor.challenge_ttl_minutes') + 1)->minutes();

        $this->postJson('/api/v1/auth/login/two-factor', [
            'challenge_token' => $challenge['challenge_token'],
            'code' => $challenge['code'],
        ])
            ->assertUnprocessable()
            ->assertJsonPath('errors.0.code', 'auth.invalid_challenge');
    }

    public function test_suspended_admin_cannot_complete_two_factor(): void
    {
        $user = $this->adminUser();

        $challenge = $this->postJson('/api/v1/auth/login', [
            'login' => $user->email,
            'password' => 'password',
        ])->json('data');

        $user->update(['status' => 'suspended']);

        $this->postJson('/api/v1/auth/login/two-factor', [
            'challenge_token' => $challenge['challenge_token'],
            'code' => $challenge['code'],
        ])
            ->assertForbidden()
            ->assertJsonPath('errors.0.code', 'auth.account_suspended');
    }
}
