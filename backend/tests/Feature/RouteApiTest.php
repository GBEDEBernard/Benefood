<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RouteApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function actingUser(): User
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22997######')]);
        $role = Role::where('slug', 'client')->firstOrFail();
        $user->roles()->attach($role, ['is_active' => true]);

        Sanctum::actingAs($user);

        return $user;
    }

    /**
     * @return array<string, mixed>
     */
    private function payload(): array
    {
        return ['points' => [
            ['latitude' => 6.3703, 'longitude' => 2.3912],
            ['latitude' => 6.3803, 'longitude' => 2.4012],
        ]];
    }

    public function test_it_returns_google_route_when_key_configured(): void
    {
        $this->actingUser();
        config()->set('beninfood.routing.google_key', 'test-key');

        Http::fake([
            'routes.googleapis.com/*' => Http::response([
                'routes' => [[
                    'distanceMeters' => 4200,
                    'duration' => '600s',
                    'polyline' => ['encodedPolyline' => '_p~iF~ps|U_ulLnnqC_mqNvxq`@'],
                    'legs' => [['distanceMeters' => 4200, 'duration' => '600s']],
                ]],
            ]),
        ]);

        $response = $this->postJson('/api/v1/routes', $this->payload());

        $response->assertOk()
            ->assertJsonPath('data.provider', 'google')
            ->assertJsonPath('data.distance_m', 4200)
            ->assertJsonPath('data.duration_s', 600);

        $this->assertNotEmpty($response->json('data.geometry'));
    }

    public function test_it_falls_back_to_osrm_without_google_key(): void
    {
        $this->actingUser();
        config()->set('beninfood.routing.google_key', null);

        Http::fake([
            'router.project-osrm.org/*' => Http::response([
                'routes' => [[
                    'distance' => 3000.5,
                    'duration' => 480.2,
                    'geometry' => ['coordinates' => [[2.3912, 6.3703], [2.4012, 6.3803]]],
                    'legs' => [['distance' => 3000.5, 'duration' => 480.2]],
                ]],
            ]),
        ]);

        $response = $this->postJson('/api/v1/routes', $this->payload());

        $response->assertOk()
            ->assertJsonPath('data.provider', 'osrm')
            ->assertJsonPath('data.distance_m', 3001)
            ->assertJsonPath('data.geometry.0.0', 6.3703)
            ->assertJsonPath('data.geometry.0.1', 2.3912);
    }

    public function test_it_falls_back_to_straight_line_when_providers_fail(): void
    {
        $this->actingUser();
        config()->set('beninfood.routing.google_key', 'test-key');

        Http::fake(['*' => Http::response('provider down', 500)]);

        $response = $this->postJson('/api/v1/routes', $this->payload());

        $response->assertOk()
            ->assertJsonPath('data.provider', 'straight');

        $this->assertGreaterThan(0, $response->json('data.distance_m'));
        $this->assertNotEmpty($response->json('data.geometry'));
    }

    public function test_it_validates_points(): void
    {
        $this->actingUser();

        $this->postJson('/api/v1/routes', ['points' => [['latitude' => 6.37, 'longitude' => 2.39]]])
            ->assertStatus(422);

        $this->postJson('/api/v1/routes', ['points' => [
            ['latitude' => 200, 'longitude' => 2.39],
            ['latitude' => 6.38, 'longitude' => 2.40],
        ]])->assertStatus(422);
    }

    public function test_it_requires_authentication(): void
    {
        $this->postJson('/api/v1/routes', $this->payload())->assertStatus(401);
    }
}
