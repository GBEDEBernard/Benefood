<?php

namespace Tests\Feature;

use App\Models\CommissionRate;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Services\FinanceService;
use App\Services\OrderService;
use App\Services\PlatformPricingSettings;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CommissionRateResolutionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function vendor(): Vendor
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22997######')]);
        $role = Role::where('slug', 'vendor')->firstOrFail();
        $user->roles()->attach($role, ['is_active' => true]);

        Sanctum::actingAs($user);

        return Vendor::factory()->create(['status' => 'active', 'user_id' => $user->id]);
    }

    private function commissionFor(Vendor $vendor): int
    {
        return app(OrderService::class)->resolveCommissionRate($vendor);
    }

    public function test_default_rate_is_used_when_no_rate_configured(): void
    {
        $this->assertSame(10, $this->commissionFor($this->vendor()));
    }

    public function test_active_rate_overrides_default(): void
    {
        $vendor = $this->vendor();
        CommissionRate::create([
            'rate' => 15,
            'is_active' => true,
            'effective_from' => now()->subDay(),
            'created_by' => $vendor->user_id,
        ]);

        $this->assertSame(15, $this->commissionFor($vendor));
    }

    public function test_vendor_exception_rate_overrides_active_rate(): void
    {
        $vendor = $this->vendor();
        CommissionRate::create([
            'rate' => 15,
            'is_active' => true,
            'effective_from' => now()->subDay(),
            'created_by' => $vendor->user_id,
        ]);
        $vendor->settings()->create(['commission_exception_rate' => 8]);

        $this->assertSame(8, $this->commissionFor($vendor));
    }

    public function test_expired_or_inactive_rates_are_ignored(): void
    {
        $vendor = $this->vendor();
        CommissionRate::create(['rate' => 7, 'is_active' => false, 'effective_from' => now()->subMonth(), 'created_by' => $vendor->user_id]);
        CommissionRate::create(['rate' => 12, 'is_active' => true, 'effective_from' => now()->subMonth(), 'effective_to' => now()->subDay(), 'created_by' => $vendor->user_id]);

        $this->assertSame(10, $this->commissionFor($vendor));
    }

    public function test_latest_effective_rate_wins(): void
    {
        $vendor = $this->vendor();
        CommissionRate::create(['rate' => 9, 'is_active' => true, 'effective_from' => now()->subYear(), 'created_by' => $vendor->user_id]);
        CommissionRate::create(['rate' => 18, 'is_active' => true, 'effective_from' => now()->subDay(), 'created_by' => $vendor->user_id]);

        $this->assertSame(18, $this->commissionFor($vendor));
    }

    public function test_future_rate_is_ignored_until_its_effective_date(): void
    {
        $vendor = $this->vendor();
        CommissionRate::create(['rate' => 9, 'is_active' => true, 'effective_from' => now()->subDay(), 'created_by' => $vendor->user_id]);
        CommissionRate::create(['rate' => 25, 'is_active' => true, 'effective_from' => now()->addDay(), 'created_by' => $vendor->user_id]);

        $this->assertSame(9, $this->commissionFor($vendor));
    }

    public function test_client_commission_uses_product_subtotal_and_rate_changes_apply_immediately(): void
    {
        $finance = app(FinanceService::class);

        $before = $finance->breakdown(10000, 1000, 10);
        $this->assertSame(500, $before['service_fee']);
        $this->assertSame(11500, $before['total_client']);

        app(PlatformPricingSettings::class)->update([
            'service_fee_rate' => 2,
            'delivery_commission_rate' => 10,
        ]);

        $after = $finance->breakdown(10000, 1000, 10);
        $this->assertSame(200, $after['service_fee']);
        $this->assertSame(11200, $after['total_client']);
        $this->assertSame(100, $after['delivery_commission_amount']);
        $this->assertSame(900, $after['delivery_partner_amount']);
    }
}
