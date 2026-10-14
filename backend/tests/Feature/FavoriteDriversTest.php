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
use App\Services\ParcelService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FavoriteDriversTest extends TestCase
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
        $user->roles()->attach(Role::where('slug', $roleSlug)->firstOrFail(), ['is_active' => true]);

        Sanctum::actingAs($user);

        return $user;
    }

    private function actAs(User $user): void
    {
        Sanctum::actingAs($user);
    }

    private function driver(): DriverProfile
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22996######')]);
        $user->roles()->attach(Role::where('slug', 'driver-independent')->firstOrFail(), ['is_active' => true]);

        return DriverProfile::factory()->create(['user_id' => $user->id, 'status' => 'active', 'available' => true]);
    }

    private function pickup(): array
    {
        return ['label' => 'Carrefour Jericho', 'city' => 'Cotonou', 'landmark' => 'Face à la pharmacie', 'latitude' => 6.37, 'longitude' => 2.42];
    }

    private function dropoff(): array
    {
        return ['label' => 'Ganhi', 'city' => 'Cotonou', 'landmark' => 'Derrière le marché', 'latitude' => 6.35, 'longitude' => 2.44];
    }

    /** Le client/vendeur demande le livreur, puis celui-ci accepte. */
    private function acceptFavorite(User $owner, DriverProfile $driver): void
    {
        $this->actAs($owner);
        $this->postJson('/api/v1/me/favorite-drivers', ['driver_profile_id' => $driver->id])->assertCreated();

        $this->actAs($driver->user);
        $favoriteId = $this->getJson('/api/v1/driver/me/favorite-clients')->json('data.0.id');
        $this->postJson("/api/v1/driver/me/favorite-clients/{$favoriteId}/accept")->assertOk();
    }

    /** Vendeur actif + produit commandable + zone de livraison. @return array{0: User, 1: Vendor, 2: Product} */
    private function vendorWithProduct(): array
    {
        $vendorUser = $this->actingUser('vendor');
        $vendor = Vendor::factory()->create(['status' => 'active', 'user_id' => $vendorUser->id]);
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

        return [$vendorUser, $vendor, $product];
    }

    public function test_favorite_request_lifecycle_and_candidates_based_on_history(): void
    {
        $client = $this->actingUser('client');
        $driver = $this->driver();

        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);
        $parcels->assignDriver($parcel->fresh(), $driver, $driver->user_id);

        $this->actAs($client);
        $candidates = $this->getJson('/api/v1/me/favorite-drivers/candidates')->assertOk()->json('data');
        $this->assertCount(1, $candidates);
        $this->assertSame($driver->id, $candidates[0]['id']);

        $this->postJson('/api/v1/me/favorite-drivers', ['driver_profile_id' => $driver->id])
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending');

        $this->actAs($driver->user);
        $requests = $this->getJson('/api/v1/driver/me/favorite-clients')->assertOk()->json('data');
        $this->assertCount(1, $requests);

        $this->postJson("/api/v1/driver/me/favorite-clients/{$requests[0]['id']}/accept")
            ->assertOk()
            ->assertJsonPath('data.status', 'accepted');

        $this->actAs($client);
        $this->getJson('/api/v1/me/favorite-drivers')
            ->assertOk()
            ->assertJsonPath('data.0.status', 'accepted')
            ->assertJsonPath('data.0.driver.id', $driver->id);
    }

    public function test_candidates_exclude_drivers_without_history(): void
    {
        $this->actingUser('client');
        $this->driver();

        $candidates = $this->getJson('/api/v1/me/favorite-drivers/candidates')->assertOk()->json('data');

        $this->assertSame([], $candidates);
    }

    public function test_order_with_favorite_driver_targets_offer_only_to_that_driver(): void
    {
        $client = $this->actingUser('client');
        $driver = $this->driver();
        $this->acceptFavorite($client, $driver);

        [$vendorUser, $vendor, $product] = $this->vendorWithProduct();
        $address = Address::factory()->create(['user_id' => $client->id, 'city' => 'Cotonou']);

        $this->actAs($client);
        $this->postJson('/api/v1/cart/items', ['product_id' => $product->id, 'quantity' => 2])->assertOk();

        $reference = $this->postJson('/api/v1/orders', [
            'address_id' => $address->id,
            'favorite_driver_id' => $driver->id,
        ])->assertCreated()->json('data.reference');

        $order = Order::where('reference', $reference)->firstOrFail();
        $this->assertSame($driver->id, $order->preferred_driver_profile_id);

        $this->actAs($vendorUser);
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/accept")->assertOk();
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/preparing")->assertOk();
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/ready")->assertOk();

        $this->assertDatabaseHas('deliveries', [
            'order_id' => $order->id,
            'targeted_driver_profile_id' => $driver->id,
        ]);

        $deliveryId = $order->delivery()->value('id');

        $this->actAs($driver->user);
        $offers = $this->getJson('/api/v1/driver/me/deliveries/offers')->assertOk()->json('data');
        $this->assertTrue(collect($offers)->contains(fn ($offer) => $offer['order']['id'] === $order->id));

        $other = $this->driver();
        $this->actAs($other->user);
        $otherOffers = $this->getJson('/api/v1/driver/me/deliveries/offers')->assertOk()->json('data');
        $this->assertFalse(collect($otherOffers)->contains(fn ($offer) => $offer['order']['id'] === $order->id));

        $this->postJson("/api/v1/driver/me/deliveries/{$deliveryId}/accept")->assertStatus(409);

        $this->actAs($driver->user);
        $this->postJson("/api/v1/driver/me/deliveries/{$deliveryId}/accept")->assertOk();

        $this->assertSame($driver->id, $order->fresh()->delivery->driver_profile_id);
    }

    public function test_order_rejects_non_accepted_favorite_driver(): void
    {
        $client = $this->actingUser('client');
        $driver = $this->driver();

        $this->actAs($client);
        $this->postJson('/api/v1/me/favorite-drivers', ['driver_profile_id' => $driver->id])->assertCreated();

        [, $vendor, $product] = $this->vendorWithProduct();
        $address = Address::factory()->create(['user_id' => $client->id, 'city' => 'Cotonou']);

        $this->actAs($client);
        $this->postJson('/api/v1/cart/items', ['product_id' => $product->id, 'quantity' => 1])->assertOk();

        $this->postJson('/api/v1/orders', [
            'address_id' => $address->id,
            'favorite_driver_id' => $driver->id,
        ])
            ->assertStatus(409)
            ->assertJsonPath('errors.0.code', 'favorite.not_accepted');
    }

    public function test_parcel_with_favorite_driver_targets_offer_only_to_that_driver(): void
    {
        $client = $this->actingUser('client');
        $driver = $this->driver();
        $this->acceptFavorite($client, $driver);

        $this->actAs($client);
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff(), 'Colis réservé', $driver->id);
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);

        $this->assertSame($driver->id, $parcel->fresh()->targeted_driver_profile_id);

        $this->actAs($driver->user);
        $offers = $this->getJson('/api/v1/driver/me/parcels/offers')->assertOk()->json('data');
        $this->assertTrue(collect($offers)->contains(fn ($offer) => $offer['id'] === $parcel->id));

        $other = $this->driver();
        $this->actAs($other->user);
        $otherOffers = $this->getJson('/api/v1/driver/me/parcels/offers')->assertOk()->json('data');
        $this->assertFalse(collect($otherOffers)->contains(fn ($offer) => $offer['id'] === $parcel->id));

        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")->assertStatus(409);

        $this->actAs($driver->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")->assertOk();

        $this->assertSame($driver->id, $parcel->fresh()->driver_profile_id);
        $this->assertNull($parcel->fresh()->targeted_driver_profile_id);
    }
}
