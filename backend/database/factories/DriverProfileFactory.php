<?php

namespace Database\Factories;

use App\Enums\DriverStatus;
use App\Enums\DriverType;
use App\Models\DriverProfile;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<DriverProfile>
 */
class DriverProfileFactory extends Factory
{
    protected $model = DriverProfile::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'type' => DriverType::Independent->value,
            'status' => DriverStatus::Active->value,
            'vehicle' => fake()->randomElement(['Moto', 'Tricycle', 'Vélo', null]),
            'available' => false,
            'last_latitude' => fake()->latitude(6.35, 6.40),
            'last_longitude' => fake()->longitude(2.35, 2.45),
            'rating' => fake()->randomFloat(2, 3.0, 5.0),
        ];
    }

    public function active(): static
    {
        return $this->state(fn (): array => [
            'status' => DriverStatus::Active->value,
            'available' => true,
        ]);
    }

    public function available(): static
    {
        return $this->state(fn (): array => ['available' => true]);
    }

    public function offline(): static
    {
        return $this->state(fn (): array => ['available' => false]);
    }

    public function validated(): static
    {
        return $this->state(fn (): array => [
            'status' => DriverStatus::Validated->value,
        ]);
    }

    public function beninfood(): static
    {
        return $this->state(fn (): array => [
            'type' => DriverType::Beninfood->value,
        ]);
    }
}
