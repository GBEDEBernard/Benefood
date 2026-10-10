<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Enums\PayoutStatus;
use App\Exceptions\DomainException;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\OrderFinancial;
use App\Models\User;
use App\Models\Vendor;
use App\Services\FinanceService;
use App\Services\OrderService;
use App\Services\PayoutService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FinanceDistributionTest extends TestCase
{
    use RefreshDatabase;

    private function orderWithFinancials(User $client, Vendor $vendor, int $subtotal, int $deliveryFee): Order
    {
        $finance = app(FinanceService::class);
        $breakdown = $finance->breakdown($subtotal, $deliveryFee, 10);

        $order = Order::create([
            'reference' => '#BF'.fake()->unique()->numerify('####'),
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => OrderStatus::AwaitingPayment->value,
            'payment_status' => 'initiated',
            'currency' => 'XOF',
            'subtotal' => $subtotal,
            'delivery_fee' => $deliveryFee,
            'total' => $breakdown['total_client'],
        ]);

        OrderFinancial::create(array_merge(['order_id' => $order->id, 'discount' => 0], $breakdown));

        return $order->fresh('financials');
    }

    public function test_breakdown_matches_cahier_simulation(): void
    {
        $finance = app(FinanceService::class);

        // Commande moyenne : 5 000 nourriture + 1 000 livraison.
        $moyenne = $finance->breakdown(5000, 1000, 10);
        $this->assertSame(300, $moyenne['service_fee']);
        $this->assertSame(6300, $moyenne['total_client']);
        $this->assertSame(4500, $moyenne['vendor_amount']);
        $this->assertSame(800, $moyenne['delivery_partner_amount']);
        $this->assertSame(200, $moyenne['delivery_commission_amount']);
        $this->assertSame(1000, $moyenne['platform_amount']);
        $this->assertSame(76, $moyenne['payment_fee']); // 1,2 % de 6 300

        // Petite commande.
        $petite = $finance->breakdown(1000, 500, 10);
        $this->assertSame(75, $petite['service_fee']);
        $this->assertSame(1575, $petite['total_client']);
        $this->assertSame(900, $petite['vendor_amount']);
        $this->assertSame(400, $petite['delivery_partner_amount']);
        $this->assertSame(275, $petite['platform_amount']);
        $this->assertSame(19, $petite['payment_fee']);

        // Grosse commande.
        $grosse = $finance->breakdown(20000, 1000, 10);
        $this->assertSame(1050, $grosse['service_fee']);
        $this->assertSame(22050, $grosse['total_client']);
        $this->assertSame(18000, $grosse['vendor_amount']);
        $this->assertSame(800, $grosse['delivery_partner_amount']);
        $this->assertSame(3250, $grosse['platform_amount']);
        $this->assertSame(265, $grosse['payment_fee']);
    }

    public function test_payment_credits_vendor_pending_then_delivery_releases_funds(): void
    {
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $order = $this->orderWithFinancials($client, $vendor, 5000, 1000);

        // Confirmation du paiement → part vendeur en attente (séquestre).
        app(OrderService::class)->confirmPayment($order, $order->total);
        $order->refresh();

        $finance = app(FinanceService::class);
        $vendorWallet = $finance->walletFor($vendor);
        $this->assertSame(4500, (int) $vendorWallet->pending_balance);
        $this->assertSame(0, (int) $vendorWallet->available_balance);

        // Assignation livreur → part livreur en attente.
        $driverUser = User::factory()->create();
        $driver = DriverProfile::factory()->create(['user_id' => $driverUser->id, 'status' => 'active', 'available' => true]);

        $finance->creditDriverForDelivery($order, $driver);
        $driverWallet = $finance->walletFor($driver);
        $this->assertSame(800, (int) $driverWallet->pending_balance);

        Delivery::create([
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'vendor_id' => $vendor->id,
            'status' => 'in_delivery',
            'fee' => 1000,
            'partner_amount' => 800,
        ]);

        // Livraison → libération des séquestres.
        $finance->releaseOrderFunds($order->fresh('delivery.driverProfile'));

        $this->assertSame(0, (int) $vendorWallet->fresh()->pending_balance);
        $this->assertSame(4500, (int) $vendorWallet->fresh()->available_balance);
        $this->assertSame(800, (int) $driverWallet->fresh()->available_balance);
    }

    public function test_payout_request_debits_available_and_enforces_minimum(): void
    {
        $vendorUser = User::factory()->create();
        $vendor = Vendor::factory()->create(['user_id' => $vendorUser->id, 'status' => 'active']);

        $finance = app(FinanceService::class);
        $wallet = $finance->walletFor($vendor);
        $wallet->update(['available_balance' => 5000, 'balance' => 5000]);

        $payouts = app(PayoutService::class);

        $payout = $payouts->request($vendor, 1500);
        $this->assertSame(PayoutStatus::Pending, $payout->status);
        $this->assertSame(3500, (int) $wallet->fresh()->available_balance);

        $this->expectException(DomainException::class);
        $payouts->request($vendor, 500); // < minimum 1 000
    }

    public function test_payout_request_rejects_insufficient_funds(): void
    {
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $wallet = app(FinanceService::class)->walletFor($vendor);
        $wallet->update(['available_balance' => 1200, 'balance' => 1200]);

        $this->expectException(DomainException::class);
        app(PayoutService::class)->request($vendor, 5000);
    }
}
