<?php

namespace Database\Factories;

use App\Models\Neighborhood;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Neighborhood>
 */
class NeighborhoodFactory extends Factory
{
    protected $model = Neighborhood::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'city' => 'Cotonou',
            'name' => ucfirst(fake()->unique()->word()),
            'latitude' => fake()->latitude(6.3, 6.5),
            'longitude' => fake()->longitude(2.3, 2.5),
            'is_active' => true,
        ];
    }
}
