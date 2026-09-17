<?php

namespace Database\Factories;

use App\Models\User;
use App\Models\UserDevice;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<UserDevice>
 */
class UserDeviceFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'fcm_token' => fake()->unique()->regexify('[A-Za-z0-9\-_:]{120,160}'),
            'platform' => 'android',
            'device_type' => fake()->randomElement(['phone', 'tablet']),
            'app_version' => '0.1.0',
            'is_active' => true,
            'last_seen_at' => now(),
        ];
    }
}
