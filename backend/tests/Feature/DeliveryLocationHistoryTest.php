<?php

namespace Tests\Feature;

use App\Models\Delivery;
use App\Models\DeliveryLocation;
use App\Models\Order;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DeliveryLocationHistoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_purges_locations_older_than_the_retention_window(): void
    {
        config()->set('beninfood.tracking.history_retention_days', 30);

        $client = User::factory()->create(['phone' => fake()->unique()->numerify('+22997######')]);
        $vendor = Vendor::factory()->create();
        $order = Order::create([
            'reference' => '#BF'.fake()->unique()->numerify('####'),
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => 'delivered',
            'payment_status' => 'confirmed',
            'currency' => 'XOF',
            'subtotal' => 5000,
            'delivery_fee' => 1000,
            'total' => 6000,
        ]);
        $delivery = Delivery::create([
            'order_id' => $order->id,
            'vendor_id' => $vendor->id,
            'status' => 'delivered',
            'fee' => 1000,
            'partner_amount' => 800,
        ]);

        $old = DeliveryLocation::create([
            'delivery_id' => $delivery->id,
            'latitude' => 6.3703,
            'longitude' => 2.3912,
            'recorded_at' => now()->subDays(31),
        ]);

        $recent = DeliveryLocation::create([
            'delivery_id' => $delivery->id,
            'latitude' => 6.3713,
            'longitude' => 2.3922,
            'recorded_at' => now()->subDay(),
        ]);

        $this->artisan('deliveries:purge-locations')->assertSuccessful();

        $this->assertDatabaseMissing('delivery_locations', ['id' => $old->id]);
        $this->assertDatabaseHas('delivery_locations', ['id' => $recent->id]);
    }
}
