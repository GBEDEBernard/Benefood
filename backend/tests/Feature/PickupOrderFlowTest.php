<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Models\Address;
use App\Models\Category;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Services\FinanceService;
use App\Services\OrderService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Paiement avant acceptation, retrait sur place et codes de collecte.
 */
class PickupOrderFlowTest extends TestCase
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

    private function activeVendor(User $owner): Vendor
    {
        return Vendor::factory()->create(['status' => 'active', 'user_id' => $owner->id]);
    }

    private function vendorProduct(Vendor $vendor, int $price = 500, int $stock = 10): Product
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

    private function deliverySetup(Vendor $vendor): void
    {
        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);
    }

    private function clientAddress(User $client): Address
    {
        return Address::factory()->create([
            'user_id' => $client->id,
            'city' => 'Cotonou',
            'latitude' => 6.3702932,
            'longitude' => 2.3912362,
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

    private function placeOrder(array $payload = []): Order
    {
        return Order::where(
            'reference',
            $this->postJson('/api/v1/orders', $payload)
                ->assertCreated()
                ->json('data.reference'),
        )->firstOrFail();
    }

    private function pay(Order $order): void
    {
        app(OrderService::class)->confirmPayment($order->fresh(), (int) $order->total);
    }

    private function progressToReady(Order $order, User $vendorUser): void
    {
        $this->actAs($vendorUser);
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/accept")
            ->assertOk()
            ->assertJsonPath('data.status', 'accepted');
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/preparing")
            ->assertOk()
            ->assertJsonPath('data.status', 'preparing');
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/ready")
            ->assertOk()
            ->assertJsonPath('data.status', 'ready');
    }

    public function test_vendor_cannot_accept_unpaid_online_order(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);
        $order = $this->placeOrder(['address_id' => $address->id]);

        $this->assertSame(OrderStatus::AwaitingPayment, $order->fresh()->status);

        $this->actAs($vendorUser);
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/accept")
            ->assertStatus(404)
            ->assertJsonPath('errors.0.code', 'not_found');

        $this->assertSame(OrderStatus::AwaitingPayment, $order->fresh()->status);
    }

    public function test_pickup_order_needs_no_address_and_costs_food_only(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);

        // Aucune zone ni tarif de livraison : le retrait ne doit pas en avoir besoin.
        $this->addToCart($client, $product);

        $this->postJson('/api/v1/orders/summary', ['fulfillment_method' => 'pickup'])
            ->assertOk()
            ->assertJsonPath('data.fulfillment_method', 'pickup')
            ->assertJsonPath('data.subtotal', 1000)
            ->assertJsonPath('data.delivery_fee', 0)
            ->assertJsonPath('data.approach_fee', 0)
            ->assertJsonPath('data.total', 1000);

        $order = $this->placeOrder(['fulfillment_method' => 'pickup']);

        $this->assertSame('pickup', $order->fulfillment_method->value);
        $this->assertSame(1000, $order->subtotal);
        $this->assertSame(0, $order->delivery_fee);
        $this->assertSame(0, $order->approach_fee);
        $this->assertSame(1000, $order->total);
        $this->assertNull($order->address_snapshot);
        $this->assertNull($order->delivery_rate_snapshot);
        $this->assertNull($order->zone_id);
        $this->assertDatabaseMissing('deliveries', ['order_id' => $order->id]);

        $this->actAs($client);
        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.fulfillment_method', 'pickup')
            ->assertJsonPath('data.total', 1000)
            ->assertJsonPath('data.delivery', null);
    }

    public function test_client_confirms_self_pickup_with_code_and_funds_are_released(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);

        $this->addToCart($client, $product);
        $order = $this->placeOrder(['fulfillment_method' => 'pickup']);
        $this->pay($order);
        $this->progressToReady($order, $vendorUser);

        $this->assertDatabaseMissing('deliveries', ['order_id' => $order->id]);

        $this->actAs($client);
        $show = $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.status', 'ready')
            ->assertJsonPath('data.fulfillment_method', 'pickup');
        $code = $show->json('data.confirmation_code');
        $this->assertMatchesRegularExpression('/^\d{6}$/', (string) $code);

        $finance = app(FinanceService::class);
        $vendorWallet = $finance->walletFor($vendor);
        $this->assertSame(900, (int) $vendorWallet->fresh()->pending_balance);
        $this->assertSame(0, (int) $vendorWallet->fresh()->available_balance);

        $this->postJson("/api/v1/orders/{$order->id}/confirm-pickup", [
            'confirmation_code' => (string) $code,
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'delivered');

        $this->assertSame(OrderStatus::Delivered, $order->fresh()->status);
        $this->assertNotNull($order->fresh()->delivered_at);
        $this->assertSame(0, (int) $vendorWallet->fresh()->pending_balance);
        $this->assertSame(900, (int) $vendorWallet->fresh()->available_balance);
    }

    public function test_wrong_confirmation_code_cannot_confirm_self_pickup(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);

        $this->addToCart($client, $product);
        $order = $this->placeOrder(['fulfillment_method' => 'pickup']);
        $this->pay($order);
        $this->progressToReady($order, $vendorUser);

        $this->actAs($client);
        $this->postJson("/api/v1/orders/{$order->id}/confirm-pickup", [
            'confirmation_code' => '000000',
        ])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'order.wrong_confirmation_code');

        $this->assertSame(OrderStatus::Ready, $order->fresh()->status);
        $this->assertSame(1, (int) $order->fresh()->confirmation_code_attempts);
    }

    public function test_vendor_pickup_code_is_hidden_from_client_and_driver(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $driverUser = $this->actingUser('driver-independent');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);
        $driver = DriverProfile::factory()->create([
            'user_id' => $driverUser->id,
            'status' => 'active',
            'available' => true,
        ]);

        $this->addToCart($client, $product);
        $order = $this->placeOrder(['address_id' => $address->id]);
        $this->pay($order);
        $this->progressToReady($order, $vendorUser);

        $this->actAs($driverUser);
        $offers = $this->getJson('/api/v1/driver/me/deliveries/offers')->assertOk()->json('data');
        $deliveryId = collect($offers)->firstWhere('order.id', $order->id)['id'];
        $this->postJson("/api/v1/driver/me/deliveries/{$deliveryId}/accept")->assertOk();

        $deliveryResponse = $this->getJson('/api/v1/driver/me/deliveries')->assertOk();
        $this->assertArrayNotHasKey('pickup_code', $deliveryResponse->json('data.0'));

        $this->actAs($client);
        $clientOrder = $this->getJson("/api/v1/orders/{$order->id}")->assertOk();
        $this->assertArrayNotHasKey('vendor_pickup_code', $clientOrder->json('data'));

        $this->actAs($vendorUser);
        $vendorOrder = $this->getJson("/api/v1/vendors/me/orders/{$order->id}")->assertOk();
        $this->assertMatchesRegularExpression('/^\d{6}$/', (string) $vendorOrder->json('data.vendor_pickup_code'));
    }

    public function test_wrong_vendor_pickup_code_blocks_collection(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $driverUser = $this->actingUser('driver-independent');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);
        DriverProfile::factory()->create([
            'user_id' => $driverUser->id,
            'status' => 'active',
            'available' => true,
        ]);

        $this->addToCart($client, $product);
        $order = $this->placeOrder(['address_id' => $address->id]);
        $this->pay($order);
        $this->progressToReady($order, $vendorUser);

        $this->actAs($driverUser);
        $offers = $this->getJson('/api/v1/driver/me/deliveries/offers')->assertOk()->json('data');
        $deliveryId = collect($offers)->firstWhere('order.id', $order->id)['id'];
        $this->postJson("/api/v1/driver/me/deliveries/{$deliveryId}/accept")->assertOk();

        $this->postJson("/api/v1/driver/me/deliveries/{$deliveryId}/pickup", [
            'pickup_code' => '000000',
        ])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'delivery.wrong_confirmation_code');

        $this->assertSame(OrderStatus::Assigned, $order->fresh()->status);

        $this->actAs($vendorUser);
        $code = $this->getJson("/api/v1/vendors/me/orders/{$order->id}")
            ->assertOk()
            ->json('data.vendor_pickup_code');

        $this->actAs($driverUser);
        $this->postJson("/api/v1/driver/me/deliveries/{$deliveryId}/pickup", [
            'pickup_code' => (string) $code,
        ])->assertOk()->assertJsonPath('data.status', 'picked_up');

        $this->assertSame(OrderStatus::PickedUp, $order->fresh()->status);
    }
}
