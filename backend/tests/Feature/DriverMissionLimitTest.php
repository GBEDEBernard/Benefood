<?php

namespace Tests\Feature;

use App\Exceptions\DomainException;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\User;
use App\Models\Vendor;
use App\Services\DeliveryService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DriverMissionLimitTest extends TestCase
{
    use RefreshDatabase;

    private function order(User $client, Vendor $vendor, string $status): Order
    {
        return Order::create([
            'reference' => '#BF'.fake()->unique()->numerify('#####'),
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => $status,
            'payment_status' => 'confirmed',
            'currency' => 'XOF',
            'subtotal' => 5000,
            'delivery_fee' => 1000,
            'total' => 6000,
        ]);
    }

    public function test_a_driver_cannot_exceed_two_active_missions(): void
    {
        config()->set('beninfood.tracking.max_active_missions', 2);

        $client = User::factory()->create(['phone' => fake()->unique()->numerify('+22997######')]);
        $vendor = Vendor::factory()->create();
        $driver = DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
        ]);

        foreach (range(1, 2) as $index) {
            Delivery::create([
                'order_id' => $this->order($client, $vendor, 'assigned')->id,
                'driver_profile_id' => $driver->id,
                'vendor_id' => $vendor->id,
                'status' => 'in_delivery',
                'fee' => 1000,
                'partner_amount' => 800,
            ]);
        }

        $delivery = Delivery::create([
            'order_id' => $this->order($client, $vendor, 'ready')->id,
            'driver_profile_id' => null,
            'vendor_id' => $vendor->id,
            'status' => 'assigned',
            'fee' => 1000,
            'partner_amount' => 800,
        ]);

        try {
            app(DeliveryService::class)->acceptOffer($delivery, $driver);
            $this->fail('Le livreur ne devait pas pouvoir accepter une troisième mission.');
        } catch (DomainException $exception) {
            $this->assertSame('delivery.max_active_missions', $exception->errorCode);
            $this->assertSame(409, $exception->status);
        }

        $this->assertNull($delivery->fresh()->driver_profile_id);
    }
}
