<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Models\VendorDocument;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AdminCrudTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        Storage::fake('private');
    }

    private function admin(): User
    {
        $admin = User::factory()->create(['email' => 'admin@local']);
        $admin->roles()->attach(Role::where('slug', 'admin-technique')->first()->id, ['is_active' => true]);

        return $admin;
    }

    private function vendor(string $status = 'pending_verification'): Vendor
    {
        $owner = User::factory()->create(['phone' => '+22997000010']);

        return Vendor::create([
            'user_id' => $owner->id,
            'business_name' => 'Resto Chez Awa',
            'legal_name' => 'Awa SARL',
            'ifu' => '1202400123456',
            'phone' => '+22997000010',
            'city' => 'Cotonou',
            'status' => $status,
            'approved_at' => $status === 'active' ? now() : null,
        ]);
    }

    public function test_guest_is_redirected_to_login(): void
    {
        $this->get(route('admin.vendors.index'))->assertRedirect(route('login'));
        $this->get(route('admin.users.index'))->assertRedirect(route('login'));
    }

    public function test_client_cannot_access_backoffice(): void
    {
        $client = User::factory()->create(['phone' => '+22997000011']);
        $client->roles()->attach(Role::where('slug', 'client')->first()->id, ['is_active' => true]);

        $this->actingAs($client)->get(route('admin.vendors.index'))->assertForbidden();
    }

    public function test_admin_can_list_users_vendors_and_roles(): void
    {
        $this->actingAs($this->admin());

        $this->get(route('admin.users.index'))->assertOk();
        $this->get(route('admin.roles.index'))->assertOk();
        $this->get(route('admin.vendors.index'))->assertOk();
        $this->get(route('admin.vendors.index', ['status' => 'pending_verification']))->assertOk();
    }

    public function test_admin_can_view_vendor_detail(): void
    {
        $vendor = $this->vendor();

        $this->actingAs($this->admin())
            ->get(route('admin.vendors.show', $vendor))
            ->assertOk()
            ->assertSee($vendor->business_name);
    }

    public function test_admin_can_approve_pending_vendor(): void
    {
        $vendor = $this->vendor('pending_verification');

        $this->actingAs($this->admin())
            ->from(route('admin.vendors.show', $vendor))
            ->post(route('admin.vendors.approve', $vendor))
            ->assertRedirect(route('admin.vendors.show', $vendor));

        $this->assertSame('active', $vendor->fresh()->status);
        $this->assertNotNull($vendor->fresh()->approved_at);
        $this->assertDatabaseHas('vendor_status_history', [
            'vendor_id' => $vendor->id,
            'to_status' => 'active',
            'actor_type' => 'admin',
        ]);
    }

    public function test_admin_can_suspend_vendor_with_reason(): void
    {
        $vendor = $this->vendor('active');

        $this->actingAs($this->admin())
            ->from(route('admin.vendors.show', $vendor))
            ->post(route('admin.vendors.suspend', $vendor), ['reason' => 'Non-conformité'])
            ->assertRedirect(route('admin.vendors.show', $vendor));

        $this->assertSame('suspended', $vendor->fresh()->status);
    }

    public function test_suspend_requires_reason(): void
    {
        $vendor = $this->vendor('active');

        $this->actingAs($this->admin())
            ->from(route('admin.vendors.show', $vendor))
            ->post(route('admin.vendors.suspend', $vendor), ['reason' => ''])
            ->assertSessionHasErrors('reason');

        $this->assertSame('active', $vendor->fresh()->status);
    }

    public function test_admin_can_reactivate_suspended_vendor(): void
    {
        $vendor = $this->vendor('suspended');

        $this->actingAs($this->admin())
            ->from(route('admin.vendors.show', $vendor))
            ->post(route('admin.vendors.activate', $vendor))
            ->assertRedirect(route('admin.vendors.show', $vendor));

        $this->assertSame('active', $vendor->fresh()->status);
    }

    public function test_admin_can_review_vendor_document(): void
    {
        $vendor = $this->vendor();
        $document = VendorDocument::create([
            'vendor_id' => $vendor->id,
            'type' => 'ifu',
            'file_path' => 'vendor-documents/'.$vendor->id.'/ifu.pdf',
            'status' => 'submitted',
            'submitted_by' => $vendor->user_id,
        ]);

        $this->actingAs($this->admin())
            ->from(route('admin.vendors.show', $vendor))
            ->post(route('admin.vendors.documents.review', [$vendor, $document]), ['status' => 'valid'])
            ->assertRedirect(route('admin.vendors.show', $vendor));

        $this->assertDatabaseHas('vendor_documents', [
            'id' => $document->id,
            'status' => 'valid',
            'reviewed_by' => User::where('email', 'admin@local')->first()->id,
        ]);
    }

    public function test_admin_can_download_vendor_document(): void
    {
        $vendor = $this->vendor();
        $path = 'vendor-documents/'.$vendor->id.'/ifu.pdf';
        Storage::disk('private')->put($path, 'pdf-content');

        $document = VendorDocument::create([
            'vendor_id' => $vendor->id,
            'type' => 'ifu',
            'file_path' => $path,
            'status' => 'submitted',
            'submitted_by' => $vendor->user_id,
        ]);

        $this->actingAs($this->admin())
            ->get(route('admin.vendors.documents.download', [$vendor, $document]))
            ->assertOk();
    }

    public function test_admin_can_update_user_status(): void
    {
        $client = User::factory()->create(['phone' => '+22997000011']);

        $this->actingAs($this->admin())
            ->from(route('admin.users.show', $client))
            ->post(route('admin.users.status', $client), ['status' => 'suspended'])
            ->assertRedirect(route('admin.users.show', $client));

        $this->assertSame('suspended', $client->fresh()->status);
    }

    public function test_admin_can_reassign_user_roles(): void
    {
        $client = User::factory()->create(['phone' => '+22997000011']);
        $clientRole = Role::where('slug', 'client')->first();
        $vendorRole = Role::where('slug', 'vendor')->first();
        $client->roles()->attach($clientRole->id, ['is_active' => false]);

        $this->actingAs($this->admin())
            ->from(route('admin.users.show', $client))
            ->post(route('admin.users.roles', $client), ['roles' => [$vendorRole->id]])
            ->assertRedirect(route('admin.users.show', $client));

        $this->assertTrue($client->fresh()->roles->pluck('slug')->contains('vendor'));
    }

    public function test_admin_can_view_and_update_role_permissions(): void
    {
        $role = Role::where('slug', 'client')->first();

        $this->actingAs($this->admin())
            ->get(route('admin.roles.show', $role))
            ->assertOk();

        $permission = $role->permissions()->first();

        $this->put(route('admin.roles.update', $role), ['permissions' => [$permission->id]])
            ->assertRedirect(route('admin.roles.show', $role));

        $this->assertSame([$permission->id], $role->permissions()->get()->pluck('id')->all());
    }

    public function test_admin_cannot_suspend_own_account(): void
    {
        $admin = $this->admin();

        $this->actingAs($admin)
            ->from(route('admin.users.show', $admin))
            ->post(route('admin.users.status', $admin), ['status' => 'suspended'])
            ->assertRedirect(route('admin.users.show', $admin))
            ->assertSessionHas('error');

        $this->assertSame('active', $admin->fresh()->status);
    }
}