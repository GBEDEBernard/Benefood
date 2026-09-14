<?php

namespace Tests\Feature;

use App\Models\DriverDocument;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DriverOnboardingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        Storage::fake('private');
    }

    private function actingAsClient(): User
    {
        $user = User::factory()->create(['phone' => '+22997000020']);
        $user->roles()->attach(Role::where('slug', 'client')->first(), ['is_active' => true]);
        Sanctum::actingAs($user);

        return $user;
    }

    public function test_candidacy_creates_independent_driver_and_assigns_role(): void
    {
        $user = $this->actingAsClient();

        $this->postJson('/api/v1/driver/me/onboarding', [
            'vehicle' => 'Moto Bajaj',
        ])->assertCreated()
            ->assertJsonPath('data.type', 'independent')
            ->assertJsonPath('data.status', 'candidate');

        $this->assertDatabaseHas('driver_profiles', [
            'user_id' => $user->id,
            'type' => 'independent',
            'status' => 'candidate',
        ]);
        $this->assertTrue($user->fresh()->roles->pluck('slug')->contains('driver-independent'));
        $this->assertDatabaseHas('driver_status_history', [
            'to_status' => 'candidate',
            'actor_type' => 'user',
        ]);
    }

    public function test_candidacy_only_once_per_user(): void
    {
        $this->actingAsClient();

        $this->postJson('/api/v1/driver/me/onboarding')->assertCreated();

        $this->postJson('/api/v1/driver/me/onboarding')
            ->assertConflict()
            ->assertJsonPath('errors.0.code', 'driver.already_onboarded');
    }

    public function test_document_upload_moves_driver_to_pending_validation(): void
    {
        $user = $this->actingAsClient();

        $this->postJson('/api/v1/driver/me/onboarding', ['vehicle' => 'Moto'])->assertCreated();

        $this->postJson('/api/v1/driver/me/documents', [
            'type' => 'driver_license',
            'document' => UploadedFile::fake()->create('permis.pdf', 150),
        ])->assertCreated()
            ->assertJsonPath('data.status', 'submitted');

        $this->assertDatabaseHas('driver_profiles', [
            'user_id' => $user->id,
            'status' => 'pending_validation',
        ]);
        $this->assertDatabaseHas('driver_status_history', [
            'to_status' => 'pending_validation',
        ]);
        Storage::disk('private')->assertExists(DriverDocument::first()->file_path);
    }

    public function test_document_upload_requires_onboarding_first(): void
    {
        $this->actingAsClient();

        $this->postJson('/api/v1/driver/me/documents', [
            'type' => 'id_card',
            'document' => UploadedFile::fake()->create('cni.pdf', 100),
        ])->assertConflict()
            ->assertJsonPath('errors.0.code', 'driver.not_onboarded');
    }

    public function test_status_returns_profile_and_documents(): void
    {
        $this->actingAsClient();

        $this->postJson('/api/v1/driver/me/onboarding', ['vehicle' => 'Moto'])->assertCreated();
        $this->postJson('/api/v1/driver/me/documents', [
            'type' => 'id_card',
            'document' => UploadedFile::fake()->create('cni.pdf', 100),
        ])->assertCreated();

        $this->getJson('/api/v1/driver/me/status')
            ->assertOk()
            ->assertJsonPath('data.profile.status', 'pending_validation')
            ->assertJsonCount(1, 'data.documents');
    }

    public function test_internal_driver_creation_by_privileged_role(): void
    {
        $admin = User::factory()->create(['phone' => '+22997000030']);
        $admin->roles()->attach(Role::where('slug', 'porteuse')->first(), ['is_active' => true]);
        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/v1/admin/drivers', [
            'name' => 'Achille',
            'phone' => '97000031',
            'vehicle' => 'Scooter',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.profile.type', 'beninfood')
            ->assertJsonPath('data.profile.status', 'validated')
            ->assertJsonStructure(['data' => ['profile' => ['id'], 'initial_password']]);

        $this->assertDatabaseHas('users', ['phone' => '+22997000031']);
        $this->assertDatabaseHas('driver_profiles', [
            'type' => 'beninfood',
            'status' => 'validated',
        ]);
        $this->assertTrue(User::where('phone', '+22997000031')->first()->roles->pluck('slug')->contains('driver-beninfood'));
    }

    public function test_internal_driver_creation_requires_permission(): void
    {
        $client = $this->actingAsClient();

        $this->postJson('/api/v1/admin/drivers', [
            'name' => 'Non autorisé',
            'phone' => '97000032',
        ])->assertForbidden()
            ->assertJsonPath('errors.0.code', 'forbidden');

        $this->assertDatabaseCount('users', 1);
    }

    public function test_internal_driver_creation_rejects_duplicate_phone(): void
    {
        $admin = User::factory()->create(['phone' => '+22997000030']);
        $admin->roles()->attach(Role::where('slug', 'porteuse')->first(), ['is_active' => true]);
        Sanctum::actingAs($admin);

        $this->postJson('/api/v1/admin/drivers', [
            'name' => 'Achille',
            'phone' => '97000030',
        ])->assertConflict()
            ->assertJsonPath('errors.0.code', 'driver.phone_taken');
    }
}
