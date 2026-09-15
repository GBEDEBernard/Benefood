<?php

namespace Database\Factories;

use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<DeliveryRate>
 */
class DeliveryRateFactory extends Factory
{
    protected $model = DeliveryRate::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'zone_id' => DeliveryZone::factory(),
            'vendor_id' => null,
            'price' => fake()->numberBetween(500, 3000),
            'is_active' => true,
        ];
    }

    public function vendorSpecific(string $vendorId): static
    {
        return $this->state(fn () => [
            'vendor_id' => $vendorId,
        ]);
    }

    public function expired(): static
    {
        return $this->state(fn () => [
            'effective_from' => now()->subDays(30),
            'effective_to' => now()->subDay(),
        ]);
    }

    public function future(): static
    {
        return $this->state(fn () => [
            'effective_from' => now()->addDays(7),
        ]);
    }

    public function inactive(): static
    {
        return $this->state(fn () => [
            'is_active' => false,
        ]);
    }
}
