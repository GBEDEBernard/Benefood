<?php

namespace Tests\Feature;

use App\Models\ClientDocument;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ClientOnboardingTest extends TestCase
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
        $user = User::factory()->create(['phone' => '+22997000050']);
        $user->roles()->attach(Role::where('slug', 'client')->first(), ['is_active' => true]);
        Sanctum::actingAs($user);

        return $user;
    }

    public function test_onboarding_creates_pending_profile(): void
    {
        $user = $this->actingAsClient();

        $this->postJson('/api/v1/client/me/onboarding', [
            'full_name' => 'Awa Sossou',
            'phone' => '+22997000050',
            'address' => 'Rue 12, Cotonou',
            'city' => 'Cotonou',
        ])->assertCreated()
            ->assertJsonPath('data.status', 'pending');

        $this->assertDatabaseHas('client_profiles', [
            'user_id' => $user->id,
            'status' => 'pending',
            'address' => 'Rue 12, Cotonou',
        ]);
    }

    public function test_onboarding_updates_existing_profile(): void
    {
        $this->actingAsClient();

        $this->postJson('/api/v1/client/me/onboarding', ['city' => 'Cotonou'])->assertCreated();
        $this->postJson('/api/v1/client/me/onboarding', ['city' => 'Porto-Novo'])->assertCreated();

        $this->assertDatabaseCount('client_profiles', 1);
        $this->assertDatabaseHas('client_profiles', ['city' => 'Porto-Novo']);
    }

    public function test_document_upload_requires_onboarding_first(): void
    {
        $this->actingAsClient();

        $this->postJson('/api/v1/client/me/documents', [
            'type' => 'id_card',
            'document' => UploadedFile::fake()->create('cip.pdf', 100),
        ])->assertConflict()
            ->assertJsonPath('errors.0.code', 'client.not_onboarded');
    }

    public function test_required_documents_activate_client_account(): void
    {
        $this->actingAsClient();

        $this->postJson('/api/v1/client/me/onboarding')->assertCreated();

        $this->postJson('/api/v1/client/me/documents', [
            'type' => 'id_card',
            'document' => UploadedFile::fake()->create('cip.pdf', 100),
        ])->assertCreated();

        $this->assertDatabaseHas('client_profiles', ['status' => 'pending']);

        $this->postJson('/api/v1/client/me/documents', [
            'type' => 'proof_of_address',
            'document' => UploadedFile::fake()->create('domicile.pdf', 100),
        ])->assertCreated();

        $this->assertDatabaseHas('client_profiles', ['status' => 'active']);
        Storage::disk('private')->assertExists(ClientDocument::first()->file_path);
    }

    public function test_status_returns_profile_documents_and_completion(): void
    {
        $this->actingAsClient();

        $this->postJson('/api/v1/client/me/onboarding')->assertCreated();
        $this->postJson('/api/v1/client/me/documents', [
            'type' => 'id_card',
            'document' => UploadedFile::fake()->create('cip.pdf', 100),
        ])->assertCreated();

        $this->getJson('/api/v1/client/me/status')
            ->assertOk()
            ->assertJsonPath('data.profile.status', 'pending')
            ->assertJsonCount(1, 'data.documents')
            ->assertJsonPath('data.completed', false)
            ->assertJsonCount(2, 'data.required');
    }

    public function test_status_rejects_unknown_document_type(): void
    {
        $this->actingAsClient();

        $this->postJson('/api/v1/client/me/onboarding')->assertCreated();

        $this->postJson('/api/v1/client/me/documents', [
            'type' => 'passeport',
            'document' => UploadedFile::fake()->create('x.pdf', 100),
        ])->assertStatus(422);
    }

    public function test_client_onboarding_requires_authentication(): void
    {
        $this->postJson('/api/v1/client/me/onboarding')->assertStatus(401);
        $this->getJson('/api/v1/client/me/status')->assertStatus(401);
    }
}
