<?php

namespace Tests\Feature;

use App\Models\GeoCountry;
use App\Models\GeoDivision;
use App\Models\GeoLocality;
use App\Support\Geo;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

class GeoReferenceApiTest extends TestCase
{
    use RefreshDatabase;

    private GeoCountry $country;

    private GeoDivision $littoral;

    private GeoDivision $cotonou;

    private GeoLocality $cadjehoun;

    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();

        $this->country = GeoCountry::factory()->create([
            'code' => 'BJ',
            'name' => 'Bénin',
            'levels' => [
                ['slug' => 'department', 'label' => 'Département', 'plural' => 'Départements'],
                ['slug' => 'commune', 'label' => 'Commune', 'plural' => 'Communes'],
                ['slug' => 'arrondissement', 'label' => 'Arrondissement', 'plural' => 'Arrondissements'],
            ],
        ]);

        $this->littoral = GeoDivision::factory()->create([
            'country_id' => $this->country->id,
            'level' => 'department',
            'source_key' => 'dep-7',
            'name' => 'Littoral',
            'name_normalized' => 'littoral',
        ]);

        $this->cotonou = GeoDivision::factory()->create([
            'country_id' => $this->country->id,
            'parent_id' => $this->littoral->id,
            'level' => 'commune',
            'source_key' => 'com-cotonou',
            'name' => 'Cotonou',
            'name_normalized' => 'cotonou',
        ]);

        $arrondissement = GeoDivision::factory()->create([
            'country_id' => $this->country->id,
            'parent_id' => $this->cotonou->id,
            'level' => 'arrondissement',
            'source_key' => 'arr-cotonou-12',
            'name' => '12ème Arrondissement',
            'name_normalized' => Geo::normalizeName('12ème Arrondissement'),
            'center_latitude' => 6.36,
            'center_longitude' => 2.4,
            'bbox_min_latitude' => 6.3,
            'bbox_max_latitude' => 6.5,
            'bbox_min_longitude' => 2.2,
            'bbox_max_longitude' => 2.6,
            'geometry_json' => json_encode([
                'type' => 'Polygon',
                'coordinates' => [[
                    [2.2, 6.3], [2.6, 6.3], [2.6, 6.5], [2.2, 6.5], [2.2, 6.3],
                ]],
            ], JSON_THROW_ON_ERROR),
        ]);

        $this->cadjehoun = GeoLocality::factory()->create([
            'country_id' => $this->country->id,
            'division_id' => $arrondissement->id,
            'source_key' => 'X434101Y703242',
            'code' => 'X434101Y703242',
            'name' => 'Cadjèhoun-Gare',
            'name_normalized' => Geo::normalizeName('Cadjèhoun-Gare'),
            'kind' => 'quartier',
            'latitude' => 6.3618533919243,
            'longitude' => 2.4041499942185,
        ]);
    }

    public function test_countries_expose_configurable_hierarchy_and_source(): void
    {
        $response = $this->getJson('/api/v1/geo/countries');

        $response->assertOk()
            ->assertJsonPath('data.0.code', 'BJ')
            ->assertJsonPath('data.0.source', 'IGN Bénin')
            ->assertJsonPath('data.0.hierarchy.1.slug', 'commune');
    }

    public function test_divisions_can_be_filtered_for_cascading_selects(): void
    {
        $response = $this->getJson('/api/v1/geo/divisions?country=BJ&level=commune&parent_id='.$this->littoral->id);

        $response->assertOk()
            ->assertJsonPath('data.0.name', 'Cotonou')
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.path.1', 'Littoral');
    }

    public function test_search_returns_official_localities_with_geographic_code(): void
    {
        $response = $this->getJson('/api/v1/geo/search?q=Cadjehoun&country=BJ');

        $response->assertOk();
        $this->assertTrue(collect($response->json('data'))
            ->contains(fn (array $item): bool => $item['kind'] === 'locality'
                && $item['name'] === 'Cadjèhoun-Gare'
                && $item['code'] === 'X434101Y703242'
                && $item['source'] === 'IGN Bénin'));
    }

    public function test_reverse_geocoding_uses_official_referential(): void
    {
        $response = $this->postJson('/api/v1/geo/reverse', [
            'latitude' => 6.36185,
            'longitude' => 2.40415,
            'country' => 'BJ',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.provider', 'local')
            ->assertJsonPath('data.locality', $this->cadjehoun->id)
            ->assertJsonPath('data.division', $this->cotonou->children()->first()?->id)
            ->assertJsonPath('data.components.commune', 'Cotonou')
            ->assertJsonPath('data.source', 'IGN Bénin');
    }
}
