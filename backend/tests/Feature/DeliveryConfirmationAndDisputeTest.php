<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Exceptions\DomainException;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\OrderFinancial;
use App\Models\User;
use App\Models\Vendor;
use App\Services\FinanceService;
use App\Services\OrderService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DeliveryConfirmationAndDisputeTest extends TestCase
{
    use RefreshDatabase;

    private function orderWithFinancials(User $client, Vendor $vendor): Order
    {
        $finance = app(FinanceService::class);
        $breakdown = $finance->breakdown(5000, 1000, 10);

        $order = Order::create([
            'reference' => '#BF'.fake()->unique()->numerify('####'),
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => OrderStatus::AwaitingPayment->value,
            'payment_status' => 'initiated',
            'currency' => 'XOF',
            'subtotal' => 5000,
            'delivery_fee' => 1000,
            'total' => $breakdown['total_client'],
        ]);

        OrderFinancial::create(array_merge(['order_id' => $order->id, 'discount' => 0], $breakdown));

        return $order->fresh('financials');
    }

    private function deliveredWithDriver(Order $order, Vendor $vendor): DriverProfile
    {
        $finance = app(FinanceService::class);

        $driver = DriverProfile::factory()->create([
            'user_id' => User::factory()->create()->id,
            'status' => 'active',
            'available' => true,
        ]);

        Delivery::create([
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'vendor_id' => $vendor->id,
            'status' => 'delivered',
            'fee' => $order->delivery_fee,
            'partner_amount' => $order->financials->delivery_partner_amount,
        ]);

        $order->load('delivery.driverProfile');

        $order->update([
            'status' => OrderStatus::Delivered->value,
            'delivered_at' => now(),
            'auto_confirm_at' => now()->addMinutes(30),
        ]);

        return $driver;
    }

    public function test_delivery_keeps_funds_pending_until_client_confirms(): void
    {
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $order = $this->orderWithFinancials($client, $vendor);

        $orders = app(OrderService::class);
        $orders->confirmPayment($order, $order->total);
        $driver = $this->deliveredWithDriver($order->fresh('delivery.driverProfile'), $vendor);

        $finance = app(FinanceService::class);
        $finance->creditDriverForDelivery($order->fresh('financials'), $driver);

        $vendorWallet = $finance->walletFor($vendor);
        $driverWallet = $finance->walletFor($driver);

        // Avant confirmation : tout reste en attente.
        $this->assertSame(4500, (int) $vendorWallet->fresh()->pending_balance);
        $this->assertSame(0, (int) $vendorWallet->fresh()->available_balance);

        $orders->confirmDelivery($order->fresh());

        $this->assertSame(0, (int) $vendorWallet->fresh()->pending_balance);
        $this->assertSame(4500, (int) $vendorWallet->fresh()->available_balance);
        $this->assertSame(800, (int) $driverWallet->fresh()->available_balance);
        $this->assertNotNull($order->fresh()->delivery_confirmed_at);
    }

    public function test_auto_confirm_releases_after_deadline(): void
    {
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $order = $this->orderWithFinancials($client, $vendor);

        $orders = app(OrderService::class);
        $orders->confirmPayment($order, $order->total);
        $this->deliveredWithDriver($order->fresh('delivery.driverProfile'), $vendor);

        $order->refresh();
        $order->update(['auto_confirm_at' => now()->subMinute()]);

        $count = $orders->autoConfirmDeliveries();

        $this->assertSame(1, $count);
        $this->assertNotNull($order->fresh()->delivery_confirmed_at);

        $finance = app(FinanceService::class);
        $this->assertSame(4500, (int) $finance->walletFor($vendor)->fresh()->available_balance);
    }

    public function test_dispute_blocks_confirmation_and_resolution_releases_funds(): void
    {
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $order = $this->orderWithFinancials($client, $vendor);

        $orders = app(OrderService::class);
        $orders->confirmPayment($order, $order->total);
        $this->deliveredWithDriver($order->fresh('delivery.driverProfile'), $vendor);

        $disputed = $orders->openDispute($order->fresh(), 'client', $client->id, 'Plat froid');
        $this->assertSame(OrderStatus::Disputed, $disputed->status);

        try {
            $orders->confirmDelivery($disputed);
            $this->fail('La confirmation aurait dû être refusée pendant un litige.');
        } catch (DomainException) {
            // attendu
        }

        $orders->resolveDispute($disputed->fresh(), 'release', User::factory()->create()->id);

        $finance = app(FinanceService::class);
        $this->assertSame(4500, (int) $finance->walletFor($vendor)->fresh()->available_balance);
    }
}
