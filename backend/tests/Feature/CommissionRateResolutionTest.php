<?php

namespace Tests\Feature;

use App\Models\CommissionRate;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Services\OrderService;
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
}
