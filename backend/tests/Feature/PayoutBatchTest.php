<?php

namespace Tests\Feature;

use App\Enums\PayoutBatchStatus;
use App\Enums\PayoutStatus;
use App\Exceptions\DomainException;
use App\Models\Payout;
use App\Models\PayoutBatch;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Models\Wallet;
use App\Services\FinanceService;
use App\Services\PayoutService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Retraits groupés (Mode B, cahier de conception v1.0) : lot de demandes de
 * retrait créé puis exécuté en une seule opération par l'admin.
 */
class PayoutBatchTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private ?User $adminUser = null;

    private function admin(): User
    {
        return $this->adminUser ??= tap(User::factory()->create(['email' => 'admin@local']), function (User $admin): void {
            $admin->roles()->attach(Role::where('slug', 'admin-technique')->first()->id, ['is_active' => true]);
        });
    }

    private function walletWithAvailable(int $available): Wallet
    {
        $owner = User::factory()->create();
        $vendor = Vendor::factory()->create(['user_id' => $owner->id, 'status' => 'active']);

        $wallet = app(FinanceService::class)->walletFor($vendor);
        $wallet->update(['available_balance' => $available, 'balance' => $available]);

        return $wallet;
    }

    private function pendingPayout(Wallet $wallet, int $amount): Payout
    {
        $payout = Payout::create([
            'wallet_id' => $wallet->id,
            'amount' => $amount,
            'method' => 'mobile_money',
            'status' => PayoutStatus::Pending->value,
        ]);

        app(FinanceService::class)->debitAvailable($wallet, $amount, 'payout_hold', $payout->id, 'Demande de retrait');

        return $payout;
    }

    public function test_creating_a_batch_marks_payouts_as_processing(): void
    {
        $a = $this->pendingPayout($this->walletWithAvailable(5000), 1500);
        $b = $this->pendingPayout($this->walletWithAvailable(7000), 2000);

        $batch = app(PayoutService::class)->createBatch([$a->id, $b->id]);

        $this->assertSame(PayoutBatchStatus::Processing, $batch->status);
        $this->assertSame(2, $batch->payouts_count);
        $this->assertSame(3500, (int) $batch->total_amount);

        $this->assertSame(PayoutStatus::Processing, $a->fresh()->status);
        $this->assertSame($batch->id, $a->fresh()->batch_id);
    }

    public function test_executing_a_batch_marks_all_payouts_executed(): void
    {
        $a = $this->pendingPayout($this->walletWithAvailable(5000), 1500);
        $b = $this->pendingPayout($this->walletWithAvailable(7000), 2000);

        $service = app(PayoutService::class);
        $batch = $service->createBatch([$a->id, $b->id]);

        $executed = $service->executeBatch($batch, null, 'gw-001');

        $this->assertSame(PayoutBatchStatus::Executed, $executed->status);
        $this->assertSame(2, $executed->executed_count);
        $this->assertSame(0, $executed->failed_count);
        $this->assertSame('gw-001', $executed->gateway_ref);
        $this->assertNotNull($executed->executed_at);
        $this->assertSame(PayoutStatus::Executed, $a->fresh()->status);
        $this->assertSame(PayoutStatus::Executed, $b->fresh()->status);
    }

    public function test_failure_of_one_payout_then_execute_rest_yields_partially_failed(): void
    {
        $a = $this->pendingPayout($this->walletWithAvailable(5000), 1500);
        $b = $this->pendingPayout($this->walletWithAvailable(7000), 2000);

        $service = app(PayoutService::class);
        $batch = $service->createBatch([$a->id, $b->id]);

        $service->failBatchPayout($batch, $a, 'Numéro Mobile Money invalide');

        $failed = $a->fresh();
        $this->assertSame(PayoutStatus::Failed, $failed->status);
        $this->assertSame('Numéro Mobile Money invalide', $failed->failed_reason);
        $this->assertSame(PayoutBatchStatus::Processing, $batch->fresh()->status);

        $executed = $service->executeBatch($batch, null, 'gw-002');

        $this->assertSame(PayoutBatchStatus::PartiallyFailed, $executed->status);
        $this->assertSame(1, $executed->executed_count);
        $this->assertSame(1, $executed->failed_count);
    }

    public function test_create_batch_rejects_non_pending_payout(): void
    {
        $a = $this->pendingPayout($this->walletWithAvailable(5000), 1500);
        $a->update(['status' => PayoutStatus::Executed->value]);

        try {
            app(PayoutService::class)->createBatch([$a->id]);
            $this->fail('La création de lot aurait dû être refusée.');
        } catch (DomainException $e) {
            $this->assertSame('payout_batch.not_pending', $e->errorCode);
        }
    }

    public function test_admin_ui_creates_and_executes_a_batch(): void
    {
        $a = $this->pendingPayout($this->walletWithAvailable(5000), 1500);
        $b = $this->pendingPayout($this->walletWithAvailable(7000), 2000);

        $this->actingAs($this->admin())
            ->post(route('admin.payouts.batches.store'), ['payout_ids' => [$a->id, $b->id]])
            ->assertRedirect();

        $batch = PayoutBatch::first();
        $this->assertNotNull($batch);
        $this->assertSame(PayoutBatchStatus::Processing, $batch->status);

        $this->actingAs($this->admin())
            ->get(route('admin.payouts.batches.show', $batch))
            ->assertOk()
            ->assertSee($batch->reference);

        $this->actingAs($this->admin())
            ->post(route('admin.payouts.batches.execute', $batch))
            ->assertRedirect();

        $this->assertSame(PayoutBatchStatus::Executed, $batch->fresh()->status);
        $this->assertSame(PayoutStatus::Executed, $a->fresh()->status);
    }
}
