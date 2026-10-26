<?php

namespace Tests\Feature;

use App\Models\Address;
use App\Models\Category;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Services\ParcelService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DriverSelectionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);

        config()->set('beninfood.routing.google_key', null);
        config()->set('beninfood.routing.ors_key', null);
        config()->set('beninfood.routing.allow_public_osrm', true);
        config()->set('beninfood.routing.osrm_url', 'https://router.project-osrm.org');
        config()->set('beninfood.driver_selection.radius_km', 5);
        config()->set('beninfood.driver_selection.max_radius_km', 15);

        Http::fake([
            'router.project-osrm.org/*' => Http::response([
                'routes' => [[
                    'distance' => 3000,
                    'duration' => 900,
                    'geometry' => ['coordinates' => [
                        [2.390, 6.365],
                        [2.391, 6.366],
                        [2.392, 6.370],
                    ]],
                    'legs' => [
                        ['distance' => 1000, 'duration' => 300],
                        ['distance' => 2000, 'duration' => 600],
                    ],
                ]],
            ]),
        ]);
    }

    private function actingUser(string $roleSlug): User
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22997######')]);
        $user->roles()->attach(Role::where('slug', $roleSlug)->firstOrFail(), ['is_active' => true]);

        Sanctum::actingAs($user);

        return $user;
    }

    private function actAs(User $user): void
    {
        Sanctum::actingAs($user);
    }

    private function driver(string $name, float $latitude, float $longitude, array $attributes = []): DriverProfile
    {
        $user = User::factory()->create([
            'name' => $name,
            'phone' => fake()->unique()->numerify('+22996######'),
        ]);
        $user->roles()->attach(Role::where('slug', 'driver-independent')->firstOrFail(), ['is_active' => true]);

        return DriverProfile::factory()->create(array_merge([
            'user_id' => $user->id,
            'status' => 'active',
            'available' => true,
            'last_latitude' => $latitude,
            'last_longitude' => $longitude,
            'last_location_at' => now(),
            'rating' => 4.8,
            'vehicle' => 'Moto',
        ], $attributes));
    }

    private function addToCart(User $client, Product $product): void
    {
        $this->actAs($client);

        $this->postJson('/api/v1/cart/items', [
            'product_id' => $product->id,
            'quantity' => 2,
        ])->assertOk();
    }

    /**
     * @return array{0: User, 1: User, 2: Vendor, 3: Order}
     */
    private function paidOrderSetup(): array
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = Vendor::factory()->create(['status' => 'active', 'user_id' => $vendorUser->id]);
        $vendor->update([
            'latitude' => 6.365,
            'longitude' => 2.390,
            'pickup_latitude' => 6.365,
            'pickup_longitude' => 2.390,
            'pickup_address' => 'Marché Dantokpa',
            'pickup_landmark' => 'Entrée nord',
            'city' => 'Cotonou',
        ]);

        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'name' => 'Piment frais',
            'price' => 500,
            'stock_qty' => 10,
            'is_active' => true,
            'is_available' => true,
        ]);

        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);

        $address = Address::factory()->create([
            'user_id' => $client->id,
            'city' => 'Cotonou',
            'latitude' => 6.3702932,
            'longitude' => 2.3912362,
        ]);

        $this->addToCart($client, $product);
        $order = Order::where(
            'reference',
            $this->postJson('/api/v1/orders', ['address_id' => $address->id])
                ->assertCreated()
                ->json('data.reference'),
        )->firstOrFail();

        $order->update(['status' => 'paid']);

        return [$client, $vendorUser, $vendor, $order];
    }

    private function readyOrder(Order $order, User $vendorUser): void
    {
        $this->actAs($vendorUser);

        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/accept")->assertOk();
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/preparing")->assertOk();
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/ready")->assertOk();
    }

    public function test_nearby_drivers_are_private_fresh_and_use_road_distances(): void
    {
        [$client, $vendorUser, , $order] = $this->paidOrderSetup();

        $near = $this->driver('Livreur Proche', 6.366, 2.391);
        $this->driver('Livreur Loin', 6.55, 2.55);
        $this->driver('GPS Ancien', 6.366, 2.391, ['last_location_at' => now()->subHour()]);
        $this->driver('Hors Ligne', 6.366, 2.391, ['available' => false]);
        $this->driver('Compte Suspendu', 6.366, 2.391, ['status' => 'validated']);

        Parcel::create([
            'reference' => 'COL-COMPLETED-1',
            'user_id' => $client->id,
            'driver_profile_id' => $near->id,
            'status' => 'delivered',
            'payment_status' => 'confirmed',
            'pickup_snapshot' => [],
            'dropoff_snapshot' => [],
            'delivery_fee' => 1000,
            'platform_amount' => 200,
            'delivered_at' => now(),
        ]);

        $intruder = $this->actingUser('client');
        $this->getJson("/api/v1/orders/{$order->id}/nearby-drivers")->assertNotFound();

        $this->actAs($client);
        $response = $this->getJson("/api/v1/orders/{$order->id}/nearby-drivers")
            ->assertOk()
            ->assertJsonPath('data.radius_km', 5)
            ->assertJsonPath('data.drivers.0.id', $near->id)
            ->assertJsonPath('data.drivers.0.name', 'Livreur Proche')
            ->assertJsonPath('data.drivers.0.vehicle', 'Moto')
            ->assertJsonPath('data.drivers.0.completed_deliveries', 1)
            ->assertJsonPath('data.drivers.0.distance_to_pickup_km', 1)
            ->assertJsonPath('data.drivers.0.eta_to_pickup_s', 390)
            ->assertJsonPath('data.drivers.0.pickup_to_dropoff_km', 2)
            ->assertJsonPath('data.drivers.0.eta_to_dropoff_s', 780)
            ->assertJsonPath('data.drivers.0.distance_to_dropoff_km', 3)
            ->assertJsonPath('data.drivers.0.eta_total_s', 1170)
            ->assertJsonPath('data.drivers.0.position.latitude', 6.366)
            ->assertJsonMissingPath('data.drivers.0.phone')
            ->assertJsonMissingPath('data.drivers.0.position.phone');

        $drivers = $response->json('data.drivers');
        $this->assertCount(1, $drivers);
        $this->assertArrayNotHasKey('phone', $drivers[0]);
        $this->assertNull($response->json('data.request'));
    }

    public function test_order_request_is_pending_until_ready_then_driver_accepts(): void
    {
        [$client, $vendorUser, , $order] = $this->paidOrderSetup();
        $driver = $this->driver('Livreur Proche', 6.366, 2.391);

        $this->actAs($client);
        $request = $this->postJson("/api/v1/orders/{$order->id}/driver-request", [
            'driver_profile_id' => $driver->id,
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.driver.id', $driver->id)
            ->assertJsonPath('data.offered_at', null)
            ->assertJsonPath('data.expires_at', null)
            ->assertJsonMissingPath('data.driver.phone');

        $this->assertDatabaseHas('orders', [
            'id' => $order->id,
            'preferred_driver_profile_id' => $driver->id,
        ]);
        $this->assertDatabaseHas('driver_assignment_requests', [
            'id' => $request->json('data.id'),
            'status' => 'pending',
            'offered_at' => null,
            'expires_at' => null,
        ]);

        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.driver_request.status', 'pending')
            ->assertJsonMissingPath('data.driver_request.driver.phone');

        $this->readyOrder($order, $vendorUser);

        $this->actAs($client);
        $offered = $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.driver_request.status', 'pending');
        $this->assertNotNull($offered->json('data.driver_request.offered_at'));
        $this->assertNotNull($offered->json('data.driver_request.expires_at'));

        $this->actAs($driver->user);
        $offers = $this->getJson('/api/v1/driver/me/deliveries/offers')->assertOk()->json('data');
        $offer = collect($offers)->firstWhere('order.id', $order->id);
        $this->assertNotNull($offer);

        $other = $this->driver('Autre Livreur', 6.366, 2.392);
        $this->actAs($other->user);
        $this->assertEmpty($this->getJson('/api/v1/driver/me/deliveries/offers')->json('data'));
        $this->postJson("/api/v1/driver/me/deliveries/{$offer['id']}/accept")->assertStatus(409);

        $this->actAs($driver->user);
        $this->postJson("/api/v1/driver/me/deliveries/{$offer['id']}/accept")->assertOk();

        $this->actAs($client);
        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.status', 'assigned')
            ->assertJsonPath('data.driver_request.status', 'accepted')
            ->assertJsonPath('data.delivery.driver.id', $driver->id)
            ->assertJsonPath('data.delivery.driver.phone', $driver->user->phone);
    }

    public function test_client_request_remains_targeted_when_vendor_selects_another_driver(): void
    {
        [$client, $vendorUser, , $order] = $this->paidOrderSetup();
        $chosen = $this->driver('Livreur Choisi', 6.366, 2.391);
        $vendorChoice = $this->driver('Choix Vendeur', 6.367, 2.392);

        $this->actAs($client);
        $requestId = $this->postJson("/api/v1/orders/{$order->id}/driver-request", [
            'driver_profile_id' => $chosen->id,
        ])->assertCreated()->json('data.id');

        $this->actAs($vendorUser);
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/accept")->assertOk();
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/preparing")->assertOk();
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/ready", [
            'favorite_driver_id' => $vendorChoice->id,
        ])->assertOk();

        $this->assertDatabaseHas('orders', [
            'id' => $order->id,
            'preferred_driver_profile_id' => $chosen->id,
        ]);
        $this->assertDatabaseHas('deliveries', [
            'order_id' => $order->id,
            'targeted_driver_profile_id' => $chosen->id,
        ]);
        $this->assertDatabaseHas('driver_assignment_requests', [
            'id' => $requestId,
            'status' => 'pending',
        ]);

        $this->actAs($vendorChoice->user);
        $this->assertEmpty($this->getJson('/api/v1/driver/me/deliveries/offers')->json('data'));

        $this->actAs($chosen->user);
        $offers = $this->getJson('/api/v1/driver/me/deliveries/offers')->assertOk()->json('data');
        $offer = collect($offers)->firstWhere('order.id', $order->id);

        $this->assertNotNull($offer);
    }

    public function test_driver_refusal_releases_order_for_another_driver(): void
    {
        [$client, $vendorUser, , $order] = $this->paidOrderSetup();
        $first = $this->driver('Premier Livreur', 6.366, 2.391);
        $second = $this->driver('Second Livreur', 6.367, 2.392);

        $this->actAs($client);
        $requestId = $this->postJson("/api/v1/orders/{$order->id}/driver-request", [
            'driver_profile_id' => $first->id,
        ])->assertCreated()->json('data.id');

        $this->readyOrder($order, $vendorUser);

        $this->actAs($first->user);
        $deliveryId = $this->getJson('/api/v1/driver/me/deliveries/offers')
            ->assertOk()
            ->json('data.0.id');

        $this->postJson("/api/v1/driver/me/deliveries/{$deliveryId}/decline", [
            'reason' => 'Trop loin finalement',
        ])->assertOk();

        $this->assertDatabaseHas('driver_assignment_requests', [
            'id' => $requestId,
            'status' => 'refused',
            'refusal_reason' => 'Trop loin finalement',
        ]);
        $this->assertDatabaseHas('orders', [
            'id' => $order->id,
            'preferred_driver_profile_id' => null,
        ]);
        $this->assertDatabaseHas('deliveries', [
            'id' => $deliveryId,
            'targeted_driver_profile_id' => null,
        ]);

        $this->actAs($second->user);
        $offers = $this->getJson('/api/v1/driver/me/deliveries/offers')->assertOk()->json('data');
        $offer = collect($offers)->firstWhere('order.id', $order->id);
        $this->assertNotNull($offer);

        $this->postJson("/api/v1/driver/me/deliveries/{$offer['id']}/accept")->assertOk();

        $this->actAs($client);
        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.driver_request.status', 'refused')
            ->assertJsonPath('data.delivery.driver.id', $second->id);
    }

    public function test_expired_driver_request_releases_target_and_allows_another_driver(): void
    {
        config()->set('beninfood.driver_selection.request_ttl_s', 5);

        [$client, $vendorUser, , $order] = $this->paidOrderSetup();
        $first = $this->driver('Premier Livreur', 6.366, 2.391);
        $second = $this->driver('Second Livreur', 6.367, 2.392);

        $this->actAs($client);
        $requestId = $this->postJson("/api/v1/orders/{$order->id}/driver-request", [
            'driver_profile_id' => $first->id,
        ])->assertCreated()->json('data.id');

        $this->readyOrder($order, $vendorUser);
        $this->travel(6)->seconds();

        $this->actAs($client);
        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.driver_request.status', 'expired');

        $this->assertDatabaseHas('driver_assignment_requests', [
            'id' => $requestId,
            'status' => 'expired',
        ]);
        $this->assertDatabaseHas('orders', [
            'id' => $order->id,
            'preferred_driver_profile_id' => null,
        ]);

        $this->actAs($second->user);
        $offers = $this->getJson('/api/v1/driver/me/deliveries/offers')->assertOk()->json('data');
        $offer = collect($offers)->firstWhere('order.id', $order->id);
        $this->assertNotNull($offer);

        $this->postJson("/api/v1/driver/me/deliveries/{$offer['id']}/accept")->assertOk();

        $this->actAs($client);
        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.status', 'assigned')
            ->assertJsonPath('data.delivery.driver.id', $second->id);
    }

    public function test_parcel_nearby_request_refusal_and_acceptance(): void
    {
        $client = $this->actingUser('client');
        $driver = $this->driver('Livreur Colis', 6.366, 2.391);

        $services = app(ParcelService::class);
        $parcel = $services->create(
            $client,
            ['label' => 'Carrefour Jericho', 'city' => 'Cotonou', 'landmark' => 'Face pharmacie', 'latitude' => 6.365, 'longitude' => 2.390],
            ['label' => 'Ganhi', 'city' => 'Cotonou', 'landmark' => 'Derrière le marché', 'latitude' => 6.370, 'longitude' => 2.392],
        );
        $services->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);

        $this->actAs($client);
        $this->getJson("/api/v1/parcels/{$parcel->id}/nearby-drivers")
            ->assertOk()
            ->assertJsonPath('data.drivers.0.id', $driver->id)
            ->assertJsonMissingPath('data.drivers.0.phone');

        $requestId = $this->postJson("/api/v1/parcels/{$parcel->id}/driver-request", [
            'driver_profile_id' => $driver->id,
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.driver.id', $driver->id)
            ->assertJsonMissingPath('data.driver.phone')
            ->json('data.id');

        $this->assertDatabaseHas('parcels', [
            'id' => $parcel->id,
            'targeted_driver_profile_id' => $driver->id,
        ]);

        $this->actAs($driver->user);
        $this->getJson('/api/v1/driver/me/parcels/offers')
            ->assertOk()
            ->assertJsonPath('data.0.id', $parcel->id);

        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/decline", [
            'reason' => 'Colis trop volumineux',
        ])->assertOk();

        $this->assertDatabaseHas('driver_assignment_requests', [
            'id' => $requestId,
            'status' => 'refused',
            'refusal_reason' => 'Colis trop volumineux',
        ]);
        $this->assertDatabaseHas('parcels', [
            'id' => $parcel->id,
            'targeted_driver_profile_id' => null,
        ]);

        $this->actAs($client);
        $this->postJson("/api/v1/parcels/{$parcel->id}/driver-request", [
            'driver_profile_id' => $driver->id,
        ])->assertCreated()->assertJsonPath('data.status', 'pending');

        $this->actAs($driver->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")
            ->assertOk()
            ->assertJsonPath('data.driver.id', $driver->id);

        $this->actAs($client);
        $this->getJson("/api/v1/parcels/{$parcel->id}")
            ->assertOk()
            ->assertJsonPath('data.driver_request.status', 'accepted')
            ->assertJsonPath('data.driver.id', $driver->id)
            ->assertJsonPath('data.driver.phone', $driver->user->phone);
    }
}
