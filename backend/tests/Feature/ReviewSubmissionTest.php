<?php

namespace Tests\Feature;

use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReviewSubmissionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function client(): User
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22997######')]);
        $user->roles()->attach(Role::where('slug', 'client')->firstOrFail(), ['is_active' => true]);

        Sanctum::actingAs($user);

        return $user;
    }

    private function deliveredOrder(User $client, Vendor $vendor): Order
    {
        return Order::create([
            'reference' => '#BF'.fake()->unique()->numerify('####'),
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => 'delivered',
            'payment_status' => 'confirmed',
            'currency' => 'XOF',
            'subtotal' => 5000,
            'delivery_fee' => 1000,
            'total' => 6300,
        ]);
    }

    public function test_client_can_review_vendor_and_driver_after_delivery(): void
    {
        $client = $this->client();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $order = $this->deliveredOrder($client, $vendor);

        $driverUser = User::factory()->create();
        $driver = DriverProfile::factory()->create(['user_id' => $driverUser->id, 'status' => 'active']);

        Delivery::create([
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'vendor_id' => $vendor->id,
            'status' => 'delivered',
            'fee' => 1000,
            'partner_amount' => 800,
        ]);

        $this->postJson("/api/v1/orders/{$order->id}/review", [
            'rating' => 5,
            'driver_rating' => 4,
            'comment' => 'Très bon, livraison rapide.',
        ])
            ->assertCreated()
            ->assertJsonPath('data.rating', 5)
            ->assertJsonPath('data.driver_rating', 4);

        $this->assertDatabaseHas('reviews', [
            'order_id' => $order->id,
            'user_id' => $client->id,
            'rating' => 5,
            'driver_rating' => 4,
        ]);

        $this->assertSame('4.00', (string) $driver->fresh()->rating);
    }

    public function test_client_cannot_review_un_delivered_order(): void
    {
        $client = $this->client();
        $vendor = Vendor::factory()->create(['status' => 'active']);

        $order = Order::create([
            'reference' => '#BF'.fake()->unique()->numerify('####'),
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => 'in_delivery',
            'payment_status' => 'confirmed',
            'currency' => 'XOF',
            'subtotal' => 1000,
            'total' => 1000,
        ]);

        $this->postJson("/api/v1/orders/{$order->id}/review", ['rating' => 5])->assertStatus(422);
    }

    public function test_client_cannot_review_twice(): void
    {
        $client = $this->client();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $order = $this->deliveredOrder($client, $vendor);

        $this->postJson("/api/v1/orders/{$order->id}/review", ['rating' => 5])->assertCreated();
        $this->postJson("/api/v1/orders/{$order->id}/review", ['rating' => 3])->assertStatus(422);
    }

    public function test_client_cannot_review_foreign_order(): void
    {
        $client = $this->client();
        $otherClient = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $order = $this->deliveredOrder($otherClient, $vendor);

        $this->postJson("/api/v1/orders/{$order->id}/review", ['rating' => 5])->assertNotFound();
    }
}
