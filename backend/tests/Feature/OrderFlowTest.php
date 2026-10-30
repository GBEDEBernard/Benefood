<?php

namespace Tests\Feature;

use App\Enums\CartStatus;
use App\Enums\PaymentStatus;
use App\Models\Address;
use App\Models\Category;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\Order;
use App\Models\Product;
use App\Models\ProductImage;
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

    public function test_order_requires_pinned_delivery_address(): void
    {
        $client = $this->actingUser('client');
        $vendor = $this->activeVendor($client);
        $product = $this->vendorProduct($vendor, price: 500, stock: 10);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);
        $address->update(['latitude' => null, 'longitude' => null]);

        $this->addToCart($client, $product, 2);

        $this->postJson('/api/v1/orders', ['address_id' => $address->id])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'order.delivery_location_required');
    }

    public function test_commission_changes_apply_immediately_to_new_orders_only(): void
    {
        $client = $this->actingUser('client');
        $vendor = $this->activeVendor($client);
        $product = $this->vendorProduct($vendor, price: 1000, stock: 20);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);
        $this->addToCart($client, $product, 1);

        $this->postJson('/api/v1/orders/summary', ['address_id' => $address->id])
            ->assertOk()
            ->assertJsonPath('data.service_fee', 50)
            ->assertJsonPath('data.commission.rate', 10)
            ->assertJsonPath('data.total', 2550);

        $first = Order::where('reference', $this->placeOrder($client, $address))->firstOrFail();

        $admin = User::factory()->create();
        $admin->roles()->attach(Role::where('slug', 'admin-technique')->firstOrFail(), ['is_active' => true]);

        $this->actingAs($admin)->put(route('admin.commissions.platform-settings'), [
            'service_fee_rate' => 0,
            'delivery_commission_rate' => 0,
            'parcel_commission_rate' => 3,
            'gateway_fee_basis_points' => 120,
            'minimum_payout' => 1495,
        ])->assertRedirect();

        $this->actingAs($admin)->post(route('admin.commissions.store'), [
            'rate' => 20,
            'notes' => 'Nouvelle commission vendeur',
        ])->assertRedirect();

        $this->addToCart($client, $product, 1);

        $this->postJson('/api/v1/orders/summary', ['address_id' => $address->id])
            ->assertOk()
            ->assertJsonPath('data.service_fee', 0)
            ->assertJsonPath('data.commission.rate', 20)
            ->assertJsonPath('data.total', 2500);

        $second = Order::where('reference', $this->placeOrder($client, $address))->firstOrFail();

        $this->assertSame(50, $first->financials->service_fee);
        $this->assertSame(100, $first->financials->commission_amount);
        $this->assertSame(2550, $first->total);

        $this->assertSame(0, $second->financials->service_fee);
        $this->assertSame(0, $second->financials->delivery_commission_amount);
        $this->assertSame(200, $second->financials->commission_amount);
        $this->assertSame(2500, $second->total);
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
            // Commission client 5 % du sous-total produits uniquement.
            ->assertJsonPath('data.service_fee', 50)
            ->assertJsonPath('data.total', 2550)
            ->assertJsonPath('data.commission.rate', 10)
            ->assertJsonPath('data.commission.amount', 100)
            ->assertJsonPath('data.currency', 'XOF')
            ->assertJsonPath('data.delivery_zone.name', 'Cotonou Centre');

        $reference = $this->placeOrder($client, $address, ['notes' => 'Sonner avant de livrer']);

        $order = Order::where('reference', $reference)->first();

        $this->assertNotNull($order->reference);
        $this->assertSame(1000, $order->subtotal);
        $this->assertSame(2550, $order->total);
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

        $this->assertDatabaseHas('order_financials', [
            'order_id' => $order->id,
            'commission_amount' => 100,
            'service_fee' => 50,
            'vendor_amount' => 900,
            'delivery_commission_amount' => 300,
            'delivery_partner_amount' => 1200,
            'platform_amount' => 450,
            'total_client' => 2550,
        ]);
        $this->assertDatabaseHas('payments', ['order_id' => $order->id, 'status' => 'initiated', 'amount' => 2550]);
        $this->assertSame(8, $product->fresh()->stock_qty);
        $this->assertSame(CartStatus::Converted->value, $order->cart->fresh()->status->value);

        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.reference', $reference)
            ->assertJsonPath('data.status', 'awaiting_payment')
            ->assertJsonPath('data.items.0.unit_price', 500)
            ->assertJsonPath('data.items.0.image_url', null)
            ->assertJsonPath('data.customer.name', $client->name)
            ->assertJsonPath('data.customer.phone', $client->phone)
            ->assertJsonPath('data.notes', 'Sonner avant de livrer');
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
        $this->postJson("/api/v1/orders/{$order->id}/cancel", ['reason' => 'Plus besoin du repas'])
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

    public function test_vendor_can_list_own_orders(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);
        $reference = $this->placeOrder($client, $address);

        $this->actAs($vendorUser);

        $this->getJson('/api/v1/vendors/me/orders')
            ->assertOk()
            ->assertJsonFragment(['reference' => $reference]);
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
        $this->postJson("/api/v1/admin/orders/{$order->id}/cancel", ['reason' => 'Test administratif'])
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
        $product->update(['image_main' => 'products/piment-frais-01.webp']);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);
        $this->placeOrder($client, $address);

        $this->actAs($client);
        $this->getJson('/api/v1/orders')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.status', 'awaiting_payment')
            ->assertJsonPath('data.0.items.0.image_url', fn (string $url) => str_ends_with($url, '/storage/products/piment-frais-01.webp'));
    }

    public function test_orders_index_exposes_creation_and_payment_times(): void
    {
        $client = $this->actingUser('client');
        $vendor = $this->activeVendor($client);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);
        $reference = $this->placeOrder($client, $address);

        $order = Order::where('reference', $reference)->firstOrFail();
        $order->payment->update([
            'status' => PaymentStatus::Confirmed,
            'paid_at' => now(),
        ]);

        $this->actAs($client);
        $this->getJson('/api/v1/orders')
            ->assertOk()
            ->assertJsonPath('data.0.created_at', fn ($value) => $value !== null)
            ->assertJsonPath('data.0.payment.paid_at', fn ($value) => $value !== null);
    }

    public function test_order_items_fall_back_to_the_product_gallery_image(): void
    {
        $client = $this->actingUser('client');
        $vendor = $this->activeVendor($client);
        $product = $this->vendorProduct($vendor);
        $product->update(['image_main' => null]);
        ProductImage::create([
            'product_id' => $product->id,
            'path' => 'products/gallery-piment.webp',
            'is_main' => true,
            'sort_order' => 0,
        ]);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);
        $this->placeOrder($client, $address);

        $this->actAs($client);
        $this->getJson('/api/v1/orders')
            ->assertOk()
            ->assertJsonPath('data.0.items.0.image_url', fn (string $url) => str_ends_with($url, '/storage/products/gallery-piment.webp'));
    }
}
