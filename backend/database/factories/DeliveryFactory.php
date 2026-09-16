<?php

namespace Database\Factories;

use App\Enums\DeliveryStatus;
use App\Models\Delivery;
use App\Models\DeliveryZone;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Vendor;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Delivery>
 */
class DeliveryFactory extends Factory
{
    protected $model = Delivery::class;

    public function definition(): array
    {
        return [
            'order_id' => Order::factory(),
            'driver_profile_id' => null,
            'vendor_id' => Vendor::factory(),
            'zone_id' => DeliveryZone::factory(),
            'status' => DeliveryStatus::Assigned->value,
            'fee' => fake()->numberBetween(500, 3000),
            'partner_amount' => 0,
            'proof_code' => fake()->numerify('####'),
            'assigned_at' => now(),
        ];
    }

    public function assigned(): static
    {
        return $this->state(fn (): array => [
            'status' => DeliveryStatus::Assigned->value,
            'driver_profile_id' => null,
        ]);
    }

    public function withDriver(DriverProfile $driver): static
    {
        return $this->state(fn () => [
            'driver_profile_id' => $driver->id,
            'assigned_at' => now(),
        ]);
    }

    public function pickedUp(): static
    {
        return $this->state(fn (): array => [
            'status' => DeliveryStatus::PickedUp->value,
            'picked_up_at' => now(),
        ]);
    }

    public function inDelivery(): static
    {
        return $this->state(fn (): array => [
            'status' => DeliveryStatus::InDelivery->value,
            'picked_up_at' => now(),
        ]);
    }

    public function delivered(): static
    {
        return $this->state(fn (): array => [
            'status' => DeliveryStatus::Delivered->value,
            'picked_up_at' => now(),
            'delivered_at' => now(),
        ]);
    }
}
