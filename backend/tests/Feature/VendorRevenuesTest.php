<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\OrderFinancial;
use App\Models\Payout;
use App\Models\User;
use App\Models\Vendor;
use App\Models\Wallet;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class VendorRevenuesTest extends TestCase
{
    use RefreshDatabase;

    public function test_vendor_can_see_revenue_summary_and_transactions(): void
    {
        $vendorUser = User::factory()->create();
        $vendor = Vendor::factory()->create(['user_id' => $vendorUser->id, 'status' => 'active']);
        $client = User::factory()->create();

        $this->financialOrder($client, $vendor, '#BF2001', 'delivered', 1000, 100, 900);
        $this->financialOrder($client, $vendor, '#BF2002', 'delivered', 2000, 200, 1800);
        $this->financialOrder($client, $vendor, '#BF2003', 'preparing', 1500, 150, 1350);

        $wallet = Wallet::create(['owner_type' => 'vendor', 'owner_id' => $vendor->id, 'balance' => 2700, 'available_balance' => 2700]);
        Payout::create([
            'wallet_id' => $wallet->id,
            'amount' => 500,
            'method' => 'kkiapay',
            'status' => 'executed',
            'executed_at' => now(),
        ]);

        Sanctum::actingAs($vendorUser);

        $this->getJson('/api/v1/vendors/me/revenues')
            ->assertOk()
            ->assertJsonPath('data.currency', 'XOF')
            ->assertJsonPath('data.gross_sales', 3000)
            ->assertJsonPath('data.net_sales', 2700)
            ->assertJsonPath('data.commission', 300)
            ->assertJsonPath('data.pending_amount', 1350)
            ->assertJsonPath('data.available_balance', 2700)
            ->assertJsonCount(3, 'data.transactions')
            ->assertJsonCount(1, 'data.payouts')
            ->assertJsonPath('data.payouts.0.status', 'executed')
            ->assertJsonStructure(['data' => ['transactions' => [['id', 'reference', 'gross', 'commission', 'net']]]]);
    }

    public function test_revenue_period_filters_delivered_orders(): void
    {
        $vendorUser = User::factory()->create();
        $vendor = Vendor::factory()->create(['user_id' => $vendorUser->id, 'status' => 'active']);
        $client = User::factory()->create();

        $this->financialOrder($client, $vendor, '#BF3001', 'delivered', 1000, 100, 900, now()->subMonth());
        $this->financialOrder($client, $vendor, '#BF3002', 'delivered', 2000, 200, 1800, now());

        Sanctum::actingAs($vendorUser);

        $from = now()->startOfMonth()->toDateString();
        $to = now()->endOfMonth()->toDateString();

        $this->getJson("/api/v1/vendors/me/revenues?from={$from}&to={$to}")
            ->assertOk()
            ->assertJsonPath('data.gross_sales', 2000)
            ->assertJsonPath('data.orders_count', 1)
            ->assertJsonCount(1, 'data.transactions');
    }

    public function test_revenue_requires_valid_period(): void
    {
        $vendorUser = User::factory()->create();
        Vendor::factory()->create(['user_id' => $vendorUser->id, 'status' => 'active']);

        Sanctum::actingAs($vendorUser);

        $this->getJson('/api/v1/vendors/me/revenues?from=2026-10-10&to=2026-10-01')
            ->assertStatus(422);
    }

    private function financialOrder(
        User $client,
        Vendor $vendor,
        string $reference,
        string $status,
        int $subtotal,
        int $commission,
        int $net,
        mixed $deliveredAt = null,
    ): Order {
        $order = Order::create([
            'reference' => $reference,
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => $status,
            'payment_status' => 'confirmed',
            'currency' => 'XOF',
            'subtotal' => $subtotal,
            'total' => $subtotal,
            'delivered_at' => $status === 'delivered' ? ($deliveredAt ?? now()) : null,
        ]);

        OrderFinancial::create([
            'order_id' => $order->id,
            'subtotal' => $subtotal,
            'commission_base' => $subtotal,
            'commission_rate' => 10,
            'commission_amount' => $commission,
            'vendor_amount' => $net,
            'total_client' => $subtotal,
        ]);

        return $order;
    }
}
