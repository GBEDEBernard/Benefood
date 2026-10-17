<?php

namespace Tests\Feature;

use App\Models\DeliveryZone;
use App\Models\Neighborhood;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminLocationsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function admin(): User
    {
        $admin = User::factory()->create(['email' => 'admin@local']);
        $admin->roles()->attach(Role::where('slug', 'admin-technique')->first()->id, ['is_active' => true]);

        return $admin;
    }

    private function client(): User
    {
        $client = User::factory()->create(['phone' => '+22997000012']);
        $client->roles()->attach(Role::where('slug', 'client')->first()->id, ['is_active' => true]);

        return $client;
    }

    public function test_guest_is_redirected_to_login(): void
    {
        $this->get(route('admin.locations.index'))->assertRedirect(route('login'));
    }

    public function test_client_cannot_manage_locations(): void
    {
        $this->actingAs($this->client());

        $this->get(route('admin.locations.index'))->assertForbidden();
        $this->get(route('admin.locations.create'))->assertForbidden();
    }

    public function test_admin_can_create_neighborhood_and_implicitly_a_city(): void
    {
        $zone = DeliveryZone::factory()->create(['city' => 'Cotonou', 'name' => 'Cotonou Centre']);

        $this->actingAs($this->admin())
            ->from(route('admin.locations.create'))
            ->post(route('admin.locations.store'), [
                'name' => 'Fidjrossè',
                'city' => 'Cotonou',
                'latitude' => 6.3551,
                'longitude' => 2.3502,
                'delivery_zone_id' => $zone->id,
                'sort_order' => 3,
                'is_active' => 1,
            ])
            ->assertRedirect(route('admin.locations.index'))
            ->assertSessionHas('success');

        $this->assertDatabaseHas('neighborhoods', [
            'name' => 'Fidjrossè',
            'city' => 'Cotonou',
            'delivery_zone_id' => $zone->id,
            'is_active' => true,
        ]);
    }

    public function test_index_lists_neighborhoods_grouped_by_city(): void
    {
        Neighborhood::factory()->create(['name' => 'Fidjrossè', 'city' => 'Cotonou']);

        $this->actingAs($this->admin())
            ->get(route('admin.locations.index'))
            ->assertOk()
            ->assertSee('Fidjrossè')
            ->assertSee('Cotonou');
    }

    public function test_admin_can_update_neighborhood(): void
    {
        $neighborhood = Neighborhood::factory()->create(['name' => 'Akpakpa', 'city' => 'Cotonou']);

        $this->actingAs($this->admin())
            ->from(route('admin.locations.edit', $neighborhood))
            ->put(route('admin.locations.update', $neighborhood), [
                'name' => 'Akpakpa Nord',
                'city' => 'Cotonou',
                'latitude' => 6.35,
                'longitude' => 2.45,
                'sort_order' => 5,
                'is_active' => 1,
            ])
            ->assertRedirect(route('admin.locations.index'))
            ->assertSessionHas('success');

        $neighborhood->refresh();
        $this->assertSame('Akpakpa Nord', $neighborhood->name);
        $this->assertSame(5, $neighborhood->sort_order);
    }

    public function test_admin_can_toggle_neighborhood_active(): void
    {
        $neighborhood = Neighborhood::factory()->create(['is_active' => true]);

        $this->actingAs($this->admin())
            ->post(route('admin.locations.active', $neighborhood))
            ->assertRedirect();

        $this->assertFalse($neighborhood->fresh()->is_active);
    }

    public function test_admin_can_destroy_neighborhood_logically(): void
    {
        $neighborhood = Neighborhood::factory()->create(['is_active' => true]);

        $this->actingAs($this->admin())
            ->delete(route('admin.locations.destroy', $neighborhood))
            ->assertRedirect(route('admin.locations.index'));

        $this->assertFalse($neighborhood->fresh()->is_active);
        $this->assertDatabaseHas('neighborhoods', ['id' => $neighborhood->id]);
    }

    public function test_store_rejects_duplicate_quarter_in_same_city(): void
    {
        Neighborhood::factory()->create(['name' => 'Gbégamey', 'city' => 'Cotonou']);

        $this->actingAs($this->admin())
            ->post(route('admin.locations.store'), [
                'name' => 'Gbégamey',
                'city' => 'Cotonou',
            ])
            ->assertSessionHasErrors('name');

        $this->assertDatabaseCount('neighborhoods', 1);
    }

    public function test_store_rejects_invalid_coordinates_and_unknown_zone(): void
    {
        $this->actingAs($this->admin())
            ->post(route('admin.locations.store'), [
                'name' => 'Zone Impossible',
                'city' => 'Cotonou',
                'latitude' => 120,
                'longitude' => 200,
                'delivery_zone_id' => 'not-a-zone',
            ])
            ->assertSessionHasErrors(['latitude', 'longitude', 'delivery_zone_id']);

        $this->assertDatabaseMissing('neighborhoods', ['name' => 'Zone Impossible']);
    }

    public function test_client_cannot_access_admin_locations(): void
    {
        $this->actingAs($this->client())
            ->get(route('admin.locations.index'))
            ->assertForbidden();
    }

    public function test_delivery_zone_is_optional(): void
    {
        $this->actingAs($this->admin())
            ->post(route('admin.locations.store'), [
                'name' => 'Womey',
                'city' => 'Abomey-Calavi',
                'is_active' => 1,
            ])
            ->assertRedirect(route('admin.locations.index'));

        $this->assertDatabaseHas('neighborhoods', [
            'name' => 'Womey',
            'city' => 'Abomey-Calavi',
            'delivery_zone_id' => null,
        ]);
    }

    public function test_zone_can_be_cleared_on_update(): void
    {
        $zone = DeliveryZone::factory()->create();
        $neighborhood = Neighborhood::factory()->create(['delivery_zone_id' => $zone->id]);

        $this->actingAs($this->admin())
            ->put(route('admin.locations.update', $neighborhood), [
                'name' => $neighborhood->name,
                'city' => $neighborhood->city,
                'delivery_zone_id' => null,
                'is_active' => 1,
            ])
            ->assertRedirect(route('admin.locations.index'));

        $this->assertNull($neighborhood->fresh()->delivery_zone_id);
    }
}
