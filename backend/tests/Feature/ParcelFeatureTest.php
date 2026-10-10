<?php

namespace Tests\Feature;

use App\Enums\ParcelStatus;
use App\Enums\PaymentStatus;
use App\Exceptions\DomainException;
use App\Models\DriverProfile;
use App\Models\Role;
use App\Models\User;
use App\Services\FinanceService;
use App\Services\ParcelPricingService;
use App\Services\ParcelService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ParcelFeatureTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function client(): User
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22997######')]);
        $user->roles()->attach(Role::where('slug', 'client')->firstOrFail(), ['is_active' => true]);

        Sanctum::actingAs($user);

        return $user;
    }

    private function driver(): DriverProfile
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22996######')]);
        $user->roles()->attach(Role::where('slug', 'driver-independent')->firstOrFail(), ['is_active' => true]);

        return DriverProfile::factory()->create(['user_id' => $user->id, 'status' => 'active', 'available' => true]);
    }

    private function pickup(): array
    {
        return ['label' => 'Carrefour Jericho', 'city' => 'Cotonou', 'latitude' => 6.37, 'longitude' => 2.42];
    }

    private function dropoff(): array
    {
        return ['label' => 'Ganhi', 'city' => 'Cotonou', 'latitude' => 6.35, 'longitude' => 2.44];
    }

    public function test_pricing_tiers_by_distance(): void
    {
        $pricing = app(ParcelPricingService::class);

        $this->assertSame(500, $pricing->feeForDistance(2.0));
        $this->assertSame(1000, $pricing->feeForDistance(5.0));
        $this->assertSame(2000, $pricing->feeForDistance(10.0));

        $breakdown = $pricing->quote(5.0);
        $this->assertSame(1000, $breakdown['delivery_fee']);
        $this->assertSame(800, $breakdown['partner_amount']);
        $this->assertSame(200, $breakdown['platform_amount']);
        $this->assertSame(800 + 200, $breakdown['delivery_fee']);
    }

    public function test_client_creates_parcel_awaiting_payment(): void
    {
        $this->client();

        $this->postJson('/api/v1/parcels', [
            'pickup' => $this->pickup(),
            'dropoff' => $this->dropoff(),
            'description' => 'Documents A4',
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'awaiting_payment')
            ->assertJsonPath('data.payment_status', 'initiated')
            ->assertJsonPath('data.partner_amount', 800)
            ->assertJsonPath('data.platform_amount', 200)
            ->assertJsonPath('data.payment.id', fn ($id) => $id !== null);

        $this->assertDatabaseCount('parcels', 1);
        $this->assertDatabaseCount('payments', 1);
    }

    public function test_webhook_confirms_parcel_payment(): void
    {
        $client = $this->client();

        $parcel = app(ParcelService::class)->create($client, $this->pickup(), $this->dropoff(), 'Colis test');

        $this->postJson('/api/v1/payments/webhook', [
            'event' => 'success',
            'data' => [
                'transaction' => [
                    'id' => 'tx-parcel-'.fake()->numerify('####'),
                    'status' => 'success',
                    'amount' => (int) $parcel->delivery_fee,
                    'metadata' => ['type' => 'parcel', 'parcel_id' => $parcel->id],
                ],
            ],
        ])->assertOk()->assertJson(['ok' => true]);

        $parcel->refresh();

        $this->assertSame(ParcelStatus::Paid, $parcel->status);
        $this->assertSame(PaymentStatus::Confirmed, $parcel->payment_status);
        $this->assertSame(PaymentStatus::Confirmed, $parcel->payment->status);
    }

    public function test_client_can_request_payment_for_parcel(): void
    {
        $client = $this->client();
        $parcel = app(ParcelService::class)->create($client, $this->pickup(), $this->dropoff());

        $this->postJson('/api/v1/payments/create', ['parcel_id' => $parcel->id])
            ->assertOk()
            ->assertJsonPath('data.widget.order_id', $parcel->id);
    }

    public function test_driver_accept_assigns_and_credits_pending(): void
    {
        $client = $this->client();
        $parcel = app(ParcelService::class)->create($client, $this->pickup(), $this->dropoff());
        app(ParcelService::class)->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);

        $driver = $this->driver();
        Sanctum::actingAs($driver->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")
            ->assertOk()
            ->assertJsonPath('data.status', 'assigned')
            ->assertJsonPath('data.driver.id', $driver->id);

        $wallet = app(FinanceService::class)->walletFor($driver);
        $this->assertSame(800, (int) $wallet->fresh()->pending_balance);
        $this->assertSame(0, (int) $wallet->fresh()->available_balance);
    }

    public function test_driver_delivery_flow_releases_funds(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);

        $driver = $this->driver();
        Sanctum::actingAs($driver->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")->assertOk();

        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/pickup")->assertOk()->assertJsonPath('data.status', 'picked_up');
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/start")->assertOk()->assertJsonPath('data.status', 'in_delivery');
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/deliver")->assertOk()->assertJsonPath('data.status', 'delivered');

        $wallet = app(FinanceService::class)->walletFor($driver);
        $this->assertSame(800, (int) $wallet->fresh()->available_balance);
        $this->assertNotNull($parcel->fresh()->delivered_at);
    }

    public function test_cancel_paid_and_assigned_parcel_reverses_pending(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);

        $driver = $this->driver();
        Sanctum::actingAs($driver->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")->assertOk();

        Sanctum::actingAs($client);
        $this->postJson("/api/v1/parcels/{$parcel->id}/cancel", ['reason' => 'Livraison reportée'])
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');

        $wallet = app(FinanceService::class)->walletFor($driver);
        $this->assertSame(0, (int) $wallet->fresh()->pending_balance);
    }

    public function test_parcel_service_blocks_invalid_transitions(): void
    {
        $this->expectException(DomainException::class);

        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());

        $parcels->markDelivered($parcel->fresh());
    }
}
