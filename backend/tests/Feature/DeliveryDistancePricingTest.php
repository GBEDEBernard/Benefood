<?php

namespace Tests\Feature;

use App\Enums\VendorStatus;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\Vendor;
use App\Services\DeliveryPricingService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DeliveryDistancePricingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_fee_for_distance_follows_the_pricing_tiers(): void
    {
        $pricing = app(DeliveryPricingService::class);

        $this->assertSame(500, $pricing->feeForDistance(0.5));
        $this->assertSame(500, $pricing->feeForDistance(2.0));
        $this->assertSame(500, $pricing->feeForDistance(3.0));
        $this->assertSame(1000, $pricing->feeForDistance(8.0));
        $this->assertSame(1000, $pricing->feeForDistance(10.0));
        $this->assertSame(1125, $pricing->feeForDistance(11.0));
        $this->assertSame(1250, $pricing->feeForDistance(12.0));
        $this->assertSame(1625, $pricing->feeForDistance(15.0));
        $this->assertSame(1700, $pricing->feeForDistance(16.0));
        $this->assertSame(2000, $pricing->feeForDistance(20.0));
    }

    public function test_fee_for_distance_is_progressive_between_flat_and_base_km(): void
    {
        $pricing = app(DeliveryPricingService::class);

        // À mi-parcours (5,5 km) : 750 = moitié de l'écart 500 → 1000.
        $this->assertSame(750, $pricing->feeForDistance(5.5));
    }

    public function test_quote_uses_distance_fee_when_both_parties_have_coordinates(): void
    {
        $vendor = Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'latitude' => 6.3700,
            'longitude' => 2.3900,
        ]);

        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);

        // ~2 km → tarif minimum de 500 F, malgré le tarif de zone à 1500 F.
        $this->postJson(route('api.v1.delivery.quote', [
            'vendor_id' => $vendor->id,
            'address' => ['city' => 'Cotonou', 'latitude' => 6.3880, 'longitude' => 2.3900],
        ]))
            ->assertOk()
            ->assertJsonPath('data.delivery_fee', 500);

        // ~9 km → palier inclus : 1000 F.
        $this->postJson(route('api.v1.delivery.quote', [
            'vendor_id' => $vendor->id,
            'address' => ['city' => 'Cotonou', 'latitude' => 6.4510, 'longitude' => 2.3900],
        ]))
            ->assertOk()
            ->assertJsonPath('data.delivery_fee', 1000);
    }

    public function test_quote_falls_back_to_zone_rate_when_vendor_has_no_coordinates(): void
    {
        $vendor = Vendor::factory()->create(['status' => VendorStatus::Active->value]);

        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);

        $this->postJson(route('api.v1.delivery.quote', [
            'vendor_id' => $vendor->id,
            'address' => ['city' => 'Cotonou', 'latitude' => 6.3880, 'longitude' => 2.3900],
        ]))
            ->assertOk()
            ->assertJsonPath('data.delivery_fee', 1500)
            ->assertJsonPath('data.rate.price', 1500);
    }
}
