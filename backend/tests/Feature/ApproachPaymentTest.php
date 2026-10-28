<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Enums\PaymentPurpose;
use App\Enums\PaymentStatus;
use App\Models\Address;
use App\Models\Category;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Services\OrderService;
use App\Services\Payments\PaymentGateway;
use App\Services\PlatformPricingSettings;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Fakes\PaymentGatewayFake;
use Tests\TestCase;

class ApproachPaymentTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);

        app(PlatformPricingSettings::class)->update([
            'delivery_commission_rate' => 20,
            'approach_free_km' => 3,
            'approach_per_km' => 50,
        ]);
    }

    private function client(): User
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22997######')]);
        $user->roles()->attach(Role::where('slug', 'client')->firstOrFail(), ['is_active' => true]);

        Sanctum::actingAs($user);

        return $user;
    }

    private function paidOrderWithoutDriver(User $client, DriverProfile $driver): Order
    {
        $vendor = Vendor::factory()->create([
            'status' => 'active',
            'latitude' => 6.360,
            'longitude' => 2.420,
            'pickup_latitude' => 6.360,
            'pickup_longitude' => 2.420,
            'pickup_address' => 'Marché Dantokpa',
            'city' => 'Cotonou',
        ]);
        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'price' => 500,
            'stock_qty' => 10,
            'is_active' => true,
            'is_available' => true,
        ]);
        $address = Address::factory()->create([
            'user_id' => $client->id,
            'city' => 'Cotonou',
            'latitude' => 6.370847,
            'longitude' => 2.420,
        ]);

        $this->postJson('/api/v1/cart/items', [
            'product_id' => $product->id,
            'quantity' => 2,
        ])->assertOk();

        $this->postJson('/api/v1/orders', ['address_id' => $address->id])->assertCreated();

        $order = Order::where('user_id', $client->id)->latest()->firstOrFail();
        $order->update([
            'status' => OrderStatus::Paid->value,
            'payment_status' => PaymentStatus::Confirmed->value,
        ]);
        $order->payment?->update([
            'status' => PaymentStatus::Confirmed->value,
            'paid_at' => now(),
        ]);

        return $order->fresh(['payment', 'financials']);
    }

    private function farDriver(): DriverProfile
    {
        return DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
            'last_latitude' => 6.473045,
            'last_longitude' => 2.420,
            'last_location_at' => now(),
        ]);
    }

    public function test_online_approach_payment_is_collected_then_targets_the_driver(): void
    {
        $client = $this->client();
        $driver = $this->farDriver();
        $order = $this->paidOrderWithoutDriver($client, $driver);
        $baseTotal = (int) $order->total;

        $fake = new PaymentGatewayFake('TX-APPROACH-1', 'https://checkout.fedapay.test/TX-APPROACH-1');
        $this->app->instance(PaymentGateway::class, $fake);

        $response = $this->postJson('/api/v1/payments/approach', [
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'payment_method' => 'online',
        ])->assertOk();

        $fee = (int) $response->json('data.approach_fee');

        $this->assertGreaterThan(0, $fee);
        $this->assertSame('https://checkout.fedapay.test/TX-APPROACH-1', $response->json('data.checkout_url'));

        $order->refresh();
        $this->assertSame($baseTotal, (int) $order->total, 'Le total ne change qu\'après confirmation en ligne.');
        $this->assertSame(PaymentStatus::Initiated, $order->approach_payment_status);
        $this->assertSame($driver->id, $order->approach_driver_profile_id);

        $approachPayment = Payment::query()
            ->where('order_id', $order->id)
            ->where('purpose', PaymentPurpose::OrderApproach->value)
            ->firstOrFail();

        $this->assertSame($fee, (int) $approachPayment->amount);

        $fake->webhookEvent = [
            'event' => 'transaction.approved',
            'status' => 'success',
            'transaction_id' => 'TX-APPROACH-1',
            'type' => 'order_approach',
            'order_id' => $order->id,
            'payment_id' => $approachPayment->id,
            'amount' => $fee,
            'raw' => ['name' => 'transaction.approved'],
        ];

        $this->postJson('/api/v1/payments/webhook', ['name' => 'transaction.approved'])
            ->assertOk()
            ->assertJson(['ok' => true]);

        $order->refresh()->load(['financials', 'driverAssignmentRequest']);

        $this->assertSame(PaymentStatus::Confirmed, $order->approach_payment_status);
        $this->assertSame($baseTotal + $fee, (int) $order->total);
        $this->assertSame($fee, (int) $order->financials->approach_fee);
        $this->assertSame($driver->id, $order->preferred_driver_profile_id);
        $this->assertNotNull($order->driverAssignmentRequest);
        $this->assertSame($driver->id, $order->driverAssignmentRequest->driver_profile_id);

        $this->assertDatabaseHas('financial_transactions', [
            'order_id' => $order->id,
            'payment_id' => $approachPayment->id,
            'type' => 'approach_payment',
            'amount' => $fee,
        ]);
    }

    public function test_cash_approach_is_added_to_the_order_total_and_targets_the_driver(): void
    {
        $client = $this->client();
        $driver = $this->farDriver();
        $order = $this->paidOrderWithoutDriver($client, $driver);
        $baseTotal = (int) $order->total;

        $response = $this->postJson('/api/v1/payments/approach', [
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'payment_method' => 'cash',
        ])->assertOk();

        $fee = (int) $response->json('data.approach_fee');

        $order->refresh()->load('financials');

        $this->assertGreaterThan(0, $fee);
        $this->assertSame('cash', $response->json('data.status'));
        $this->assertSame(PaymentStatus::Pending, $order->approach_payment_status);
        $this->assertSame($baseTotal + $fee, (int) $order->total);
        $this->assertSame($fee, (int) $order->financials->approach_fee);
        $this->assertSame($driver->id, $order->preferred_driver_profile_id);
        $this->assertDatabaseMissing('payments', [
            'order_id' => $order->id,
            'purpose' => PaymentPurpose::OrderApproach->value,
        ]);
    }

    public function test_free_approach_targets_the_driver_without_payment(): void
    {
        $client = $this->client();
        $driver = DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
            'last_latitude' => 6.365,
            'last_longitude' => 2.420,
            'last_location_at' => now(),
        ]);
        $order = $this->paidOrderWithoutDriver($client, $driver);
        $baseTotal = (int) $order->total;

        $response = $this->postJson('/api/v1/payments/approach', [
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'payment_method' => 'online',
        ])->assertOk();

        $order->refresh();

        $this->assertSame('free', $response->json('data.status'));
        $this->assertSame(0, (int) $response->json('data.amount'));
        $this->assertSame(PaymentStatus::Confirmed, $order->approach_payment_status);
        $this->assertSame($baseTotal, (int) $order->total);
        $this->assertSame($driver->id, $order->preferred_driver_profile_id);
        $this->assertDatabaseMissing('payments', [
            'order_id' => $order->id,
            'purpose' => PaymentPurpose::OrderApproach->value,
        ]);
    }

    public function test_free_approach_with_cash_is_confirmed_without_payment(): void
    {
        $client = $this->client();
        $driver = DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
            'last_latitude' => 6.365,
            'last_longitude' => 2.420,
            'last_location_at' => now(),
        ]);
        $order = $this->paidOrderWithoutDriver($client, $driver);

        $response = $this->postJson('/api/v1/payments/approach', [
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'payment_method' => 'cash',
        ])->assertOk();

        $order->refresh();

        $this->assertSame('free', $response->json('data.status'));
        $this->assertSame(PaymentStatus::Confirmed, $order->approach_payment_status);
        $this->assertSame('cash', $order->approach_payment_method?->value);
        $this->assertSame($driver->id, $order->preferred_driver_profile_id);
        $this->assertDatabaseMissing('payments', [
            'order_id' => $order->id,
            'purpose' => PaymentPurpose::OrderApproach->value,
        ]);
    }

    public function test_paid_approach_can_target_a_replacement_driver_without_charging_again(): void
    {
        $client = $this->client();
        $driver = $this->farDriver();
        $replacement = DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
            'last_latitude' => 6.380,
            'last_longitude' => 2.420,
            'last_location_at' => now(),
        ]);
        $order = $this->paidOrderWithoutDriver($client, $driver);

        $fake = new PaymentGatewayFake('TX-REPLACE-1', 'https://checkout.fedapay.test/TX-REPLACE-1');
        $this->app->instance(PaymentGateway::class, $fake);

        $this->postJson('/api/v1/payments/approach', [
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'payment_method' => 'online',
        ])->assertOk();

        $approachPayment = Payment::query()
            ->where('order_id', $order->id)
            ->where('purpose', PaymentPurpose::OrderApproach->value)
            ->firstOrFail();

        $fake->webhookEvent = [
            'event' => 'transaction.approved',
            'status' => 'success',
            'transaction_id' => 'TX-REPLACE-1',
            'type' => 'order_approach',
            'order_id' => $order->id,
            'payment_id' => $approachPayment->id,
            'amount' => (int) $approachPayment->amount,
            'raw' => ['name' => 'transaction.approved'],
        ];

        $this->postJson('/api/v1/payments/webhook', ['name' => 'transaction.approved'])
            ->assertOk();

        $order->refresh();
        $paidTotal = (int) $order->total;

        $response = $this->postJson('/api/v1/payments/approach', [
            'order_id' => $order->id,
            'driver_profile_id' => $replacement->id,
            'payment_method' => 'cash',
        ])->assertOk();

        $order->refresh();

        $this->assertSame('already_paid', $response->json('data.status'));
        $this->assertSame(0, (int) $response->json('data.amount'));
        $this->assertSame($paidTotal, (int) $order->total);
        $this->assertSame($replacement->id, $order->approach_driver_profile_id);
        $this->assertSame($replacement->id, $order->preferred_driver_profile_id);
        $this->assertSame(1, \App\Models\DriverAssignmentRequest::query()
            ->where('assignable_type', Order::class)
            ->where('assignable_id', $order->id)
            ->where('status', 'pending')
            ->count());
    }

    public function test_pending_cash_approach_is_carried_to_a_replacement_driver(): void
    {
        $client = $this->client();
        $driver = $this->farDriver();
        $replacement = DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
            'last_latitude' => 6.380,
            'last_longitude' => 2.420,
            'last_location_at' => now(),
        ]);
        $order = $this->paidOrderWithoutDriver($client, $driver);

        $first = $this->postJson('/api/v1/payments/approach', [
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'payment_method' => 'cash',
        ])->assertOk();

        $order->refresh();
        $fee = (int) $order->approach_fee;
        $total = (int) $order->total;

        $response = $this->postJson('/api/v1/payments/approach', [
            'order_id' => $order->id,
            'driver_profile_id' => $replacement->id,
            'payment_method' => 'cash',
        ])->assertOk();

        $order->refresh();

        $this->assertSame('cash', $first->json('data.status'));
        $this->assertSame('cash', $response->json('data.status'));
        $this->assertSame($fee, (int) $response->json('data.amount'));
        $this->assertSame($fee, (int) $order->approach_fee);
        $this->assertSame($total, (int) $order->total);
        $this->assertSame(PaymentStatus::Pending, $order->approach_payment_status);
        $this->assertSame($replacement->id, $order->approach_driver_profile_id);
        $this->assertSame($replacement->id, $order->preferred_driver_profile_id);
    }

    public function test_cash_approach_on_an_online_order_is_debited_from_the_driver_float_at_delivery(): void
    {
        $client = $this->client();
        $driver = $this->farDriver();
        $driver->update(['prepaid_balance' => 100000, 'user_id' => User::factory()->create()->id]);
        $order = $this->paidOrderWithoutDriver($client, $driver);

        $this->postJson('/api/v1/payments/approach', [
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'payment_method' => 'cash',
        ])->assertOk();

        $order->refresh()->load(['financials', 'delivery']);
        $fee = (int) $order->approach_fee;
        $balanceBefore = (int) $driver->fresh()->prepaid_balance;

        $orders = app(OrderService::class);
        $orders->acceptVendorOrder($order->fresh(), $order->vendor->user_id);
        $orders->markPreparing($order->fresh(), $order->vendor->user_id);
        $orders->markReady($order->fresh(), $order->vendor->user_id);

        $assigned = $orders->assignDriver($order->fresh(), $driver->id, $driver->user_id);
        $orders->markPickedUp($assigned, $driver->user_id);
        $orders->markInDelivery($assigned, $driver->user_id);

        $order->update([
            'confirmation_code' => '123456',
            'confirmation_code_expires_at' => now()->addHour(),
        ]);

        $delivered = $orders->markDelivered($order->fresh('delivery', 'financials'), '123456', $driver->user_id);

        $this->assertSame(OrderStatus::Delivered, $delivered->status);
        $this->assertSame($balanceBefore - $fee, (int) $driver->fresh()->prepaid_balance);
        $this->assertSame(PaymentStatus::Confirmed, $delivered->fresh()->approach_payment_status);
    }
}
