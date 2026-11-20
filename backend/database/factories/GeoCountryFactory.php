<?php

namespace Database\Factories;

use App\Models\GeoCountry;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<GeoCountry>
 */
class GeoCountryFactory extends Factory
{
    protected $model = GeoCountry::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'code' => 'BJ',
            'name' => 'Bénin',
            'official_name' => 'République du Bénin',
            'levels' => [
                ['slug' => 'department', 'label' => 'Département', 'plural' => 'Départements'],
                ['slug' => 'commune', 'label' => 'Commune', 'plural' => 'Communes'],
                ['slug' => 'arrondissement', 'label' => 'Arrondissement', 'plural' => 'Arrondissements'],
            ],
            'locality_label' => 'Village ou quartier',
            'source' => 'IGN Bénin',
            'source_url' => 'https://ign.bj/donnees',
            'data_updated_at' => '2026-09-20',
            'is_active' => true,
        ];
    }
}
