<?php

namespace Tests\Feature;

use App\Models\Address;
use App\Models\Category;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Product;
use App\Models\Role;
use App\Models\PlatformSetting;
use App\Models\User;
use App\Models\Vendor;
use App\Services\PlatformPricingSettings;
use Illuminate\Support\Facades\Cache;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ApproachPricingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);

        app(PlatformPricingSettings::class)->update([
            'delivery_commission_rate' => 20,
            'approach_free_km' => 3,
            'approach_per_km' => 50,
        ]);
    }

    private function actingUser(string $roleSlug): User
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22997######')]);
        $user->roles()->attach(Role::where('slug', $roleSlug)->firstOrFail(), ['is_active' => true]);

        Sanctum::actingAs($user);

        return $user;
    }

    private function addToCart(User $client, Product $product): void
    {
        Sanctum::actingAs($client);

        $this->postJson('/api/v1/cart/items', [
            'product_id' => $product->id,
            'quantity' => 2,
        ])->assertOk();
    }

    public function test_selected_driver_approach_fee_is_included_in_summary_and_order_snapshot(): void
    {
        $client = $this->actingUser('client');
        $vendor = Vendor::factory()->create([
            'status' => 'active',
            'latitude' => 6.360,
            'longitude' => 2.420,
            'pickup_latitude' => 6.360,
            'pickup_longitude' => 2.420,
            'pickup_address' => 'Marché Dantokpa',
            'city' => 'Cotonou',
        ]);
        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'price' => 500,
            'stock_qty' => 10,
            'is_active' => true,
            'is_available' => true,
        ]);
        $address = Address::factory()->create([
            'user_id' => $client->id,
            'city' => 'Cotonou',
            'latitude' => 6.380,
            'longitude' => 2.440,
        ]);
        $driver = DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
            'last_latitude' => 6.405,
            'last_longitude' => 2.420,
            'last_location_at' => now(),
        ]);

        $this->addToCart($client, $product);

        $this->postJson('/api/v1/orders/checkout-drivers', [
            'address_id' => $address->id,
        ])
            ->assertOk()
            ->assertJsonPath('data.drivers.0.id', $driver->id)
            ->assertJsonPath('data.drivers.0.approach_fee', 100);

        $summary = $this->postJson('/api/v1/orders/summary', [
            'address_id' => $address->id,
            'driver_profile_id' => $driver->id,
        ])->assertOk();

        $baseFee = (int) $summary->json('data.delivery_fee');

        $summary
            ->assertJsonPath('data.selected_driver.id', $driver->id)
            ->assertJsonPath('data.approach_fee', 100)
            ->assertJsonPath('data.delivery_total', $baseFee + 100)
            ->assertJsonPath('data.total', 1000 + $baseFee + 100 + 50);

        $response = $this->postJson('/api/v1/orders', [
            'address_id' => $address->id,
            'driver_profile_id' => $driver->id,
        ])->assertCreated();

        $order = Order::where('reference', $response->json('data.reference'))->firstOrFail()->fresh('financials');

        $this->assertSame($driver->id, $order->preferred_driver_profile_id);
        $this->assertSame(100, $order->approach_fee);
        $this->assertSame(5.004, round($order->approach_distance_km, 3));
        $this->assertSame(50, $order->approach_pricing_snapshot['per_km']);
        $this->assertSame($baseFee + 100, $order->financials->delivery_total);
        $this->assertSame((int) round(($baseFee + 100) * 0.2), $order->financials->delivery_commission_amount);
        $this->assertSame(
            $order->financials->delivery_partner_amount,
            $order->financials->base_partner_amount + $order->financials->approach_partner_amount,
        );
    }

    /**
     * Un livreur à 12,5 km du point de collecte doit faire payer au client les
     * km d'approche au-delà des 3 km offerts (barème de la porteuse).
     */
    public function test_approach_fee_is_charged_when_the_chosen_driver_is_far_from_the_pickup(): void
    {
        $client = $this->actingUser('client');
        $vendor = Vendor::factory()->create([
            'status' => 'active',
            'latitude' => 6.360,
            'longitude' => 2.420,
            'pickup_latitude' => 6.360,
            'pickup_longitude' => 2.420,
            'pickup_address' => 'Marché Dantokpa',
            'city' => 'Cotonou',
        ]);
        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'price' => 500,
            'stock_qty' => 10,
            'is_active' => true,
            'is_available' => true,
        ]);
        // Client à ~1,2 km de la boutique : il paie le tarif de base.
        $address = Address::factory()->create([
            'user_id' => $client->id,
            'city' => 'Cotonou',
            'latitude' => 6.370847,
            'longitude' => 2.420,
        ]);
        // Livreur à ~12,5 km de la boutique.
        $driver = DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
            'last_latitude' => 6.473045,
            'last_longitude' => 2.420,
            'last_location_at' => now(),
        ]);

        $this->addToCart($client, $product);

        $summary = $this->postJson('/api/v1/orders/summary', [
            'address_id' => $address->id,
            'driver_profile_id' => $driver->id,
        ])->assertOk();

        $baseFee = (int) $summary->json('data.delivery_fee');

        $approachKm = (float) $summary->json('data.approach_distance_km');
        $approachFee = (int) $summary->json('data.approach_fee');

        $this->assertSame(500, $baseFee, 'Le client est à 1,2 km : tarif de base minimum.');
        $this->assertGreaterThan(12.0, $approachKm);
        $this->assertLessThan(13.0, $approachKm);
        // 12,5 km − 3 km offerts ≈ 9,5 km payés à 50 F/km.
        $this->assertSame((int) round(($approachKm - 3) * 50), $approachFee);
        $this->assertGreaterThan(400, $approachFee);
        $this->assertSame($baseFee + $approachFee, (int) $summary->json('data.delivery_total'));
        // Le client paie bien la livraison de base + les km d'approche.
        $this->assertSame(
            (int) $summary->json('data.subtotal')
                + (int) $summary->json('data.delivery_total')
                + (int) $summary->json('data.service_fee'),
            (int) $summary->json('data.total'),
        );

        $response = $this->postJson('/api/v1/orders', [
            'address_id' => $address->id,
            'driver_profile_id' => $driver->id,
        ])->assertCreated();

        $order = Order::where('reference', $response->json('data.reference'))->firstOrFail()->fresh('financials');
        $snapshot = $order->approach_pricing_snapshot;

        $this->assertSame($driver->id, $order->preferred_driver_profile_id);
        $this->assertSame(3, $snapshot['free_km']);
        $this->assertSame(50, $snapshot['per_km']);
        $this->assertSame((int) round($snapshot['billable_km'] * 50), $order->approach_fee);
        $this->assertGreaterThan(0, $order->approach_fee);
        $this->assertSame($order->approach_fee, (int) $order->financials->approach_fee);
        $this->assertSame(
            (int) $order->delivery_fee + $order->approach_fee,
            (int) $order->financials->delivery_total,
        );
    }

    /**
     * Un cache enregistré avant l'ajout d'un réglage ne doit pas le remettre à
     * zéro : les valeurs de secours de la config restent prioritaires.
     */
    public function test_a_pricing_cache_saved_before_a_setting_existed_does_not_zero_it(): void
    {
        // Entrée de cache d'avant l'introduction des frais d'approche : la clé
        // courante comme la clé historique, pour couvrir un cache déjà rempli.
        $stale = ['order_default_fee' => 1200, 'service_fee_rate' => 5];
        Cache::put('platform-pricing-settings-v2', $stale);
        Cache::put('platform-pricing-settings-v1', $stale);

        $settings = app(PlatformPricingSettings::class);

        $this->assertSame(3, $settings->get('approach_free_km'));
        $this->assertSame(50, $settings->get('approach_per_km'));
        // Les réglages réellement enregistrés restent prioritaires.
        $this->assertSame(1200, $settings->get('order_default_fee'));
    }

    /**
     * Une ligne `platform_settings` enregistrée avant l'ajout des frais
     * d'approche ne doit pas les neutraliser non plus.
     */
    public function test_a_pricing_row_saved_before_a_setting_existed_does_not_zero_it(): void
    {
        PlatformSetting::query()->whereKey('pricing')->update([
            'value' => ['order_default_fee' => 1000, 'service_fee_rate' => 5],
        ]);
        Cache::forget('platform-pricing-settings-v2');

        $settings = app(PlatformPricingSettings::class);

        $this->assertSame(3, $settings->get('approach_free_km'));
        $this->assertSame(50, $settings->get('approach_per_km'));
    }
}
