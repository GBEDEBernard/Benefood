<?php

namespace Tests\Feature;

use App\Enums\CartStatus;
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

class OrderFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function actingUser(string $roleSlug, array $attributes = []): User
    {
        $user = User::factory()->create(array_merge(['phone' => fake()->unique()->numerify('+22997######')], $attributes));
        $role = Role::where('slug', $roleSlug)->firstOrFail();
        $user->roles()->attach($role, ['is_active' => true]);

        Sanctum::actingAs($user);

        return $user;
    }

    private function actAs(User $user): void
    {
        Sanctum::actingAs($user);
    }

    private function deliverySetup(Vendor $vendor): DeliveryZone
    {
        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);

        return $zone;
    }

    private function vendorProduct(Vendor $vendor, int $price = 500, ?int $stock = 10): Product
    {
        return Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'name' => 'Piment frais',
            'price' => $price,
            'stock_qty' => $stock,
            'is_active' => true,
            'is_available' => true,
        ]);
    }

    private function activeVendor(User $owner): Vendor
    {
        return Vendor::factory()->create(['status' => 'active', 'user_id' => $owner->id]);
    }

    private function clientAddress(User $user): Address
    {
        return Address::factory()->create([
            'user_id' => $user->id,
            'city' => 'Cotonou',
        ]);
    }

    private function addToCart(User $client, Product $product, int $quantity = 2): void
    {
        $this->actAs($client);

        $this->postJson('/api/v1/cart/items', [
            'product_id' => $product->id,
            'quantity' => $quantity,
        ])->assertOk();
    }

    private function placeOrder(User $client, Address $address, array $overrides = []): string
    {
        $this->actAs($client);

        return $this->postJson('/api/v1/orders', array_merge([
            'address_id' => $address->id,
        ], $overrides))
            ->assertCreated()
            ->json('data.reference');
    }

    public function test_client_can_create_full_order_with_server_totals(): void
    {
        $client = $this->actingUser('client');
        $vendor = $this->activeVendor($client);
        $product = $this->vendorProduct($vendor, price: 500, stock: 10);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product, 2);

        $this->postJson('/api/v1/orders/summary', ['address_id' => $address->id])
            ->assertOk()
            ->assertJsonPath('data.subtotal', 1000)
            ->assertJsonPath('data.delivery_fee', 1500)
            ->assertJsonPath('data.total', 2500)
            ->assertJsonPath('data.commission.rate', 10)
            ->assertJsonPath('data.commission.amount', 100)
            ->assertJsonPath('data.currency', 'XOF');

        $reference = $this->placeOrder($client, $address, ['notes' => 'Sonner avant de livrer']);

        $order = Order::where('reference', $reference)->first();

        $this->assertNotNull($order->reference);
        $this->assertSame(1000, $order->subtotal);
        $this->assertSame(2500, $order->total);
        $this->assertNotNull($order->address_snapshot);
        $this->assertSame('Sonner avant de livrer', $order->address_snapshot['notes']);
        $this->assertSame(1500, $order->delivery_rate_snapshot['price']);
        $this->assertSame('Cotonou Centre', $order->delivery_rate_snapshot['zone_name']);

        $this->assertDatabaseHas('order_items', [
            'order_id' => $order->id,
            'product_id' => $product->id,
            'name_snapshot' => 'Piment frais',
            'unit_price_snapshot' => 500,
            'quantity' => 2,
            'subtotal' => 1000,
        ]);

        $this->assertDatabaseHas('order_financials', ['order_id' => $order->id, 'commission_amount' => 100]);
        $this->assertDatabaseHas('payments', ['order_id' => $order->id, 'status' => 'initiated', 'amount' => 2500]);
        $this->assertSame(8, $product->fresh()->stock_qty);
        $this->assertSame(CartStatus::Converted->value, $order->cart->fresh()->status->value);

        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.reference', $reference)
            ->assertJsonPath('data.status', 'awaiting_payment')
            ->assertJsonPath('data.items.0.unit_price', 500);
    }

    public function test_order_rejects_empty_cart(): void
    {
        $client = $this->actingUser('client');
        $vendor = $this->activeVendor($client);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->postJson('/api/v1/orders', ['address_id' => $address->id])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'order.empty_cart');
    }

    public function test_order_rejects_vendor_closed(): void
    {
        $client = $this->actingUser('client');
        $vendor = $this->activeVendor($client);
        $vendor->hours()->create(['day_of_week' => (int) now()->format('w'), 'is_closed' => true]);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);

        $this->postJson('/api/v1/orders', ['address_id' => $address->id])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'order.vendor_closed');
    }

    public function test_order_rejects_unavailable_item(): void
    {
        $client = $this->actingUser('client');
        $vendor = $this->activeVendor($client);
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'stock_qty' => 5,
            'is_active' => true,
            'is_available' => true,
        ]);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);

        $product->update(['is_active' => false, 'is_available' => false]);

        $this->postJson('/api/v1/orders', ['address_id' => $address->id])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'order.product_unavailable');
    }

    public function test_client_can_cancel_awaiting_order_and_stock_is_restored(): void
    {
        $client = $this->actingUser('client');
        $vendor = $this->activeVendor($client);
        $product = $this->vendorProduct($vendor, stock: 10);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product, 2);
        $reference = $this->placeOrder($client, $address);

        $order = Order::where('reference', $reference)->first();
        $this->assertSame(8, $product->fresh()->stock_qty);

        $this->actAs($client);
        $this->postJson("/api/v1/orders/{$order->id}/cancel")
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');

        $this->assertSame(10, $product->fresh()->stock_qty);
        $this->assertDatabaseHas('payments', ['order_id' => $order->id, 'status' => 'cancelled']);
        $this->assertDatabaseHas('order_status_history', [
            'order_id' => $order->id,
            'to_status' => 'cancelled',
            'actor_type' => 'client',
        ]);
    }

    public function test_vendor_can_accept_and_refuse_orders(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);
        $acceptedRef = $this->placeOrder($client, $address);

        $this->addToCart($client, $product);
        $refusedRef = $this->placeOrder($client, $address);

        $accepted = Order::where('reference', $acceptedRef)->first();
        $refused = Order::where('reference', $refusedRef)->first();

        $this->actAs($vendorUser);
        $this->postJson("/api/v1/vendors/me/orders/{$accepted->id}/accept")
            ->assertOk()
            ->assertJsonPath('data.status', 'accepted');

        $this->assertNotNull($accepted->fresh()->accepted_at);

        $this->postJson("/api/v1/vendors/me/orders/{$refused->id}/refuse", ['reason' => 'Plus de stock'])
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');

        $this->assertSame('Plus de stock', $refused->fresh()->cancellation_reason);
    }

    public function test_vendor_cannot_accept_other_vendor_order(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);
        $reference = $this->placeOrder($client, $address);
        $order = Order::where('reference', $reference)->first();

        $otherVendorUser = $this->actingUser('vendor');
        $this->activeVendor($otherVendorUser);

        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/accept")
            ->assertStatus(404);
    }

    public function test_admin_can_cancel_any_awaiting_order(): void
    {
        $client = $this->actingUser('client');
        $vendor = $this->activeVendor($client);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);
        $reference = $this->placeOrder($client, $address);
        $order = Order::where('reference', $reference)->first();

        $this->actingUser('admin-technique');
        $this->postJson("/api/v1/admin/orders/{$order->id}/cancel")
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');
    }

    public function test_client_cannot_view_foreign_order(): void
    {
        $client = $this->actingUser('client');
        $vendor = $this->activeVendor($client);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);
        $reference = $this->placeOrder($client, $address);
        $order = Order::where('reference', $reference)->first();

        $other = $this->actingUser('client');
        $this->assertNotSame($other->id, $order->user_id);

        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertStatus(404)
            ->assertJsonPath('errors.0.code', 'not_found');
    }

    public function test_client_orders_index_lists_own_orders(): void
    {
        $client = $this->actingUser('client');
        $vendor = $this->activeVendor($client);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);
        $this->placeOrder($client, $address);

        $this->actAs($client);
        $this->getJson('/api/v1/orders')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.status', 'awaiting_payment');
    }
}
