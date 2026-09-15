<?php

namespace Tests\Feature;

use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class AdminDeliveryConfigTest extends TestCase
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
        $client = User::factory()->create(['phone' => '+22997000011']);
        $client->roles()->attach(Role::where('slug', 'client')->first()->id, ['is_active' => true]);

        return $client;
    }

    private function vendor(): Vendor
    {
        return Vendor::factory()->create();
    }

    public function test_guest_is_redirected_to_login(): void
    {
        $this->get(route('admin.zones.index'))->assertRedirect(route('login'));
        $this->get(route('admin.rates.index'))->assertRedirect(route('login'));
    }

    public function test_client_cannot_access_delivery_config(): void
    {
        $this->actingAs($this->client());

        $this->get(route('admin.zones.index'))->assertForbidden();
        $this->get(route('admin.rates.index'))->assertForbidden();
    }

    public function test_admin_can_create_zone_with_identification_mode(): void
    {
        $this->actingAs($this->admin());

        $this->from(route('admin.zones.create'))
            ->post(route('admin.zones.store'), [
                'name' => 'Cotonou Nord',
                'city' => 'Cotonou',
                'identification_mode' => 'distance',
                'terms' => "Fidjrossè\nMarine",
                'center_latitude' => 6.37,
                'center_longitude' => 2.39,
                'radius_km' => 8,
                'sort_order' => 2,
                'is_active' => 1,
            ])
            ->assertRedirect(route('admin.zones.index'))
            ->assertSessionHas('success');

        $zone = DeliveryZone::where('name', 'Cotonou Nord')->firstOrFail();
        $this->assertSame('distance', $zone->identification_mode->value);
        $this->assertSame(['Fidjrossè', 'Marine'], $zone->terms);
        $this->assertSame(8.0, $zone->radius_km);
        $this->assertTrue($zone->is_active);
    }

    public function test_admin_can_update_zone_to_inactive(): void
    {
        $zone = DeliveryZone::factory()->create();

        $this->actingAs($this->admin())
            ->from(route('admin.zones.edit', $zone))
            ->put(route('admin.zones.update', $zone), [
                'name' => $zone->name,
                'city' => $zone->city,
                'identification_mode' => 'zone',
                'is_active' => 0,
            ])
            ->assertRedirect(route('admin.zones.index'))
            ->assertSessionHas('success');

        $this->assertFalse($zone->fresh()->is_active);
    }

    public function test_admin_can_destroy_zone_logically(): void
    {
        $zone = DeliveryZone::factory()->create();

        $this->actingAs($this->admin())
            ->delete(route('admin.zones.destroy', $zone))
            ->assertRedirect(route('admin.zones.index'));

        $this->assertFalse($zone->fresh()->is_active);
        $this->assertDatabaseHas('delivery_zones', ['id' => $zone->id]);
    }

    public function test_zone_validation_rejects_unknown_identification_mode(): void
    {
        $this->actingAs($this->admin())
            ->post(route('admin.zones.store'), [
                'name' => 'Zone Interdite',
                'city' => 'Cotonou',
                'identification_mode' => 'hyper-espace',
            ])
            ->assertSessionHasErrors('identification_mode');

        $this->assertDatabaseMissing('delivery_zones', ['name' => 'Zone Interdite']);
    }

    public function test_admin_can_create_default_rate(): void
    {
        $zone = DeliveryZone::factory()->create();

        $this->actingAs($this->admin())
            ->from(route('admin.rates.create'))
            ->post(route('admin.rates.store'), [
                'zone_id' => $zone->id,
                'vendor_id' => null,
                'price' => 1500,
                'is_active' => 1,
            ])
            ->assertRedirect(route('admin.rates.index'))
            ->assertSessionHas('success');

        $this->assertDatabaseHas('delivery_rates', [
            'zone_id' => $zone->id,
            'vendor_id' => null,
            'price' => 1500,
            'is_active' => true,
        ]);
    }

    public function test_admin_can_create_vendor_specific_rate(): void
    {
        $zone = DeliveryZone::factory()->create();
        $vendor = $this->vendor();

        $this->actingAs($this->admin())
            ->post(route('admin.rates.store'), [
                'zone_id' => $zone->id,
                'vendor_id' => $vendor->id,
                'price' => 2500,
            ])
            ->assertRedirect(route('admin.rates.index'));

        $this->assertDatabaseHas('delivery_rates', [
            'zone_id' => $zone->id,
            'vendor_id' => $vendor->id,
            'price' => 2500,
        ]);
    }

    public function test_admin_can_update_rate_with_validity_window(): void
    {
        $rate = DeliveryRate::factory()->create(['price' => 1000]);

        $this->actingAs($this->admin())
            ->from(route('admin.rates.edit', $rate))
            ->put(route('admin.rates.update', $rate), [
                'zone_id' => $rate->zone_id,
                'vendor_id' => null,
                'price' => 1800,
                'effective_from' => now()->toDateString(),
                'effective_to' => now()->addMonth()->toDateString(),
                'is_active' => 1,
            ])
            ->assertRedirect(route('admin.rates.index'))
            ->assertSessionHas('success');

        $rate->refresh();
        $this->assertSame(1800, $rate->price);
        $this->assertTrue($rate->isEffectiveAt(now()->addDays(10)));
        $this->assertFalse($rate->isEffectiveAt(now()->addMonths(2)));
    }

    public function test_rate_validation_rejects_unknown_zone_and_negative_price(): void
    {
        $this->actingAs($this->admin())
            ->post(route('admin.rates.store'), [
                'zone_id' => Str::uuid()->toString(),
                'price' => -10,
            ])
            ->assertSessionHasErrors(['zone_id', 'price']);

        $this->assertDatabaseCount('delivery_rates', 0);
    }

    public function test_admin_can_destroy_rate_logically(): void
    {
        $rate = DeliveryRate::factory()->create();

        $this->actingAs($this->admin())
            ->delete(route('admin.rates.destroy', $rate))
            ->assertRedirect(route('admin.rates.index'));

        $this->assertFalse($rate->fresh()->is_active);
        $this->assertDatabaseHas('delivery_rates', ['id' => $rate->id, 'is_active' => false]);
    }
}
