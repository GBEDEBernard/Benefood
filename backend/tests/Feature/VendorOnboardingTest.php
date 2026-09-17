<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use App\Models\VendorDocument;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class VendorOnboardingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        Storage::fake('private');
    }

    public function test_onboarding_creates_vendor_and_assigns_vendor_role(): void
    {
        $user = User::factory()->create(['phone' => '+22997000010']);
        $user->roles()->attach(Role::where('slug', 'client')->first(), ['is_active' => true]);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Resto Chez Awa',
            'legal_name' => 'Awa SARL',
            'phone' => '97000011',
            'email' => 'contact@chezawa.bj',
            'city' => 'Cotonou',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.business_name', 'Resto Chez Awa')
            ->assertJsonPath('data.phone', '+22997000011')
            ->assertJsonPath('data.status', 'registered');

        $this->assertDatabaseHas('vendors', [
            'user_id' => $user->id,
            'business_name' => 'Resto Chez Awa',
            'status' => 'registered',
        ]);

        $this->assertTrue($user->fresh()->roles->pluck('slug')->contains('vendor'));
        $this->assertDatabaseHas('vendor_status_history', [
            'to_status' => 'registered',
            'actor_type' => 'user',
        ]);
    }

    public function test_onboarding_only_once_per_user(): void
    {
        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Resto Chez Awa',
            'phone' => '97000011',
        ])->assertCreated();

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Doublon',
            'phone' => '97000012',
        ])->assertConflict()
            ->assertJsonPath('errors.0.code', 'vendor.already_onboarded');
    }

    public function test_onboarding_validates_required_fields(): void
    {
        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'phone' => '123',
        ])->assertUnprocessable()
            ->assertJsonPath('errors.0.field', 'business_name')
            ->assertJsonStructure(['errors' => [['code', 'message', 'field']]]);
    }

    public function test_document_upload_moves_vendor_to_pending_verification(): void
    {
        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Resto Chez Awa',
            'phone' => '97000011',
        ])->assertCreated();

        $response = $this->postJson('/api/v1/vendors/me/documents', [
            'type' => 'ifu',
            'document' => UploadedFile::fake()->create('ifu.pdf', 100),
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.type', 'ifu')
            ->assertJsonPath('data.status', 'submitted');

        $this->assertDatabaseHas('vendors', [
            'user_id' => $user->id,
            'status' => 'pending_verification',
        ]);
        $this->assertDatabaseHas('vendor_status_history', [
            'to_status' => 'pending_verification',
        ]);
        Storage::disk('private')->assertExists(VendorDocument::first()->file_path);
    }

    public function test_document_upload_requires_documents_rule(): void
    {
        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Resto Chez Awa',
            'phone' => '97000011',
        ])->assertCreated();

        $this->postJson('/api/v1/vendors/me/documents', [
            'type' => 'ifu',
            'document' => UploadedFile::fake()->create('ifu.txt', 100),
        ])->assertUnprocessable()
            ->assertJsonPath('errors.0.field', 'document');
    }

    public function test_document_upload_rejects_invalid_type(): void
    {
        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Resto Chez Awa',
            'phone' => '97000011',
        ])->assertCreated();

        $this->postJson('/api/v1/vendors/me/documents', [
            'type' => 'carte-electorale',
            'document' => UploadedFile::fake()->create('doc.pdf', 100),
        ])->assertUnprocessable();
    }

    public function test_document_upload_requires_onboarding_first(): void
    {
        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/documents', [
            'type' => 'ifu',
            'document' => UploadedFile::fake()->create('ifu.pdf', 100),
        ])->assertConflict()
            ->assertJsonPath('errors.0.code', 'vendor.not_onboarded');
    }

    public function test_status_returns_vendor_and_documents(): void
    {
        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Resto Chez Awa',
            'phone' => '97000011',
        ])->assertCreated();

        $this->postJson('/api/v1/vendors/me/documents', [
            'type' => 'ifu',
            'document' => UploadedFile::fake()->create('ifu.pdf', 100),
        ])->assertCreated();

        $this->getJson('/api/v1/vendors/me/status')
            ->assertOk()
            ->assertJsonPath('data.vendor.status', 'pending_verification')
            ->assertJsonCount(1, 'data.documents')
            ->assertJsonStructure(['data' => ['vendor', 'documents' => [['type', 'status']]]]);
    }

    public function test_status_without_onboarding_returns_404(): void
    {
        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->getJson('/api/v1/vendors/me/status')
            ->assertNotFound()
            ->assertJsonPath('errors.0.code', 'vendor.not_onboarded');
    }

    public function test_vendor_can_upload_logo_and_cover(): void
    {
        Storage::fake('public');

        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Resto Chez Awa',
            'phone' => '97000011',
        ])->assertCreated();

        $vendor = $user->fresh()->vendor()->first();

        $this->patch('/api/v1/vendors/me', [
            'logo' => UploadedFile::fake()->image('logo.jpg', 200, 200),
            'cover' => UploadedFile::fake()->image('cover.jpg', 800, 400),
        ])->assertOk();

        $vendor->refresh();

        $this->assertNotNull($vendor->logo_url);
        $this->assertNotNull($vendor->cover_url);
        $this->assertStringContainsString("vendor-media/{$vendor->id}", $vendor->logo_url);
        $this->assertCount(2, Storage::disk('public')->allFiles("vendor-media/{$vendor->id}"));
    }
}
