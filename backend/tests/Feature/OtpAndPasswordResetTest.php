<?php

namespace Tests\Feature;

use App\Models\OtpCode;
use App\Models\User;
use App\Services\AuthService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OtpAndPasswordResetTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_register_returns_phone_code_in_non_production(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Awa',
            'phone' => '97000040',
            'password' => 'secret123',
            'password_confirmation' => 'secret123',
        ])->assertCreated();

        $this->assertMatchesRegularExpression('/^\d{6}$/', $response->json('data.phone_code'));

        $this->assertDatabaseHas('otp_codes', [
            'identifier' => '+22997000040',
            'purpose' => 'phone_verification',
        ]);
    }

    public function test_verify_phone_marks_phone_verified(): void
    {
        $user = User::factory()->create(['phone' => '+22997000041']);
        Sanctum::actingAs($user);
        $code = app(AuthService::class)->issuePhoneVerification($user);

        $this->postJson('/api/v1/auth/verify-phone', ['code' => $code])
            ->assertOk()
            ->assertJsonPath('data.id', $user->id);

        $this->assertNotNull($user->fresh()->phone_verified_at);
        $this->assertDatabaseHas('otp_codes', [
            'identifier' => '+22997000041',
            'purpose' => 'phone_verification',
        ]);
        $this->assertNotNull(OtpCode::where('identifier', '+22997000041')->first()->used_at);
    }

    public function test_verify_phone_rejects_wrong_code(): void
    {
        $user = User::factory()->create(['phone' => '+22997000042']);
        Sanctum::actingAs($user);
        app(AuthService::class)->issuePhoneVerification($user);

        $this->postJson('/api/v1/auth/verify-phone', ['code' => '000000'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.0.code', 'auth.invalid_code');

        $this->assertNull($user->fresh()->phone_verified_at);
    }

    public function test_verify_phone_requires_authenticated_user(): void
    {
        $this->postJson('/api/v1/auth/verify-phone', ['code' => '123456'])->assertUnauthorized();
    }

    public function test_send_phone_code_issues_a_fresh_code(): void
    {
        $user = User::factory()->create(['phone' => '+22997000043']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/auth/send-phone-code')
            ->assertOk()
            ->assertJsonStructure(['data' => ['code']]);
    }

    public function test_forgot_password_returns_code_for_existing_user(): void
    {
        $user = User::factory()->create(['phone' => '+22997000044', 'email' => 'awa@mail.com']);

        $response = $this->postJson('/api/v1/auth/forgot-password', ['login' => '97000044']);

        $response->assertAccepted()
            ->assertJsonPath('data.sent', true);
        $this->assertMatchesRegularExpression('/^\d{6}$/', $response->json('data.code'));

        $this->assertDatabaseHas('otp_codes', [
            'identifier' => '+22997000044',
            'purpose' => 'password_reset',
        ]);
    }

    public function test_forgot_password_hides_existence_for_unknown_user(): void
    {
        $response = $this->postJson('/api/v1/auth/forgot-password', ['login' => '97000099']);

        $response->assertAccepted()
            ->assertJsonPath('data.sent', false)
            ->assertJsonMissingPath('data.code');
    }

    public function test_reset_password_updates_password_and_revokes_tokens(): void
    {
        $user = User::factory()->create(['phone' => '+22997000045']);
        $token = $user->createToken('mobile', ['*'])->plainTextToken;
        $code = app(AuthService::class)->forgotPassword('97000045')['code'];

        $this->postJson('/api/v1/auth/reset-password', [
            'login' => '97000045',
            'code' => $code,
            'password' => 'nouveau123',
            'password_confirmation' => 'nouveau123',
        ])->assertNoContent();

        $this->assertTrue(Hash::check('nouveau123', $user->fresh()->password));
        $this->assertCount(0, $user->fresh()->tokens);

        $this->postJson('/api/v1/auth/login', ['login' => '97000045', 'password' => 'nouveau123'])->assertOk();
        $this->postJson('/api/v1/auth/login', ['login' => '97000045', 'password' => 'password'])->assertUnauthorized();
    }

    public function test_reset_password_rejects_wrong_code(): void
    {
        $user = User::factory()->create(['phone' => '+22997000046']);
        app(AuthService::class)->forgotPassword('97000046');

        $this->postJson('/api/v1/auth/reset-password', [
            'login' => '97000046',
            'code' => '000000',
            'password' => 'nouveau123',
            'password_confirmation' => 'nouveau123',
        ])->assertUnprocessable()
            ->assertJsonPath('errors.0.code', 'auth.invalid_code');
    }

    public function test_reset_password_requires_confirmation(): void
    {
        $this->postJson('/api/v1/auth/reset-password', [
            'login' => '97000046',
            'code' => '123456',
            'password' => 'nouveau123',
        ])->assertUnprocessable();
    }
}
