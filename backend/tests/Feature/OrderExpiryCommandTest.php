<?php

namespace Tests\Feature;

use App\Enums\VendorStatus;
use App\Models\Address;
use App\Models\Category;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\Order;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderExpiryCommandTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function actingUser(string $roleSlug): User
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22997######')]);
        $role = Role::where('slug', $roleSlug)->firstOrFail();
        $user->roles()->attach($role, ['is_active' => true]);
        Sanctum::actingAs($user);

        return $user;
    }

    private function createOrder(): Order
    {
        $client = $this->actingUser('client');
        $vendor = Vendor::factory()->create(['status' => VendorStatus::Active->value, 'user_id' => $client->id]);
        $category = Category::factory()->create();
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'stock_qty' => 10,
        ]);
        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);
        $address = Address::factory()->create(['user_id' => $client->id, 'city' => 'Cotonou']);

        $this->postJson('/api/v1/cart/items', [
            'product_id' => $product->id,
            'quantity' => 2,
        ])->assertOk();

        $reference = $this->postJson('/api/v1/orders', ['address_id' => $address->id])
            ->assertCreated()
            ->json('data.reference');

        return Order::where('reference', $reference)->first();
    }

    public function test_expire_unpaid_orders_cancels_expired_and_restores_stock(): void
    {
        $order = $this->createOrder();
        $product = $order->items->first()->product;
        $this->assertSame(8, $product->fresh()->stock_qty);

        $order->update([
            'payment_deadline_at' => now()->subMinute(),
        ]);

        $this->artisan('orders:expire-unpaid')
            ->assertSuccessful()
            ->expectsOutput('1 commande(s) expirée(s) pour paiement manquant.');

        $order->refresh();

        $this->assertSame('cancelled', $order->status->value);
        $this->assertSame('Paiement non reçu avant la date limite.', $order->cancellation_reason);
        $this->assertDatabaseHas('payments', ['order_id' => $order->id, 'status' => 'expired']);
        $this->assertDatabaseHas('order_status_history', [
            'order_id' => $order->id,
            'to_status' => 'cancelled',
            'actor_type' => 'system',
            'reason' => 'paiement expiré',
        ]);
        $this->assertSame(10, $product->fresh()->stock_qty);
    }

    public function test_expire_unpaid_orders_ignores_fresh_orders(): void
    {
        $order = $this->createOrder();
        $product = $order->items->first()->product;

        $this->artisan('orders:expire-unpaid')
            ->assertSuccessful()
            ->expectsOutput('0 commande(s) expirée(s) pour paiement manquant.');

        $this->assertSame('awaiting_payment', $order->fresh()->status->value);
        $this->assertSame(8, $product->fresh()->stock_qty);
    }

    public function test_expire_unpaid_orders_handles_multiple_orders(): void
    {
        $first = $this->createOrder();
        $second = $this->createOrder();

        $first->update(['payment_deadline_at' => now()->subHour()]);

        $this->artisan('orders:expire-unpaid')
            ->assertSuccessful()
            ->expectsOutput('1 commande(s) expirée(s) pour paiement manquant.');

        $this->assertSame('cancelled', $first->fresh()->status->value);
        $this->assertSame('awaiting_payment', $second->fresh()->status->value);
    }
}
