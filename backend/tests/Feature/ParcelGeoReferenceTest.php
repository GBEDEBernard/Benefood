<?php

namespace Tests\Feature;

use App\Models\GeoCountry;
use App\Models\GeoDivision;
use App\Models\GeoLocality;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ParcelGeoReferenceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function client(): User
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22997######')]);
        $user->roles()->attach(Role::where('slug', 'client')->firstOrFail(), ['is_active' => true]);
        Sanctum::actingAs($user);

        return $user;
    }

    /** @return array{country: GeoCountry, division: GeoDivision, locality: GeoLocality} */
    private function references(?GeoCountry $country = null, float $latitude = 6.36, float $longitude = 2.40): array
    {
        $country ??= GeoCountry::factory()->create(['code' => 'BJ', 'name' => 'Bénin']);
        $division = GeoDivision::factory()->create([
            'country_id' => $country->id,
            'level' => 'department',
            'name' => 'Littoral',
        ]);
        $locality = GeoLocality::factory()->create([
            'country_id' => $country->id,
            'division_id' => $division->id,
            'name' => 'Cadjèhoun-Gare',
            'kind' => 'quartier',
            'latitude' => $latitude,
            'longitude' => $longitude,
        ]);

        return compact('country', 'division', 'locality');
    }

    public function test_geo_references_are_normalized_in_parcel_snapshots(): void
    {
        $this->client();
        $pickup = $this->references();

        $response = $this->postJson('/api/v1/parcels', [
            'pickup' => [
                'label' => 'Carrefour Jericho',
                'address_text' => 'Rue des Fleurs',
                'city' => 'Cotonou',
                'latitude' => 6.37,
                'longitude' => 2.42,
                'country_code' => 'BJ',
                'division_id' => $pickup['division']->id,
                'locality_id' => $pickup['locality']->id,
                'gps_accuracy_m' => 12.5,
                'location_source' => 'gps',
                'location_recorded_at' => now()->toIso8601String(),
            ],
            'dropoff' => [
                'label' => 'Ganhi',
                'address_text' => 'Derrière le marché',
                'city' => 'Cotonou',
                'latitude' => 6.35,
                'longitude' => 2.44,
            ],
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.pickup.city', 'Cotonou')
            ->assertJsonPath('data.pickup.address_text', 'Rue des Fleurs')
            ->assertJsonPath('data.pickup.country_id', $pickup['country']->id)
            ->assertJsonPath('data.pickup.division_id', $pickup['division']->id)
            ->assertJsonPath('data.pickup.locality_id', $pickup['locality']->id)
            ->assertJsonPath('data.pickup.gps_accuracy_m', 12.5)
            ->assertJsonPath('data.pickup.location_source', 'gps');
    }

    public function test_locality_must_belong_to_selected_division(): void
    {
        $this->client();
        $first = $this->references();
        $second = $this->references(country: $first['country'], latitude: 6.34, longitude: 2.46);

        $this->postJson('/api/v1/parcels', [
            'pickup' => [
                'address_text' => 'Rue des Fleurs',
                'latitude' => 6.37,
                'longitude' => 2.42,
                'country_code' => 'BJ',
                'division_id' => $first['division']->id,
                'locality_id' => $second['locality']->id,
            ],
            'dropoff' => [
                'address_text' => 'Derrière le marché',
                'latitude' => 6.35,
                'longitude' => 2.44,
            ],
        ])->assertUnprocessable()
            ->assertJsonPath('errors.0.code', 'validation_error.locality_id');
    }
}
