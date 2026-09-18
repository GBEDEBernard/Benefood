<?php

namespace Tests\Feature;

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
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderDeliveryTrackingTest extends TestCase
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

    private function activeVendor(User $owner): Vendor
    {
        return Vendor::factory()->create(['status' => 'active', 'user_id' => $owner->id]);
    }

    private function clientAddress(User $user): Address
    {
        return Address::factory()->create([
            'user_id' => $user->id,
            'city' => 'Cotonou',
            'latitude' => 6.3702932,
            'longitude' => 2.3912362,
        ]);
    }

    /** Crée un profil livreur actif et disponible (J175/J177). */
    private function activeDriver(User $driverUser): DriverProfile
    {
        return DriverProfile::factory()->create([
            'user_id' => $driverUser->id,
            'status' => 'active',
            'available' => true,
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

    /** Commande passée par le client (awaiting_payment). */
    private function placeOrder(User $client, Address $address): Order
    {
        $this->actAs($client);

        return Order::where(
            'reference',
            $this->postJson('/api/v1/orders', ['address_id' => $address->id])
                ->assertCreated()
                ->json('data.reference'),
        )->firstOrFail();
    }

    /** Achemine la commande jusqu'au statut "prête" (création de la course). */
    private function readyOrder(Order $order, User $vendorUser, Vendor $vendor, Product $product): void
    {
        $this->actAs($vendorUser);

        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/accept")
            ->assertJsonPath('data.status', 'accepted');

        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/preparing")
            ->assertJsonPath('data.status', 'preparing');

        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/ready")
            ->assertJsonPath('data.status', 'ready');

        $this->assertDatabaseHas('deliveries', ['order_id' => $order->id, 'status' => 'assigned']);
    }

    public function test_driver_can_update_location_and_goes_offline_purges_it(): void
    {
        $driver = $this->activeDriver($this->actingUser('driver-independent'));

        $this->postJson('/api/v1/driver/me/availability', ['available' => true])
            ->assertOk();

        $this->patchJson('/api/v1/driver/me/availability/location', [
            'latitude' => 6.3745678,
            'longitude' => 2.3901234,
        ])->assertOk();

        $fresh = $driver->fresh();
        $this->assertSame(6.3745678, (float) $fresh->last_latitude);
        $this->assertSame(2.3901234, (float) $fresh->last_longitude);
        $this->assertNotNull($fresh->last_location_at);

        $this->postJson('/api/v1/driver/me/availability', ['available' => false])
            ->assertOk()
            ->assertJsonPath('data.available', false);

        $offline = $fresh->fresh();
        $this->assertNull($offline->last_latitude);
        $this->assertNull($offline->last_longitude);
        $this->assertNull($offline->last_location_at);
    }

    public function test_client_sees_driver_position_during_delivery_but_not_after(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);
        $driver = $this->activeDriver($this->actingUser('driver-independent'));

        $this->addToCart($client, $product);
        $order = $this->placeOrder($client, $address);
        $this->readyOrder($order, $vendorUser, $vendor, $product);

        $this->actAs($driver->user);
        $offers = $this->getJson('/api/v1/driver/me/deliveries/offers')->assertOk()->json('data');
        $deliveryId = collect($offers)->firstWhere('order.id', $order->id)['id'];

        $this->postJson("/api/v1/driver/me/deliveries/{$deliveryId}/accept")->assertOk();

        $this->patchJson('/api/v1/driver/me/availability/location', [
            'latitude' => 6.3712345,
            'longitude' => 2.3923456,
        ])->assertOk();

        $this->postJson("/api/v1/driver/me/deliveries/{$deliveryId}/pickup")
            ->assertOk();
        $this->postJson("/api/v1/driver/me/deliveries/{$deliveryId}/start")
            ->assertOk();

        $this->actAs($client);
        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.delivery.id', $deliveryId)
            ->assertJsonPath('data.delivery.status', 'in_delivery')
            ->assertJsonPath('data.delivery.driver.name', $driver->user->name)
            ->assertJsonPath('data.delivery.driver.vehicle', $driver->vehicle)
            ->assertJsonPath('data.delivery.position.latitude', 6.371)
            ->assertJsonPath('data.delivery.position.longitude', 2.392)
            ->assertJsonPath('data.delivery.position.last_location_at', $driver->fresh()->last_location_at?->toIso8601String());

        $this->assertTrue(
            is_numeric($this->getJson("/api/v1/orders/{$order->id}")->json('data.delivery.position.distance_km')),
        );

        $this->actAs($driver->user);
        $this->postJson("/api/v1/driver/me/deliveries/{$deliveryId}/deliver", ['proof_code' => 'ok'])
            ->assertOk();

        $this->actAs($client);
        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.delivery.status', 'delivered')
            ->assertJsonPath('data.delivery.driver.name', $driver->user->name)
            ->assertJsonPath('data.delivery.position', null);
    }

    public function test_position_is_hidden_until_driver_is_assigned(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = $this->clientAddress($client);

        $this->addToCart($client, $product);
        $order = $this->placeOrder($client, $address);
        $this->readyOrder($order, $vendorUser, $vendor, $product);

        $this->actAs($client);
        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.delivery.status', 'assigned')
            ->assertJsonPath('data.delivery.driver', null)
            ->assertJsonPath('data.delivery.position', null);
    }
}
