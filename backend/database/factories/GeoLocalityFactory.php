<?php

namespace Database\Factories;

use App\Models\GeoCountry;
use App\Models\GeoDivision;
use App\Models\GeoLocality;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<GeoLocality>
 */
class GeoLocalityFactory extends Factory
{
    protected $model = GeoLocality::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'country_id' => GeoCountry::factory(),
            'division_id' => GeoDivision::factory(),
            'source_key' => fake()->unique()->uuid(),
            'code' => null,
            'name' => ucfirst(fake()->unique()->word()),
            'name_normalized' => fake()->unique()->word(),
            'kind' => 'quartier',
            'latitude' => fake()->latitude(6.3, 6.5),
            'longitude' => fake()->longitude(2.3, 2.5),
            'source' => 'IGN Bénin',
            'data_updated_at' => '2026-09-20',
            'is_verified' => true,
            'is_active' => true,
        ];
    }
}
