<?php

namespace Tests\Feature;

use App\Enums\VendorStatus;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class DeliveryQuoteApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function activeVendor(): Vendor
    {
        return Vendor::factory()->create(['status' => VendorStatus::Active->value]);
    }

    private function quote(array $address, ?Vendor $vendor = null): TestResponse
    {
        return $this->postJson(route('api.v1.delivery.quote', [
            'vendor_id' => ($vendor ?? $this->activeVendor())->id,
            'address' => $address,
        ]));
    }

    public function test_quote_resolves_zone_by_name_and_returns_delivery_fee(): void
    {
        $vendor = $this->activeVendor();
        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);

        $this->quote(['city' => 'Cotonou'], $vendor)
            ->assertOk()
            ->assertJsonPath('data.zone.id', $zone->id)
            ->assertJsonPath('data.zone.identification_mode', 'zone')
            ->assertJsonPath('data.delivery_fee', 1500)
            ->assertJsonPath('data.currency', 'XOF')
            ->assertJsonPath('data.rate.is_vendor_specific', false);
    }

    public function test_quote_resolves_zone_by_quarter_term(): void
    {
        $vendor = $this->activeVendor();
        $zone = DeliveryZone::factory()->quarter()->create(['city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 2000]);

        $this->quote(['address_text' => 'rue 145 Akpakpa'], $vendor)
            ->assertOk()
            ->assertJsonPath('data.zone.id', $zone->id)
            ->assertJsonPath('data.delivery_fee', 2000);
    }

    public function test_quote_uses_vendor_specific_rate_over_default(): void
    {
        $vendor = $this->activeVendor();
        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);
        DeliveryRate::factory()->vendorSpecific($vendor->id)->create(['zone_id' => $zone->id, 'price' => 2500]);

        $this->quote(['city' => 'Cotonou'], $vendor)
            ->assertOk()
            ->assertJsonPath('data.delivery_fee', 2500)
            ->assertJsonPath('data.rate.is_vendor_specific', true);
    }

    public function test_quote_ignores_expired_and_inactive_rates(): void
    {
        $vendor = $this->activeVendor();
        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->expired()->create(['zone_id' => $zone->id, 'price' => 500]);
        DeliveryRate::factory()->future()->create(['zone_id' => $zone->id, 'price' => 500]);
        DeliveryRate::factory()->inactive()->create(['zone_id' => $zone->id, 'price' => 500]);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1800]);

        $this->quote(['city' => 'Cotonou'], $vendor)
            ->assertJsonPath('data.delivery_fee', 1800);
    }

    public function test_quote_rejects_inactive_zone_even_if_position_matches(): void
    {
        $vendor = $this->activeVendor();
        $zone = DeliveryZone::factory()->distance(radiusKm: 10)->inactive()->create();
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);

        $this->quote(['latitude' => 6.37, 'longitude' => 2.39], $vendor)
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'delivery.zone_not_found');
    }

    public function test_quote_distance_match_within_radius(): void
    {
        $vendor = $this->activeVendor();
        $zone = DeliveryZone::factory()->distance(radiusKm: 10)->create();
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);

        $this->quote(['latitude' => 6.37, 'longitude' => 2.39], $vendor)
            ->assertOk()
            ->assertJsonPath('data.zone.id', $zone->id)
            ->assertJsonPath('data.delivery_fee', 1500);
    }

    public function test_quote_distance_miss_outside_radius(): void
    {
        $vendor = $this->activeVendor();
        $zone = DeliveryZone::factory()->distance(radiusKm: 1)->create();
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);

        $this->quote(['latitude' => 9.0, 'longitude' => 2.0], $vendor)
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'delivery.zone_not_found');
    }

    public function test_quote_does_not_crash_when_distance_zone_receives_address_without_coordinates(): void
    {
        $vendor = $this->activeVendor();
        $named = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $named->id, 'price' => 1500]);
        DeliveryZone::factory()->distance(radiusKm: 10)->create();

        $this->quote(['city' => 'Cotonou'], $vendor)
            ->assertOk()
            ->assertJsonPath('data.zone.id', $named->id)
            ->assertJsonPath('data.delivery_fee', 1500);
    }

    public function test_quote_unknown_zone_returns_422_domain_code(): void
    {
        DeliveryZone::factory()->create(['city' => 'Cotonou']);

        $this->quote(['city' => 'Parakou'])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'delivery.zone_not_found');
    }

    public function test_quote_zone_without_rate_returns_422_domain_code(): void
    {
        DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);

        $this->quote(['city' => 'Cotonou'])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'delivery.rate_not_configured');
    }

    public function test_quote_rejects_suspended_vendor(): void
    {
        $vendor = Vendor::factory()->create(['status' => VendorStatus::Suspended->value]);
        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id]);

        $this->quote(['city' => 'Cotonou'], $vendor)
            ->assertStatus(404)
            ->assertJsonPath('errors.0.code', 'vendor.not_found');
    }

    public function test_quote_validates_address_fields(): void
    {
        $this->postJson(route('api.v1.delivery.quote', [
            'vendor_id' => $this->activeVendor()->id,
            'address' => ['latitude' => 95],
        ]))
            ->assertStatus(422)
            ->assertJsonStructure(['errors' => [['code', 'message', 'field']]]);
    }
}
