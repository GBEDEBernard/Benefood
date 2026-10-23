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
            'confirmation_code' => '123456',
            'confirmation_code_expires_at' => now()->addDay(),
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

    /**
     * @return array{0: Order, 1: DriverProfile}
     */
    private function inDeliveryOrder(User $client, Vendor $vendor): array
    {
        $order = $this->orderWithFinancials($client, $vendor);

        app(OrderService::class)->confirmPayment($order, $order->total);

        $driver = DriverProfile::factory()->create([
            'user_id' => User::factory()->create()->id,
            'status' => 'active',
            'available' => true,
        ]);

        Delivery::create([
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'vendor_id' => $vendor->id,
            'status' => 'in_delivery',
            'fee' => $order->delivery_fee,
            'partner_amount' => $order->financials->delivery_partner_amount,
        ]);

        $order->update(['status' => OrderStatus::InDelivery->value]);

        return [$order->fresh('delivery.driverProfile', 'financials'), $driver];
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

        $orders->confirmDelivery($order->fresh(), 'client', null, '123456');

        $this->assertSame(0, (int) $vendorWallet->fresh()->pending_balance);
        $this->assertSame(4500, (int) $vendorWallet->fresh()->available_balance);
        $this->assertSame(800, (int) $driverWallet->fresh()->available_balance);
        $this->assertNotNull($order->fresh()->delivery_confirmed_at);
    }

    public function test_online_payment_releases_funds_when_driver_marks_delivered(): void
    {
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $order = $this->orderWithFinancials($client, $vendor);
        $order->update(['payment_method' => 'online']);

        $orders = app(OrderService::class);
        $orders->confirmPayment($order, $order->total);

        $driver = DriverProfile::factory()->create([
            'user_id' => User::factory()->create()->id,
            'status' => 'active',
            'available' => true,
        ]);

        Delivery::create([
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'vendor_id' => $vendor->id,
            'status' => 'in_delivery',
            'fee' => $order->delivery_fee,
            'partner_amount' => $order->financials->delivery_partner_amount,
        ]);

        $order->update(['status' => OrderStatus::InDelivery->value]);

        $finance = app(FinanceService::class);
        $finance->creditDriverForDelivery($order->fresh('financials'), $driver);

        $orders->markDelivered($order->fresh(['delivery.driverProfile']), '123456', $driver->user_id);

        $delivered = $order->fresh();
        $this->assertNotNull($delivered->delivery_confirmed_at);
        $this->assertNotNull($delivered->confirmation_code_confirmed_at);
        $this->assertNull($delivered->auto_confirm_at);

        $this->assertSame(0, (int) $finance->walletFor($vendor)->fresh()->pending_balance);
        $this->assertSame(4500, (int) $finance->walletFor($vendor)->fresh()->available_balance);
        $this->assertSame(0, (int) $finance->walletFor($driver)->fresh()->pending_balance);
        $this->assertSame(800, (int) $finance->walletFor($driver)->fresh()->available_balance);
        $this->assertSame(1000, (int) $finance->platformWallet()->fresh()->available_balance);
    }

    public function test_a_wrong_confirmation_code_blocks_delivery_and_counts_attempts(): void
    {
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        [$order, $driver] = $this->inDeliveryOrder($client, $vendor);

        try {
            app(OrderService::class)->markDelivered($order->fresh('delivery'), '000000', $driver->user_id);
            $this->fail('La livraison ne doit pas être confirmée avec un mauvais code.');
        } catch (DomainException $exception) {
            $this->assertSame('order.wrong_confirmation_code', $exception->errorCode);
        }

        $this->assertSame(OrderStatus::InDelivery, $order->fresh()->status);
        $this->assertSame(1, (int) $order->fresh()->confirmation_code_attempts);
    }

    public function test_an_expired_confirmation_code_blocks_delivery(): void
    {
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        [$order, $driver] = $this->inDeliveryOrder($client, $vendor);

        $order->update(['confirmation_code_expires_at' => now()->subMinute()]);

        try {
            app(OrderService::class)->markDelivered($order->fresh('delivery'), '123456', $driver->user_id);
            $this->fail('Un code expiré ne doit pas libérer les fonds.');
        } catch (DomainException $exception) {
            $this->assertSame('order.confirmation_code_expired', $exception->errorCode);
        }

        $this->assertSame(OrderStatus::InDelivery, $order->fresh()->status);
        $this->assertNull($order->fresh()->delivery_confirmed_at);
    }

    public function test_too_many_wrong_attempts_lock_the_confirmation_code(): void
    {
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        [$order, $driver] = $this->inDeliveryOrder($client, $vendor);

        $order->update(['confirmation_code_attempts' => 5]);

        try {
            app(OrderService::class)->markDelivered($order->fresh('delivery'), '123456', $driver->user_id);
            $this->fail('Un code verrouillé ne doit pas libérer les fonds.');
        } catch (DomainException $exception) {
            $this->assertSame('order.confirmation_code_locked', $exception->errorCode);
        }

        $this->assertSame(OrderStatus::InDelivery, $order->fresh()->status);
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
