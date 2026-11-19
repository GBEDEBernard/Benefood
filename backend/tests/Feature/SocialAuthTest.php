<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\SocialAccount;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SocialAuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);

        config()->set('services.google.client_id', 'google-client-id');
        config()->set('services.google.allowed_client_ids', ['google-client-id']);
        config()->set('services.facebook.client_id', 'fb-app-id');
        config()->set('services.facebook.client_secret', 'fb-app-secret');
        config()->set('services.linkedin-openid.client_id', 'li-client-id');
        config()->set('services.linkedin.client_id', 'li-client-id');
    }

    public function test_social_providers_endpoint_reports_configured_providers(): void
    {
        $response = $this->getJson('/api/v1/auth/social/providers');

        $response->assertOk()
            ->assertJsonPath('data.supported.0', 'google')
            ->assertJsonPath('data.supported.1', 'facebook')
            ->assertJsonPath('data.supported.2', 'linkedin');
    }

    public function test_google_social_login_creates_user_on_first_connection(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'sub' => 'google-sub-123',
                'email' => 'awa.google@example.com',
                'email_verified' => 'true',
                'name' => 'Awa Google',
                'picture' => 'https://example.com/awa.png',
                'aud' => 'google-client-id',
                'iss' => 'https://accounts.google.com',
                'exp' => now()->addHour()->timestamp,
            ], 200),
        ]);

        $response = $this->postJson('/api/v1/auth/social/google', [
            'id_token' => 'valid-google-id-token',
            'token_type' => 'id_token',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.is_new', true)
            ->assertJsonPath('data.linked_provider', 'google')
            ->assertJsonPath('data.user.email', 'awa.google@example.com')
            ->assertJsonPath('data.user.roles.0.slug', 'client')
            ->assertJsonStructure(['data' => ['access_token', 'token_type', 'expires_at', 'user']]);

        $this->assertDatabaseHas('users', [
            'email' => 'awa.google@example.com',
            'name' => 'Awa Google',
        ]);

        $this->assertDatabaseHas('social_accounts', [
            'provider' => 'google',
            'provider_user_id' => 'google-sub-123',
            'provider_email' => 'awa.google@example.com',
        ]);
    }

    public function test_google_social_login_connects_existing_linked_account(): void
    {
        $user = User::factory()->create([
            'email' => 'awa.google@example.com',
            'name' => 'Awa Google',
        ]);
        $user->roles()->syncWithoutDetaching([
            Role::where('slug', 'client')->value('id') => ['is_active' => true],
        ]);
        SocialAccount::create([
            'user_id' => $user->id,
            'provider' => 'google',
            'provider_user_id' => 'google-sub-123',
            'provider_email' => 'awa.google@example.com',
            'name' => 'Awa Google',
            'email_verified' => true,
        ]);

        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'sub' => 'google-sub-123',
                'email' => 'awa.google@example.com',
                'email_verified' => 'true',
                'name' => 'Awa Google',
                'aud' => 'google-client-id',
                'iss' => 'accounts.google.com',
            ], 200),
        ]);

        $response = $this->postJson('/api/v1/auth/social/google', [
            'id_token' => 'valid-google-id-token',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.is_new', false)
            ->assertJsonPath('data.user.id', $user->id);

        $this->assertSame(1, SocialAccount::where('provider', 'google')->where('provider_user_id', 'google-sub-123')->count());
        $this->assertSame(1, User::where('email', 'awa.google@example.com')->count());
    }

    public function test_social_login_does_not_auto_merge_existing_email_account(): void
    {
        User::factory()->create([
            'email' => 'same@example.com',
        ]);

        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'sub' => 'google-sub-999',
                'email' => 'same@example.com',
                'email_verified' => 'true',
                'name' => 'Same Email',
                'aud' => 'google-client-id',
                'iss' => 'https://accounts.google.com',
            ], 200),
        ]);

        $response = $this->postJson('/api/v1/auth/social/google', [
            'id_token' => 'valid-google-id-token',
        ]);

        $response->assertStatus(409)
            ->assertJsonPath('errors.0.code', 'auth.account_exists_link_required');

        $this->assertDatabaseMissing('social_accounts', [
            'provider' => 'google',
            'provider_user_id' => 'google-sub-999',
        ]);
    }

    public function test_facebook_social_login_validates_token_and_creates_user(): void
    {
        Http::fake([
            'https://graph.facebook.com/debug_token*' => Http::response([
                'data' => [
                    'is_valid' => true,
                    'app_id' => 'fb-app-id',
                    'user_id' => 'fb-user-1',
                ],
            ], 200),
            'https://graph.facebook.com/me*' => Http::response([
                'id' => 'fb-user-1',
                'name' => 'Koffi Facebook',
                'email' => 'koffi.fb@example.com',
                'picture' => ['data' => ['url' => 'https://example.com/koffi.jpg']],
            ], 200),
        ]);

        $response = $this->postJson('/api/v1/auth/social/facebook', [
            'access_token' => 'valid-facebook-token',
            'token_type' => 'access_token',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.is_new', true)
            ->assertJsonPath('data.user.email', 'koffi.fb@example.com');

        $this->assertDatabaseHas('social_accounts', [
            'provider' => 'facebook',
            'provider_user_id' => 'fb-user-1',
        ]);
    }

    public function test_linkedin_social_login_validates_userinfo_and_creates_user(): void
    {
        Http::fake([
            'https://api.linkedin.com/v2/userinfo*' => Http::response([
                'sub' => 'li-user-1',
                'name' => 'Mina LinkedIn',
                'email' => 'mina.li@example.com',
                'email_verified' => true,
                'picture' => 'https://example.com/mina.jpg',
            ], 200),
        ]);

        $response = $this->postJson('/api/v1/auth/social/linkedin', [
            'access_token' => 'valid-linkedin-token',
            'token_type' => 'access_token',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.is_new', true)
            ->assertJsonPath('data.linked_provider', 'linkedin')
            ->assertJsonPath('data.user.name', 'Mina LinkedIn');

        $this->assertDatabaseHas('social_accounts', [
            'provider' => 'linkedin',
            'provider_user_id' => 'li-user-1',
        ]);
    }

    public function test_invalid_social_token_is_rejected(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response(['error' => 'invalid_token'], 400),
        ]);

        $response = $this->postJson('/api/v1/auth/social/google', [
            'id_token' => 'bad-token',
        ]);

        $response->assertStatus(401)
            ->assertJsonPath('errors.0.code', 'auth.social_token_invalid');
    }

    public function test_unconfigured_provider_is_rejected(): void
    {
        config()->set('services.google.client_id', null);
        config()->set('services.google.allowed_client_ids', []);

        $response = $this->postJson('/api/v1/auth/social/google', [
            'id_token' => 'any-token',
        ]);

        $response->assertStatus(503)
            ->assertJsonPath('errors.0.code', 'auth.provider_not_configured');
    }

    public function test_authenticated_user_can_link_and_unlink_provider(): void
    {
        $user = User::factory()->create([
            'email' => 'owner@example.com',
            'password' => 'password123',
        ]);
        $user->roles()->syncWithoutDetaching([
            Role::where('slug', 'client')->value('id') => ['is_active' => true],
        ]);

        Sanctum::actingAs($user);

        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'sub' => 'google-link-1',
                'email' => 'owner@example.com',
                'email_verified' => 'true',
                'name' => 'Owner',
                'aud' => 'google-client-id',
                'iss' => 'https://accounts.google.com',
            ], 200),
        ]);

        $link = $this->postJson('/api/v1/auth/social/google/link', [
            'id_token' => 'valid-google-id-token',
        ]);

        $link->assertOk()->assertJsonPath('data.provider', 'google');
        $this->assertDatabaseHas('social_accounts', [
            'user_id' => $user->id,
            'provider' => 'google',
            'provider_user_id' => 'google-link-1',
        ]);

        $unlink = $this->deleteJson('/api/v1/auth/social/google/link');

        $unlink->assertOk();
        $this->assertDatabaseMissing('social_accounts', [
            'user_id' => $user->id,
            'provider' => 'google',
        ]);
    }

    public function test_cannot_unlink_last_login_method(): void
    {
        $user = User::factory()->create([
            'email' => 'socialonly@example.com',
            'password' => null,
            'phone' => null,
        ]);
        $user->roles()->syncWithoutDetaching([
            Role::where('slug', 'client')->value('id') => ['is_active' => true],
        ]);
        SocialAccount::create([
            'user_id' => $user->id,
            'provider' => 'google',
            'provider_user_id' => 'only-one',
            'email_verified' => true,
        ]);

        Sanctum::actingAs($user);

        $response = $this->deleteJson('/api/v1/auth/social/google/link');

        $response->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'auth.last_login_method');
    }
}
