<?php

namespace Database\Factories;

use App\Models\Address;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Address>
 */
class AddressFactory extends Factory
{
    protected $model = Address::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'label' => fake()->randomElement(['Maison', 'Bureau', 'Autre']),
            'zone_id' => null,
            'is_default' => false,
            'full_address' => fake()->streetAddress(),
            'landmark' => fake()->randomElement(['Près du marché Dantokpa', 'En face de la station', null]),
            'latitude' => fake()->latitude(),
            'longitude' => fake()->longitude(),
            'city' => 'Cotonou',
        ];
    }

    public function default(): static
    {
        return $this->state(fn (): array => ['is_default' => true]);
    }
}
