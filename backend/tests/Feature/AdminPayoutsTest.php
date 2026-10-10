<?php

namespace Tests\Feature;

use App\Enums\PayoutStatus;
use App\Models\Payout;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Models\Wallet;
use App\Services\FinanceService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminPayoutsTest extends TestCase
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

    private function walletWithAvailable(int $available): Wallet
    {
        $owner = User::factory()->create();
        $vendor = Vendor::factory()->create(['user_id' => $owner->id, 'status' => 'active', 'business_name' => 'Chez Edna']);

        $wallet = app(FinanceService::class)->walletFor($vendor);
        $wallet->update(['available_balance' => $available, 'balance' => $available]);

        return $wallet;
    }

    private function pendingPayout(Wallet $wallet, int $amount): Payout
    {
        return Payout::create([
            'wallet_id' => $wallet->id,
            'amount' => $amount,
            'method' => 'mobile_money',
            'status' => PayoutStatus::Pending->value,
        ]);
    }

    public function test_admin_can_view_payouts_page(): void
    {
        $wallet = $this->walletWithAvailable(5000);
        $this->pendingPayout($wallet, 1500);

        $this->actingAs($this->admin())
            ->get(route('admin.payouts.index'))
            ->assertOk()
            ->assertSee('Wallets & retraits')
            ->assertSee('Chez Edna');
    }

    public function test_admin_executes_a_payout(): void
    {
        $wallet = $this->walletWithAvailable(5000);
        $payout = $this->pendingPayout($wallet, 1500);

        $this->actingAs($this->admin())
            ->post(route('admin.payouts.execute', $payout))
            ->assertRedirect();

        $this->assertSame(PayoutStatus::Executed, $payout->fresh()->status);
    }

    public function test_admin_failing_a_payout_credits_the_wallet_back(): void
    {
        // Le solde disponible a déjà été débité à la demande : ici 3500 restants.
        $wallet = $this->walletWithAvailable(3500);
        $payout = $this->pendingPayout($wallet, 1500);

        $this->actingAs($this->admin())
            ->post(route('admin.payouts.fail', $payout))
            ->assertRedirect();

        $this->assertSame(PayoutStatus::Failed, $payout->fresh()->status);
        $this->assertSame(5000, (int) $wallet->fresh()->available_balance);
    }
}
