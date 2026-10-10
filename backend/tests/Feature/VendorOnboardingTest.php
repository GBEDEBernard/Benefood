<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Role;
use App\Models\User;
use App\Models\VendorDocument;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;
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

    public function test_onboarding_accepts_category_id(): void
    {
        $category = Category::factory()->create();
        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Resto Chez Awa',
            'phone' => '97000011',
            'category_id' => $category->id,
        ])->assertCreated()
            ->assertJsonPath('data.category_id', $category->id);

        $this->assertDatabaseHas('vendors', [
            'user_id' => $user->id,
            'category_id' => $category->id,
        ]);
    }

    public function test_onboarding_rejects_unknown_category(): void
    {
        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Resto Chez Awa',
            'phone' => '97000011',
            'category_id' => '11111111-1111-1111-1111-111111111111',
        ])->assertUnprocessable()
            ->assertJsonPath('errors.0.field', 'category_id');
    }

    public function test_update_profile_sets_category_id(): void
    {
        $category = Category::factory()->create();
        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Resto Chez Awa',
            'phone' => '97000011',
        ])->assertCreated();

        $this->patchJson('/api/v1/vendors/me', [
            'business_name' => 'Chez Awa',
            'description' => 'Cuisine béninoise.',
            'category_id' => $category->id,
        ])->assertOk()
            ->assertJsonPath('data.business_name', 'Chez Awa')
            ->assertJsonPath('data.category_id', $category->id);

        $this->assertDatabaseHas('vendors', [
            'user_id' => $user->id,
            'business_name' => 'Chez Awa',
            'category_id' => $category->id,
        ]);
    }

    public function test_update_profile_closes_and_reopens_shop(): void
    {
        $user = User::factory()->create(['phone' => '+22997000010']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Resto Chez Awa',
            'phone' => '97000011',
        ])->assertCreated();

        $closedAt = '2026-10-07T12:00:00.000000Z';

        $this->patchJson('/api/v1/vendors/me', [
            'closed_at' => $closedAt,
        ])->assertOk()
            ->assertJsonPath('data.closed_at', '2026-10-07T12:00:00+00:00');

        $this->assertNotNull($user->vendor()->first()->closed_at);

        $this->patchJson('/api/v1/vendors/me', [
            'closed_at' => null,
        ])->assertOk()
            ->assertJsonPath('data.closed_at', null);

        $this->assertNull($user->vendor()->first()->closed_at);
    }

    public function test_status_exposes_is_open(): void
    {
        $user = User::factory()->create(['phone' => '+22997000011']);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/vendors/me/onboarding', [
            'business_name' => 'Resto Chez Awa',
            'phone' => '97000011',
        ])->assertCreated();

        // Boutique active sans horaire : ouverte tant que closed_at est vide.
        $user->vendor()->first()->update(['status' => 'active']);

        $this->getJson('/api/v1/vendors/me/status')
            ->assertOk()
            ->assertJsonPath('data.vendor.is_open', true);

        $this->patchJson('/api/v1/vendors/me', [
            'closed_at' => '2026-10-07T12:00:00.000000Z',
        ])->assertOk();

        $this->getJson('/api/v1/vendors/me/status')
            ->assertOk()
            ->assertJsonPath('data.vendor.is_open', false);
    }

    public function test_documents_endpoint_returns_metadata_and_signed_url(): void
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

        $this->getJson('/api/v1/vendors/me/documents')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.type', 'ifu')
            ->assertJsonPath('data.0.status', 'submitted')
            ->assertJsonStructure(['data' => [['id', 'type', 'status', 'reason', 'file_name', 'created_at', 'reviewed_at', 'url']]]);

        $this->getJson('/api/v1/vendors/me/status')
            ->assertOk()
            ->assertJsonStructure(['data' => ['progress' => [['key', 'label', 'done']]]]);
    }

    public function test_vendor_document_download_requires_signature(): void
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

        $document = VendorDocument::first();

        $this->get('/api/v1/vendors/me/documents/'.$document->id.'/download')
            ->assertForbidden();

        $signed = URL::temporarySignedRoute(
            'api.v1.vendors.me.documents.download',
            now()->addMinutes(5),
            ['document' => $document->id],
        );

        $this->get($signed)->assertOk();
    }

    public function test_activity_endpoint_returns_timeline(): void
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

        $response = $this->getJson('/api/v1/vendors/me/activity')
            ->assertOk()
            ->assertJsonStructure(['data' => [['id', 'type', 'action', 'label', 'description', 'status', 'created_at']]]);

        $actions = collect($response->json('data'))->pluck('action');

        $this->assertTrue($actions->contains('status_registered'));
        $this->assertTrue($actions->contains('document_submitted'));
    }
}
