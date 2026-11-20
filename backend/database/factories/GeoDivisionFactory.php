<?php

namespace Database\Factories;

use App\Models\GeoCountry;
use App\Models\GeoDivision;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<GeoDivision>
 */
class GeoDivisionFactory extends Factory
{
    protected $model = GeoDivision::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'country_id' => GeoCountry::factory(),
            'parent_id' => null,
            'level' => 'department',
            'source_key' => fake()->unique()->slug(2),
            'name' => ucfirst(fake()->unique()->word()),
            'name_normalized' => fake()->unique()->word(),
            'center_latitude' => fake()->latitude(6.2, 12.3),
            'center_longitude' => fake()->longitude(0.9, 3.7),
            'source' => 'IGN Bénin',
            'data_updated_at' => '2026-09-20',
            'is_active' => true,
        ];
    }
}
