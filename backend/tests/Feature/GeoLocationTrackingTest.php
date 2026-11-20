<?php

namespace Tests\Feature;

use App\Enums\ParcelStatus;
use App\Events\DriverLocationUpdated;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Queue;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class GeoLocationTrackingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Cache::flush();
        $this->seed(RolesAndPermissionsSeeder::class);
        config()->set('beninfood.routing.google_key', null);
        config()->set('beninfood.routing.ors_key', null);
        config()->set('beninfood.routing.allow_public_osrm', false);
        config()->set('beninfood.tracking.broadcast_enabled', false);
    }

    public function test_driver_location_is_recorded_on_the_active_mission_only(): void
    {
        [$client, $driverUser, $driver, $delivery] = $this->activeMission();
        Sanctum::actingAs($driverUser);
        Queue::fake();

        $response = $this->patchJson('/api/v1/driver/me/availability/location', [
            'latitude' => 6.362,
            'longitude' => 2.404,
            'accuracy_m' => 12.5,
            'speed_mps' => 3.2,
            'heading' => 45,
            'location_source' => 'gps',
            'delivery_id' => $delivery->id,
        ]);

        $response->assertOk()
            ->assertJsonPath('data.accepted', true)
            ->assertJsonPath('data.missions.0.id', $delivery->id)
            ->assertJsonPath('data.position.accuracy_m', 12.5)
            ->assertJsonPath('data.position.location_source', 'gps');

        $this->assertDatabaseHas('deliveries', [
            'id' => $delivery->id,
            'last_accuracy_m' => 12.5,
            'last_speed_mps' => 3.2,
            'last_heading' => 45,
            'last_location_source' => 'gps',
        ]);
        $this->assertDatabaseHas('delivery_locations', [
            'delivery_id' => $delivery->id,
            'driver_profile_id' => $driver->id,
            'accuracy_m' => 12.5,
            'speed_mps' => 3.2,
            'location_source' => 'gps',
        ]);

        // L'événement est émis, mais rien n'est diffusé tant que Reverb n'est pas activé.
        Queue::assertNothingPushed();
        $this->assertFalse((bool) config('beninfood.tracking.broadcast_enabled'));
    }

    public function test_rapid_updates_are_throttled_and_accuracy_is_enforced(): void
    {
        [, $driverUser, , $delivery] = $this->activeMission();
        Sanctum::actingAs($driverUser);

        $payload = [
            'latitude' => 6.362,
            'longitude' => 2.404,
            'accuracy_m' => 15,
            'delivery_id' => $delivery->id,
        ];

        $this->patchJson('/api/v1/driver/me/availability/location', $payload)
            ->assertOk()
            ->assertJsonPath('data.accepted', true);

        $this->patchJson('/api/v1/driver/me/availability/location', $payload)
            ->assertOk()
            ->assertJsonPath('data.accepted', false)
            ->assertJsonPath('data.reason', 'throttled');

        $this->assertSame(1, $delivery->locations()->count());

        $this->patchJson('/api/v1/driver/me/availability/location', [
            'latitude' => 6.362,
            'longitude' => 2.404,
            'accuracy_m' => 500,
            'delivery_id' => $delivery->id,
        ])->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'tracking.inaccurate_position');

        $this->assertSame(1, $delivery->locations()->count());
    }

    public function test_completed_mission_stops_tracking(): void
    {
        [, $driverUser, $driver, $delivery] = $this->activeMission();
        $delivery->update(['status' => 'delivered']);
        Sanctum::actingAs($driverUser);

        $this->patchJson('/api/v1/driver/me/availability/location', [
            'latitude' => 6.363,
            'longitude' => 2.405,
            'delivery_id' => $delivery->id,
        ])->assertStatus(409)
            ->assertJsonPath('errors.0.code', 'tracking.mission_not_active');

        $this->assertSame(0, $delivery->locations()->count());
        $this->assertEqualsWithDelta(6.361, (float) $delivery->fresh()->last_latitude, 0.0001);

        $this->patchJson('/api/v1/driver/me/availability/location', [
            'latitude' => 6.363,
            'longitude' => 2.405,
        ])->assertOk()->assertJsonPath('data.accepted', true);

        $this->assertSame(0, $delivery->locations()->count());
        $this->assertNotNull($driver->fresh()->last_latitude);
    }

    public function test_owner_reads_three_positions_distances_and_eta_but_other_client_cannot(): void
    {
        [$client, $driverUser, , $delivery] = $this->activeMission();
        Sanctum::actingAs($client);

        $response = $this->getJson('/api/v1/orders/'.$delivery->order_id.'/tracking');

        $response->assertOk()
            ->assertJsonPath('data.active', true)
            ->assertJsonPath('data.points.client.latitude', 6.3703)
            ->assertJsonPath('data.points.shop.latitude', 6.36)
            ->assertJsonPath('data.points.driver.latitude', 6.361)
            ->assertJsonPath('data.distances.road_provider', 'straight')
            ->assertJsonPath('data.eta.source', 'road')
            ->assertJsonPath('data.eta.available', true);

        $straight = $response->json('data.distances.straight_km');
        $this->assertNotNull($straight['driver_client_km']);
        $this->assertNotNull($straight['driver_shop_km']);
        $this->assertNotNull($straight['shop_client_km']);
        $this->assertGreaterThan(0, $response->json('data.distances.road_m'));
        $this->assertGreaterThan(0, $response->json('data.eta.seconds'));

        $other = User::factory()->create(['phone' => '+22997111111']);
        Sanctum::actingAs($other);

        $this->getJson('/api/v1/orders/'.$delivery->order_id.'/tracking')
            ->assertStatus(404)
            ->assertJsonPath('errors.0.code', 'not_found');

        // Le livreur assigné peut également suivre sa propre mission.
        Sanctum::actingAs($driverUser);
        $this->getJson('/api/v1/orders/'.$delivery->order_id.'/tracking')->assertOk();
    }

    public function test_parcel_tracking_uses_pickup_and_dropoff_points(): void
    {
        $client = User::factory()->create(['phone' => '+22997222222']);
        $driverUser = User::factory()->create(['phone' => '+22997333333']);
        $driverUser->roles()->attach(Role::where('slug', 'driver-independent')->first(), ['is_active' => true]);
        $driver = DriverProfile::factory()->create([
            'user_id' => $driverUser->id,
            'status' => 'active',
            'last_latitude' => 6.362,
            'last_longitude' => 2.404,
        ]);
        $parcel = Parcel::create([
            'reference' => '#COL'.fake()->unique()->numerify('####'),
            'user_id' => $client->id,
            'driver_profile_id' => $driver->id,
            'status' => ParcelStatus::Assigned->value,
            'pickup_snapshot' => [
                'address_text' => 'Cadjèhoun-Gare, Cotonou',
                'latitude' => 6.36185,
                'longitude' => 2.40415,
            ],
            'dropoff_snapshot' => [
                'address_text' => 'Akpakpa, Cotonou',
                'latitude' => 6.37,
                'longitude' => 2.42,
            ],
        ]);

        Sanctum::actingAs($client);
        $this->getJson('/api/v1/parcels/'.$parcel->id.'/tracking')
            ->assertOk()
            ->assertJsonPath('data.active', true)
            ->assertJsonPath('data.points.client.latitude', 6.37)
            ->assertJsonPath('data.points.shop.latitude', 6.36185)
            ->assertJsonPath('data.points.driver.latitude', 6.362);

        Sanctum::actingAs($driverUser);
        $this->patchJson('/api/v1/driver/me/availability/location', [
            'latitude' => 6.365,
            'longitude' => 2.408,
            'accuracy_m' => 18,
            'parcel_id' => $parcel->id,
        ])->assertOk()
            ->assertJsonPath('data.accepted', true)
            ->assertJsonPath('data.missions.0.type', 'parcel');

        $this->assertNotNull($driver->fresh()->last_latitude);
    }

    public function test_broadcast_event_targets_a_private_delivery_channel(): void
    {
        [, , , $delivery] = $this->activeMission();

        $event = new DriverLocationUpdated(
            (string) $delivery->id,
            (string) $delivery->driver_profile_id,
            (string) $delivery->order_id,
            ['latitude' => 6.362, 'longitude' => 2.404],
        );

        $this->assertSame('driver.location.updated', $event->broadcastAs());
        $this->assertSame('private-delivery.'.$delivery->id, $event->broadcastOn()[0]->name);
        $this->assertFalse($event->broadcastWhen());
    }

    /**
     * @return array{0: User, 1: User, 2: DriverProfile, 3: Delivery}
     */
    private function activeMission(): array
    {
        $client = User::factory()->create(['phone' => '+22997000091']);
        $driverUser = User::factory()->create(['phone' => '+22997000092']);
        $driverUser->roles()->attach(Role::where('slug', 'driver-independent')->first(), ['is_active' => true]);
        $driver = DriverProfile::factory()->create([
            'user_id' => $driverUser->id,
            'status' => 'active',
            'last_latitude' => 6.36,
            'last_longitude' => 2.4,
        ]);
        $vendor = Vendor::factory()->create();
        $order = Order::create([
            'reference' => '#BF'.fake()->unique()->numerify('####'),
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => 'in_delivery',
            'payment_status' => 'confirmed',
            'currency' => 'XOF',
            'subtotal' => 5000,
            'delivery_fee' => 1000,
            'total' => 6000,
            'address_snapshot' => [
                'latitude' => 6.3703,
                'longitude' => 2.3912,
                'full_address' => 'Akpakpa, Cotonou',
            ],
        ]);
        $delivery = Delivery::create([
            'order_id' => $order->id,
            'vendor_id' => $vendor->id,
            'driver_profile_id' => $driver->id,
            'status' => 'in_delivery',
            'fee' => 1000,
            'partner_amount' => 800,
            'assigned_at' => now(),
            'pickup_latitude' => 6.36,
            'pickup_longitude' => 2.4,
            'dropoff_latitude' => 6.3703,
            'dropoff_longitude' => 2.3912,
            'last_latitude' => 6.361,
            'last_longitude' => 2.402,
            'last_location_at' => now(),
        ]);

        return [$client, $driverUser, $driver, $delivery];
    }
}
