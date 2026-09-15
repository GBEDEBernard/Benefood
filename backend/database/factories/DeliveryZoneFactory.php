<?php

namespace Database\Factories;

use App\Models\DeliveryZone;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<DeliveryZone>
 */
class DeliveryZoneFactory extends Factory
{
    protected $model = DeliveryZone::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->unique()->city().' Centre',
            'city' => 'Cotonou',
            'identification_mode' => 'zone',
            'is_active' => true,
            'sort_order' => fake()->numberBetween(1, 50),
        ];
    }

    /** Zone identifiée par quartier(s). */
    public function quarter(array $terms = ['Akpakpa', 'Cadjèhoun']): static
    {
        return $this->state(fn () => [
            'identification_mode' => 'quarter',
            'terms' => $terms,
        ]);
    }

    /** Zone identifiée par distance autour d'un centre (rayon en km). */
    public function distance(float $radiusKm = 5.0): static
    {
        return $this->state(fn () => [
            'identification_mode' => 'distance',
            'center_latitude' => 6.3702932,
            'center_longitude' => 2.3912362,
            'radius_km' => $radiusKm,
        ]);
    }

    public function inactive(): static
    {
        return $this->state(fn () => [
            'is_active' => false,
        ]);
    }
}
