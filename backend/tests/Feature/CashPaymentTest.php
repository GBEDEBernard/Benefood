<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Enums\PaymentMethod;
use App\Exceptions\DomainException;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\OrderFinancial;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Services\CashService;
use App\Services\FinanceService;
use App\Services\OrderService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Paiement à la livraison (cash) — cahier de conception v1.0 :
 * flottant prépayé du livreur, garde-fou à l'assignation, règlement immédiat
 * à la livraison (débit flottant + parts vendeur/livreur).
 */
class CashPaymentTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function cashOrder(User $client, Vendor $vendor): Order
    {
        $breakdown = app(FinanceService::class)->breakdown(5000, 1000, 10);

        $order = Order::create([
            'reference' => '#BF'.fake()->unique()->numerify('####'),
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => OrderStatus::AwaitingPayment->value,
            'payment_method' => PaymentMethod::Cash->value,
            'payment_status' => 'initiated',
            'currency' => 'XOF',
            'subtotal' => 5000,
            'delivery_fee' => 1000,
            'total' => $breakdown['total_client'],
        ]);

        OrderFinancial::create(array_merge(['order_id' => $order->id, 'discount' => 0], $breakdown));

        return $order->fresh('financials');
    }

    private function payableDriver(int $prepaidBalance = 100000): DriverProfile
    {
        return DriverProfile::factory()->create([
            'user_id' => User::factory()->create()->id,
            'status' => 'active',
            'available' => true,
            'prepaid_balance' => $prepaidBalance,
        ]);
    }

    public function test_online_orders_are_default_and_cash_marker_exists(): void
    {
        $this->assertSame('online', PaymentMethod::Online->value);
        $this->assertTrue(PaymentMethod::Cash->isCash());
        $this->assertFalse(PaymentMethod::Online->isCash());
    }

    public function test_assigning_cash_order_requires_float_coverage(): void
    {
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $order = $this->cashOrder($client, $vendor);
        $order->update(['status' => OrderStatus::Ready->value]);
        Delivery::create([
            'order_id' => $order->id,
            'vendor_id' => $vendor->id,
            'status' => 'assigned',
            'fee' => $order->delivery_fee,
            'partner_amount' => $order->financials->delivery_partner_amount,
        ]);
        $order->refresh();

        $poor = $this->payableDriver(100);
        $rich = $this->payableDriver(1000000);

        $orders = app(OrderService::class);

        try {
            $orders->assignDriver($order->fresh(), $poor->id, $poor->user_id);
            $this->fail('L\'assignation aurait dû être refusée sans flottant suffisant.');
        } catch (DomainException $e) {
            $this->assertSame('cash.insufficient_float', $e->errorCode);
        }

        $assigned = $orders->assignDriver($order->fresh(), $rich->id, $rich->user_id);
        $this->assertSame(OrderStatus::Assigned, $assigned->status);
    }

    public function test_cash_order_settles_float_and_pays_vendor_driver_on_delivery(): void
    {
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $order = $this->cashOrder($client, $vendor);
        $driver = $this->payableDriver(100000);
        $total = (int) $order->total;

        $orders = app(OrderService::class);
        $finance = app(FinanceService::class);

        $orders->acceptVendorOrder($order->fresh(), $vendor->user_id);
        $orders->markPreparing($order->fresh(), $vendor->user_id);
        $orders->markReady($order->fresh(), $vendor->user_id);

        $assigned = $orders->assignDriver($order->fresh(), $driver->id, $driver->user_id);
        $orders->markPickedUp($assigned, $driver->user_id);
        $orders->markInDelivery($assigned, $driver->user_id);

        $delivered = $orders->markDelivered($order->fresh('delivery', 'financials'), $driver->user_id);

        $this->assertSame(OrderStatus::Delivered, $delivered->status);

        // Flottant débité du total encaissé auprès du client.
        $this->assertSame(100000 - $total, (int) $driver->fresh()->prepaid_balance);

        // Part vendeur créditée en disponible.
        $this->assertSame(0, (int) $finance->walletFor($vendor)->fresh()->pending_balance);
        $this->assertSame((int) $order->financials->vendor_amount, (int) $finance->walletFor($vendor)->fresh()->available_balance);

        // Part livreur libérée en disponible.
        $this->assertSame((int) $order->financials->delivery_partner_amount, (int) $finance->walletFor($driver)->fresh()->available_balance);

        // Livraison confirmée immédiatement (pas d'attente 30 min), paiement encaissé.
        $this->assertNotNull($delivered->delivery_confirmed_at);
        $this->assertNull($delivered->auto_confirm_at);
        $this->assertSame('confirmed', $delivered->payment_status?->value);

        // Une transaction de débit de flottant est tracée.
        $this->assertSame(1, $driver->fresh()->floatTransactions()->where('type', 'debit')->where('reference_type', 'order_cash_settle')->count());
    }

    public function test_cash_settle_refuses_insufficient_float(): void
    {
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $order = $this->cashOrder($client, $vendor);
        $driver = $this->payableDriver(10);

        $order->update([
            'status' => OrderStatus::Delivered->value,
            'delivery_confirmed_at' => null,
        ]);

        try {
            app(CashService::class)->settle($order->fresh(), $driver);
            $this->fail('Le règlement aurait dû être refusé sans flottant suffisant.');
        } catch (DomainException $e) {
            $this->assertSame('cash.insufficient_float', $e->errorCode);
        }
    }

    public function test_driver_float_topup_endpoint(): void
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22995######')]);
        $user->roles()->attach(Role::where('slug', 'driver-independent')->firstOrFail(), ['is_active' => true]);
        DriverProfile::factory()->create(['user_id' => $user->id, 'status' => 'active', 'available' => true, 'prepaid_balance' => 0]);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/driver/me/float/topup', ['amount' => 5000])
            ->assertOk()
            ->assertJsonPath('data.prepaid_balance', 5000);

        $this->getJson('/api/v1/driver/me/float?for_total=3000')
            ->assertOk()
            ->assertJsonPath('data.prepaid_balance', 5000)
            ->assertJsonPath('data.coverage.covered', true);

        $this->getJson('/api/v1/driver/me/float?for_total=9000')
            ->assertJsonPath('data.coverage.covered', false);
    }
}
