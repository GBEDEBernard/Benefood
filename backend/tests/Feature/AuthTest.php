<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_register_creates_user_with_client_role(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Awa',
            'phone' => '97000000',
            'email' => 'awa@mail.com',
            'password' => 'secret123',
            'password_confirmation' => 'secret123',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.user.name', 'Awa')
            ->assertJsonPath('data.user.phone', '+22997000000')
            ->assertJsonPath('data.user.roles.0.slug', 'client')
            ->assertJsonPath('data.user.roles.0.is_active', true)
            ->assertJsonStructure(['data' => ['access_token', 'token_type', 'expires_at']]);

        $this->assertDatabaseHas('users', ['phone' => '+22997000000']);
        $this->assertDatabaseHas('user_roles', [
            'user_id' => User::where('phone', '+22997000000')->first()->id,
            'role_id' => Role::where('slug', 'client')->first()->id,
            'is_active' => true,
        ]);
    }

    public function test_register_rejects_duplicate_phone(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'name' => 'Premier',
            'phone' => '97000001',
            'password' => 'secret123',
            'password_confirmation' => 'secret123',
        ])->assertCreated();

        $this->postJson('/api/v1/auth/register', [
            'name' => 'Doublon',
            'phone' => '+22997000001',
            'password' => 'secret123',
            'password_confirmation' => 'secret123',
        ])->assertConflict()
            ->assertJsonPath('errors.0.code', 'auth.phone_taken');
    }

    public function test_register_validates_phone_and_password(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'name' => 'Awa',
            'phone' => '12345',
            'password' => 'short',
            'password_confirmation' => 'short',
        ])->assertUnprocessable()
            ->assertJsonPath('errors.0.code', 'validation_error.phone')
            ->assertJsonStructure(['errors' => [['code', 'message', 'field']]]);
    }

    public function test_login_with_phone_or_email(): void
    {
        $user = User::factory()->create(['phone' => '+22997000002', 'email' => 'awa@mail.com']);
        $user->roles()->attach(Role::where('slug', 'client')->first(), ['is_active' => true]);

        $this->postJson('/api/v1/auth/login', ['login' => '97000002', 'password' => 'password'])
            ->assertOk()
            ->assertJsonPath('data.user.id', $user->id)
            ->assertJsonStructure(['data' => ['access_token']]);

        $this->postJson('/api/v1/auth/login', ['login' => 'awa@mail.com', 'password' => 'password'])
            ->assertOk();
    }

    public function test_login_with_invalid_credentials_returns_401(): void
    {
        $this->postJson('/api/v1/auth/login', ['login' => '97000000', 'password' => 'mauvais'])
            ->assertUnauthorized()
            ->assertJsonPath('errors.0.code', 'auth.invalid_credentials');
    }

    public function test_suspended_account_cannot_login(): void
    {
        $user = User::factory()->create(['phone' => '+22997000003', 'status' => 'suspended']);

        $this->postJson('/api/v1/auth/login', ['login' => '97000003', 'password' => 'password'])
            ->assertForbidden()
            ->assertJsonPath('errors.0.code', 'auth.account_suspended');

        $this->assertNull($user->tokens()->first());
    }

    public function test_protected_routes_require_authentication(): void
    {
        $this->postJson('/api/v1/auth/logout')->assertUnauthorized();
        $this->postJson('/api/v1/auth/refresh')->assertUnauthorized();
    }

    public function test_logout_revokes_token(): void
    {
        $user = User::factory()->create(['phone' => '+22997000004']);
        $user->roles()->attach(Role::where('slug', 'client')->first(), ['is_active' => true]);

        $login = $this->postJson('/api/v1/auth/login', ['login' => '97000004', 'password' => 'password'])->json();

        $this->postJson('/api/v1/auth/logout', [], [
            'Authorization' => 'Bearer '.$login['data']['access_token'],
        ])->assertNoContent();

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_revoked_token_is_rejected(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('mobile', ['*'])->plainTextToken;
        $user->tokens()->delete();

        $this->postJson('/api/v1/auth/refresh', [], [
            'Authorization' => "Bearer {$token}",
        ])->assertUnauthorized();
    }

    public function test_refresh_rotates_token(): void
    {
        $user = User::factory()->create(['phone' => '+22997000005']);
        $user->roles()->attach(Role::where('slug', 'client')->first(), ['is_active' => true]);

        $login = $this->postJson('/api/v1/auth/login', ['login' => '97000005', 'password' => 'password'])->json();
        $oldToken = $login['data']['access_token'];

        $response = $this->postJson('/api/v1/auth/refresh', [], [
            'Authorization' => "Bearer {$oldToken}",
        ]);

        $response->assertOk()
            ->assertJsonPath('data.user.id', $user->id)
            ->assertJsonStructure(['data' => ['access_token']]);
        $this->assertNotSame($oldToken, $response->json('data.access_token'));

        $this->assertCount(1, $user->fresh()->tokens);
    }
}
