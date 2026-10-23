<?php

namespace Tests\Feature;

use App\Enums\PayoutStatus;
use App\Models\DriverProfile;
use App\Models\Payment;
use App\Models\Payout;
use App\Models\Role;
use App\Models\User;
use App\Models\Wallet;
use App\Services\FinanceService;
use App\Services\Payments\PaymentGateway;
use App\Services\PayoutService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Fakes\PaymentGatewayFake;
use Tests\TestCase;

/**
 * Phases wallet + retraits FedaPay (cahier v1.0) :
 * recharge du flottant livreur via encaissement FedaPay et reversements
 * Mobile Money exécutés par la passerelle.
 */
class FedaPayWalletTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    /** @return array{0: User, 1: DriverProfile} */
    private function driver(int $prepaidBalance = 0): array
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22995######')]);
        $user->roles()->attach(
            Role::where('slug', 'driver-independent')->firstOrFail(),
            ['is_active' => true],
        );

        $profile = DriverProfile::factory()->create([
            'user_id' => $user->id,
            'status' => 'active',
            'available' => true,
            'prepaid_balance' => $prepaidBalance,
        ]);

        return [$user, $profile];
    }

    private function fundedWallet(DriverProfile $driver, int $available = 5000): Wallet
    {
        $wallet = app(FinanceService::class)->walletFor($driver);
        $wallet->update(['available_balance' => $available, 'balance' => $available]);

        return $wallet;
    }

    public function test_float_topup_creates_a_fedapay_checkout_when_configured(): void
    {
        $fake = new PaymentGatewayFake;
        $this->app->instance(PaymentGateway::class, $fake);

        [$user, $profile] = $this->driver(0);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/driver/me/float/topup', ['amount' => 5000])
            ->assertOk()
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.checkout_url', 'https://checkout.fedapay.test/TX-123');

        $this->assertDatabaseHas('payments', [
            'gateway' => 'fedapay',
            'amount' => 5000,
            'gateway_txn_id' => 'TX-123',
        ]);

        $this->assertSame(0, (int) $profile->fresh()->prepaid_balance);
    }

    public function test_float_topup_webhook_credits_the_prepaid_balance(): void
    {
        [$user, $profile] = $this->driver(0);

        $payment = Payment::create([
            'reference' => 'FLOAT-TEST-1',
            'gateway' => 'fedapay',
            'gateway_txn_id' => 'TX-900',
            'amount' => 5000,
            'currency' => 'XOF',
            'status' => 'initiated',
        ]);

        $fake = new PaymentGatewayFake;
        $fake->webhookEvent = [
            'event' => 'transaction.approved',
            'status' => 'success',
            'transaction_id' => 'TX-900',
            'type' => 'float_topup',
            'driver_id' => $profile->id,
            'payment_id' => $payment->id,
            'amount' => 5000,
            'raw' => ['name' => 'transaction.approved'],
        ];
        $this->app->instance(PaymentGateway::class, $fake);

        $this->postJson('/api/v1/payments/webhook', ['name' => 'transaction.approved'])
            ->assertOk();

        $this->assertSame(5000, (int) $profile->fresh()->prepaid_balance);
    }

    public function test_driver_payout_request_records_destination_and_network(): void
    {
        [$user, $profile] = $this->driver();
        $this->fundedWallet($profile);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/driver/me/wallet/payouts', [
            'amount' => 2000,
            'method' => 'moov',
            'destination' => '+22996000000',
        ])
            ->assertCreated()
            ->assertJsonPath('data.method', 'moov')
            ->assertJsonPath('data.destination', '+22996000000')
            ->assertJsonPath('data.status', 'pending');

        $this->assertDatabaseHas('payouts', [
            'method' => 'moov',
            'destination' => '+22996000000',
        ]);
    }

    public function test_payout_request_defaults_to_phone_and_default_network(): void
    {
        [$user, $profile] = $this->driver();
        $this->fundedWallet($profile);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/driver/me/wallet/payouts', ['amount' => 2000])
            ->assertCreated()
            ->assertJsonPath('data.method', 'mtn_open')
            ->assertJsonPath('data.destination', $user->phone);
    }

    public function test_payout_request_executes_immediately_when_gateway_configured(): void
    {
        $fake = new PaymentGatewayFake;
        $this->app->instance(PaymentGateway::class, $fake);

        [, $profile] = $this->driver();
        $wallet = $this->fundedWallet($profile);

        $payout = app(PayoutService::class)->request($profile, 2000, 'moov', '+22996000000');

        $this->assertSame(PayoutStatus::Executed, $payout->status);
        $this->assertCount(1, $fake->payoutCalls);
        $this->assertSame(3000, (int) $wallet->fresh()->available_balance);
    }

    public function test_driver_wallet_summary_exposes_phone_and_payouts(): void
    {
        [$user, $profile] = $this->driver();
        $this->fundedWallet($profile);
        Sanctum::actingAs($user);

        app(PayoutService::class)->request($profile, 2000, 'moov', '+22996000000');

        $this->getJson('/api/v1/driver/me/wallet')
            ->assertOk()
            ->assertJsonPath('data.phone', $user->phone)
            ->assertJsonPath('data.earnings_total', 5000)
            ->assertJsonPath('data.withdrawn_total', 0)
            ->assertJsonPath('data.pending_payout_total', 2000);

        $this->getJson('/api/v1/driver/me/wallet/payouts')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.amount', 2000)
            ->assertJsonPath('data.0.status', 'pending');
    }

    public function test_send_to_gateway_executes_the_payout_with_a_reference(): void
    {
        $fake = new PaymentGatewayFake;
        $this->app->instance(PaymentGateway::class, $fake);

        [, $profile] = $this->driver();
        $this->fundedWallet($profile);

        $payout = app(PayoutService::class)->request($profile, 2000, 'moov', '+22996000000');
        $result = app(PayoutService::class)->sendToGateway($payout);

        $this->assertSame(PayoutStatus::Executed, $result->status);
        $this->assertSame('PO-123', $result->gateway_ref);
        $this->assertCount(1, $fake->payoutCalls);
        $this->assertSame(['moov', '+22996000000'], [$fake->payoutCalls[0][2], $fake->payoutCalls[0][1]]);
    }

    public function test_send_to_gateway_failure_credits_the_wallet_back(): void
    {
        $fake = new PaymentGatewayFake;
        $fake->payoutResult = ['ok' => false, 'status' => 'failed', 'message' => 'Échec fournisseur'];
        $this->app->instance(PaymentGateway::class, $fake);

        [, $profile] = $this->driver();
        $wallet = $this->fundedWallet($profile);

        $payout = app(PayoutService::class)->request($profile, 2000, 'moov', '+22996000000');
        $result = app(PayoutService::class)->sendToGateway($payout);

        $this->assertSame(PayoutStatus::Failed, $result->status);
        $this->assertSame('Échec fournisseur', $result->failed_reason);
        $this->assertSame(5000, (int) $wallet->fresh()->available_balance);
    }

    public function test_send_to_gateway_without_gateway_validates_manually(): void
    {
        [$user, $profile] = $this->driver();
        $this->fundedWallet($profile);

        $fake = new PaymentGatewayFake;
        $fake->configured = false;
        $this->app->instance(PaymentGateway::class, $fake);

        $payout = app(PayoutService::class)->request($profile, 2000, 'moov', '+22996000000');
        $result = app(PayoutService::class)->sendToGateway($payout, $user->id);

        $this->assertSame(PayoutStatus::Executed, $result->status);
        $this->assertSame($user->id, $result->executed_by);
        $this->assertCount(0, $fake->payoutCalls);
    }

    public function test_payout_request_rejects_invalid_destination(): void
    {
        [$user, $profile] = $this->driver();
        $this->fundedWallet($profile);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/driver/me/wallet/payouts', [
            'amount' => 2000,
            'destination' => '123',
        ])->assertStatus(422);
    }

    public function test_send_to_gateway_fails_and_refunds_on_invalid_destination(): void
    {
        $fake = new PaymentGatewayFake;
        $this->app->instance(PaymentGateway::class, $fake);

        [, $profile] = $this->driver();
        $wallet = $this->fundedWallet($profile);

        $payout = app(PayoutService::class)->request($profile, 2000, 'moov', '123');

        $result = app(PayoutService::class)->sendToGateway($payout);

        $this->assertSame(PayoutStatus::Failed, $result->status);
        $this->assertSame(5000, (int) $wallet->fresh()->available_balance);
        $this->assertCount(0, $fake->payoutCalls);
    }

    public function test_payout_webhook_marks_payout_executed(): void
    {
        $fake = new PaymentGatewayFake;
        $fake->webhookEvent = [
            'event' => 'payout.sent',
            'status' => 'success',
            'transaction_id' => 'PO-900',
            'reference' => 'REF-900',
            'raw' => ['name' => 'payout.sent'],
        ];
        $this->app->instance(PaymentGateway::class, $fake);

        [, $profile] = $this->driver();
        $wallet = $this->fundedWallet($profile);

        $payout = Payout::create([
            'wallet_id' => $wallet->id,
            'amount' => 2000,
            'method' => 'mtn_open',
            'destination' => '+22996000000',
            'status' => PayoutStatus::Pending->value,
            'gateway_ref' => 'PO-900',
        ]);

        $this->postJson('/api/v1/payments/webhook', ['name' => 'payout.sent'])->assertOk();

        $this->assertSame(PayoutStatus::Executed, $payout->fresh()->status);
    }
}
