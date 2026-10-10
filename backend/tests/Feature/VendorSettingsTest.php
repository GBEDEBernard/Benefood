<?php

namespace Tests\Feature;

use App\Models\DeliveryZone;
use App\Models\Order;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Services\OrderService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class VendorSettingsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_vendor_can_read_and_update_settings(): void
    {
        $user = $this->vendorUser();
        $vendor = Vendor::factory()->create(['user_id' => $user->id, 'status' => 'active']);

        Sanctum::actingAs($user);

        $this->getJson('/api/v1/vendors/me/settings')
            ->assertOk()
            ->assertJsonPath('data.payout_method', null)
            ->assertJsonPath('data.notify_new_orders', true)
            ->assertJsonPath('data.locale', 'fr');

        $this->patchJson('/api/v1/vendors/me/settings', [
            'payout_method' => 'mobile_money',
            'payout_details' => '+22997000000',
            'notify_new_orders' => false,
            'locale' => 'en',
        ])
            ->assertOk()
            ->assertJsonPath('data.payout_method', 'mobile_money')
            ->assertJsonPath('data.payout_details', '+22997000000')
            ->assertJsonPath('data.notify_new_orders', false)
            ->assertJsonPath('data.locale', 'en');

        $this->assertDatabaseHas('vendor_settings', [
            'vendor_id' => $vendor->id,
            'payout_method' => 'mobile_money',
            'locale' => 'en',
        ]);
    }

    public function test_closing_temporarily_stores_and_clears_reason(): void
    {
        $user = $this->vendorUser();
        $vendor = Vendor::factory()->create(['user_id' => $user->id, 'status' => 'active']);

        Sanctum::actingAs($user);

        $this->patchJson('/api/v1/vendors/me', [
            'closed_at' => now()->toIso8601String(),
            'closed_reason' => 'Rupture d\'approvisionnement',
        ])
            ->assertOk()
            ->assertJsonPath('data.closed_reason', 'Rupture d\'approvisionnement');

        $this->assertDatabaseHas('vendors', [
            'id' => $vendor->id,
            'closed_reason' => 'Rupture d\'approvisionnement',
        ]);

        $this->patchJson('/api/v1/vendors/me', ['closed_at' => null])
            ->assertOk()
            ->assertJsonPath('data.closed_reason', null);

        $this->assertDatabaseHas('vendors', [
            'id' => $vendor->id,
            'closed_reason' => null,
        ]);
    }

    public function test_vendor_can_report_order_incident(): void
    {
        $user = $this->vendorUser();
        $vendor = Vendor::factory()->create(['user_id' => $user->id, 'status' => 'active']);
        $client = User::factory()->create();

        $order = Order::create([
            'reference' => '#BF5001',
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => 'accepted',
            'payment_status' => 'confirmed',
            'currency' => 'XOF',
            'subtotal' => 1000,
            'total' => 1000,
        ]);

        Sanctum::actingAs($user);

        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/incident", [
            'subject' => 'Livreur introuvable',
            'description' => 'Aucun livreur ne s\'est présenté après 30 minutes.',
            'type' => 'delivery',
        ])
            ->assertCreated()
            ->assertJsonPath('data.subject', 'Livreur introuvable');

        $this->assertDatabaseHas('complaints', [
            'user_id' => $user->id,
            'order_id' => $order->id,
            'type' => 'delivery',
        ]);
    }

    public function test_lists_selectable_delivery_zones(): void
    {
        DeliveryZone::factory()->create(['name' => 'Akpakpa', 'city' => 'Cotonou', 'is_active' => true]);
        DeliveryZone::factory()->create(['name' => 'Inactive', 'city' => 'Cotonou', 'is_active' => false]);

        $this->getJson('/api/v1/delivery/zones')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Akpakpa');
    }

    public function test_confirming_payment_sets_vendor_acceptance_deadline(): void
    {
        $user = $this->vendorUser();
        $vendor = Vendor::factory()->create(['user_id' => $user->id, 'status' => 'active']);
        $client = User::factory()->create();

        $order = Order::create([
            'reference' => '#BF6001',
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => 'awaiting_payment',
            'payment_status' => 'pending',
            'currency' => 'XOF',
            'subtotal' => 1000,
            'total' => 1000,
        ]);

        $this->assertNull($order->vendor_acceptance_deadline_at);

        app(OrderService::class)->confirmPayment($order, 1000);

        $this->assertNotNull($order->fresh()->vendor_acceptance_deadline_at);
    }

    private function vendorUser(): User
    {
        $user = User::factory()->create();
        $user->roles()->attach(Role::where('slug', 'vendor')->first()->id, ['is_active' => true]);

        return $user;
    }
}
