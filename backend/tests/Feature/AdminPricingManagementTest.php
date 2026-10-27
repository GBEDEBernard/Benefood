<?php

namespace Tests\Feature;

use App\Models\DistancePricingRule;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Services\DeliveryPricingService;
use App\Services\ParcelPricingService;
use App\Services\PlatformPricingSettings;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminPricingManagementTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function admin(): User
    {
        $user = User::factory()->create(['email' => 'pricing-admin@local']);
        $user->roles()->attach(Role::where('slug', 'admin-technique')->firstOrFail()->id, ['is_active' => true]);

        return $user;
    }

    public function test_admin_can_manage_platform_pricing_and_distance_rules(): void
    {
        $admin = $this->admin();

        $this->actingAs($admin)
            ->get(route('admin.pricing.index'))
            ->assertOk()
            ->assertSee('Tarifs et barèmes de distance')
            ->assertSee('Envoi de colis');

        $this->post(route('admin.pricing.settings'), [
            'order_minimum_fee' => 600,
            'order_default_fee' => 1200,
            'parcel_minimum_fee' => 500,
            'parcel_default_fee' => 1100,
            'parcel_creation_fee' => 200,
            'service_fee_rate' => 6,
            'delivery_commission_rate' => 18,
            'parcel_commission_rate' => 22,
            'gateway_fee_basis_points' => 125,
            'minimum_payout' => 1500,
        ])->assertRedirect();

        $this->assertSame(600, app(PlatformPricingSettings::class)->get('order_minimum_fee'));

        $this->put(route('admin.commissions.platform-settings'), [
            'service_fee_rate' => 6,
            'delivery_commission_rate' => 18,
            'driver_max_active_missions' => 3,
            'parcel_commission_rate' => 22,
            'parcel_creation_fee' => 250,
            'gateway_fee_basis_points' => 125,
            'minimum_payout' => 1500,
        ])->assertRedirect();

        $this->assertSame(22, app(PlatformPricingSettings::class)->get('parcel_commission_rate'));
        $this->assertSame(250, app(PlatformPricingSettings::class)->get('parcel_creation_fee'));
        $this->assertSame(3, app(PlatformPricingSettings::class)->get('driver_max_active_missions'));

        $this->post(route('admin.pricing.rules.store'), [
            'service_type' => 'order',
            'max_km' => 2,
            'base_fee' => 500,
            'per_km' => 0,
            'discount_percentage' => 0,
        ])->assertRedirect();

        $rule = DistancePricingRule::query()->where('service_type', 'order')->where('max_km', 2)->firstOrFail();
        $this->assertSame(600, app(DeliveryPricingService::class)->feeForDistance(1));

        $this->put(route('admin.pricing.rules.update', $rule), [
            'max_km' => 2,
            'base_fee' => 1000,
            'per_km' => 0,
            'discount_percentage' => 20,
        ])->assertRedirect();

        $this->assertSame(800, app(DeliveryPricingService::class)->feeForDistance(1));

        $this->delete(route('admin.pricing.rules.destroy', $rule))->assertRedirect();
        $this->assertDatabaseMissing('distance_pricing_rules', ['id' => $rule->id]);
    }

    public function test_order_and_parcel_quotes_use_database_rules_and_discount_percentages(): void
    {
        app(PlatformPricingSettings::class)->update(['parcel_commission_rate' => 22]);

        DistancePricingRule::create([
            'service_type' => 'order',
            'max_km' => 5,
            'base_fee' => 1000,
            'per_km' => 0,
            'discount_percentage' => 20,
            'sort_order' => 1,
            'is_active' => true,
        ]);
        DistancePricingRule::create([
            'service_type' => 'order',
            'max_km' => null,
            'base_fee' => 2000,
            'per_km' => 0,
            'discount_percentage' => 0,
            'sort_order' => 2,
            'is_active' => true,
        ]);
        DistancePricingRule::create([
            'service_type' => 'parcel',
            'max_km' => 3,
            'base_fee' => 700,
            'per_km' => 0,
            'discount_percentage' => 10,
            'sort_order' => 1,
            'is_active' => true,
        ]);
        DistancePricingRule::create([
            'service_type' => 'parcel',
            'max_km' => null,
            'base_fee' => 2000,
            'per_km' => 0,
            'discount_percentage' => 0,
            'sort_order' => 2,
            'is_active' => true,
        ]);

        $this->assertSame(800, app(DeliveryPricingService::class)->feeForDistance(4));
        $this->assertSame(630, app(ParcelPricingService::class)->feeForDistance(2));
        $this->assertSame(22, app(ParcelPricingService::class)->quote(2)['commission_rate']);
    }

    public function test_admin_can_set_a_vendor_specific_commission(): void
    {
        $admin = $this->admin();
        $vendor = Vendor::factory()->create();

        $this->actingAs($admin)
            ->put(route('admin.commissions.vendors.update', $vendor), [
                'commission_exception_rate' => 7,
            ])
            ->assertRedirect();

        $this->assertSame(7, (int) $vendor->settings()->value('commission_exception_rate'));
    }
}
