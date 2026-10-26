<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\OrderFinancial;
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

class DriverMissionEarningsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);

        app(PlatformPricingSettings::class)->update([
            'service_fee_rate' => 3,
            'delivery_commission_rate' => 15,
            'gateway_fee_basis_points' => 120,
        ]);
    }

    public function test_driver_receives_the_net_share_for_dynamic_delivery_fees(): void
    {
        $driver = $this->driver();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $client = User::factory()->create();

        $fees = [500, 1000, 1306];
        $references = [];

        foreach ($fees as $index => $fee) {
            $subtotal = $index === 2 ? 400000 : 5000;
            $order = $this->order($client, $vendor, $subtotal, $fee, OrderStatus::Delivered);
            $references[$fee] = $order->reference;

            Delivery::create([
                'order_id' => $order->id,
                'vendor_id' => $vendor->id,
                'driver_profile_id' => $driver->id,
                'status' => 'delivered',
                'fee' => $fee,
                'partner_amount' => $order->financials->delivery_partner_amount,
                'delivered_at' => now(),
            ]);
        }

        $legacy = $this->order($client, $vendor, 5000, 1000, OrderStatus::Assigned);
        $references['legacy'] = $legacy->reference;

        Delivery::create([
            'order_id' => $legacy->id,
            'vendor_id' => $vendor->id,
            'driver_profile_id' => $driver->id,
            'status' => 'assigned',
            'fee' => 1000,
            'partner_amount' => 0,
        ]);

        Sanctum::actingAs($driver->user);

        $deliveries = collect(
            $this->getJson('/api/v1/driver/me/deliveries')->assertOk()->json('data')
        )->keyBy('order.reference');

        $this->assertSame(413306, $deliveries[$references[1306]]['order']['total']);
        $this->assertSame(1306, $deliveries[$references[1306]]['client_delivery_fee']);
        $this->assertSame(1110, $deliveries[$references[1306]]['driver_earnings']);
        $this->assertSame(1110, $deliveries[$references[1306]]['partner_amount']);
        $this->assertSame(425, $deliveries[$references[500]]['driver_earnings']);
        $this->assertSame(850, $deliveries[$references[1000]]['driver_earnings']);
        $this->assertSame(850, $deliveries[$references['legacy']]['driver_earnings']);

        $this->getJson('/api/v1/driver/me/stats?period=7d')
            ->assertOk()
            ->assertJsonPath('data.kpis.orders_earnings', 2385)
            ->assertJsonPath('data.kpis.earnings', 2385)
            ->assertJsonPath('data.kpis.orders_delivered', 3)
            ->assertJsonPath('data.kpis.average_per_mission', 795);
    }

    public function test_driver_wallet_is_credited_with_the_net_share_after_confirmation(): void
    {
        $driver = $this->driver();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $client = User::factory()->create();

        $order = $this->order($client, $vendor, 400000, 1306, OrderStatus::AwaitingPayment);

        app(OrderService::class)->confirmPayment($order, $order->total);

        Delivery::create([
            'order_id' => $order->id,
            'vendor_id' => $vendor->id,
            'driver_profile_id' => $driver->id,
            'status' => 'in_delivery',
            'fee' => 1306,
            'partner_amount' => $order->financials->delivery_partner_amount,
        ]);

        $finance = app(FinanceService::class);
        $finance->creditDriverForDelivery($order->fresh('financials'), $driver);

        $this->assertSame(1306, (int) $finance->walletFor($driver)->fresh()->pending_balance);

        $finance->releaseOrderFunds($order->fresh('delivery.driverProfile'));

        $wallet = $finance->walletFor($driver)->fresh();
        $this->assertSame(0, (int) $wallet->pending_balance);
        $this->assertSame(1110, (int) $wallet->available_balance);
    }

    private function driver(): DriverProfile
    {
        $user = User::factory()->create();
        $user->roles()->attach(
            Role::where('slug', 'driver-independent')->firstOrFail(),
            ['is_active' => true],
        );

        return DriverProfile::factory()->create([
            'user_id' => $user->id,
            'status' => 'active',
            'available' => true,
        ]);
    }

    private function order(
        User $client,
        Vendor $vendor,
        int $subtotal,
        int $deliveryFee,
        OrderStatus $status,
    ): Order {
        $breakdown = app(FinanceService::class)->breakdown($subtotal, $deliveryFee, 10);

        $order = Order::create([
            'reference' => 'BF-'.fake()->unique()->numerify('######'),
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => $status->value,
            'payment_status' => 'initiated',
            'currency' => 'XOF',
            'subtotal' => $subtotal,
            'delivery_fee' => $deliveryFee,
            'total' => $breakdown['total_client'],
        ]);

        OrderFinancial::create(array_merge(
            ['order_id' => $order->id, 'discount' => 0],
            $breakdown,
        ));

        return $order->fresh('financials');
    }
}
