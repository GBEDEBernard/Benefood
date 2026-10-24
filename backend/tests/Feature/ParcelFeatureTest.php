<?php

namespace Tests\Feature;

use App\Enums\ParcelStatus;
use App\Enums\PaymentStatus;
use App\Exceptions\DomainException;
use App\Models\DriverProfile;
use App\Models\Notification;
use App\Models\Parcel;
use App\Models\Refund;
use App\Models\Role;
use App\Models\User;
use App\Services\FinanceService;
use App\Services\ParcelPricingService;
use App\Services\ParcelService;
use App\Services\Payments\PaymentGateway;
use App\Services\RefundService;
use Database\Seeders\NotificationTemplatesSeeder;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Fakes\PaymentGatewayFake;
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

    /** Une boutique vendeuse peut elle aussi expédier des colis. */
    private function vendor(): User
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22995######')]);
        $user->roles()->attach(Role::where('slug', 'vendor')->firstOrFail(), ['is_active' => true]);

        Sanctum::actingAs($user);

        return $user;
    }

    private function driver(int $prepaidBalance = 0): DriverProfile
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22996######')]);
        $user->roles()->attach(Role::where('slug', 'driver-independent')->firstOrFail(), ['is_active' => true]);

        return DriverProfile::factory()->create([
            'user_id' => $user->id,
            'status' => 'active',
            'available' => true,
            'prepaid_balance' => $prepaidBalance,
        ]);
    }

    private function pickup(): array
    {
        return ['label' => 'Carrefour Jericho', 'city' => 'Cotonou', 'landmark' => 'Face à la pharmacie', 'latitude' => 6.37, 'longitude' => 2.42];
    }

    private function dropoff(): array
    {
        return ['label' => 'Ganhi', 'city' => 'Cotonou', 'landmark' => 'Derrière le marché', 'latitude' => 6.35, 'longitude' => 2.44];
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
        $this->assertNotNull(Parcel::query()->firstOrFail()->pricing_snapshot);
    }

    public function test_parcel_snapshots_keep_landmark(): void
    {
        $this->client();

        $this->postJson('/api/v1/parcels', [
            'pickup' => $this->pickup(),
            'dropoff' => $this->dropoff(),
        ])->assertCreated()
            ->assertJsonPath('data.pickup.landmark', 'Face à la pharmacie')
            ->assertJsonPath('data.dropoff.landmark', 'Derrière le marché');
    }

    public function test_parcel_snapshots_keep_contacts_and_driver_sees_sender(): void
    {
        $client = $this->client();

        $pickup = array_merge($this->pickup(), [
            'contact_name' => 'Awa Expéditrice',
            'contact_phone' => '+22997000001',
        ]);
        $dropoff = array_merge($this->dropoff(), [
            'contact_name' => 'Koffi Destinataire',
            'contact_phone' => '+22997000002',
        ]);

        $this->postJson('/api/v1/parcels', [
            'pickup' => $pickup,
            'dropoff' => $dropoff,
        ])->assertCreated()
            ->assertJsonPath('data.pickup.contact_name', 'Awa Expéditrice')
            ->assertJsonPath('data.pickup.contact_phone', '+22997000001')
            ->assertJsonPath('data.dropoff.contact_name', 'Koffi Destinataire')
            ->assertJsonPath('data.dropoff.contact_phone', '+22997000002');

        $parcel = Parcel::firstOrFail();
        app(ParcelService::class)->confirmPayment($parcel, (int) $parcel->delivery_fee);

        $driver = $this->driver();
        Sanctum::actingAs($driver->user);

        $offers = $this->getJson('/api/v1/driver/me/parcels/offers')->assertOk()->json('data');
        $offer = collect($offers)->firstWhere('id', $parcel->id);

        $this->assertSame($client->id, $offer['sender']['id']);
        $this->assertSame($client->name, $offer['sender']['name']);
        $this->assertSame($client->phone, $offer['sender']['phone']);
    }

    public function test_driver_starts_pickup_with_parcel_status_history(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);

        $driver = $this->driver();
        Sanctum::actingAs($driver->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")->assertOk();

        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/start-pickup")
            ->assertOk()
            ->assertJsonPath('data.status', 'en_route_pickup');

        $this->assertDatabaseHas('parcel_status_histories', [
            'parcel_id' => $parcel->id,
            'from_status' => 'assigned',
            'to_status' => 'en_route_pickup',
            'actor_type' => 'driver',
        ]);

        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/pickup")
            ->assertOk()
            ->assertJsonPath('data.status', 'picked_up');

        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/start-pickup")
            ->assertStatus(409)
            ->assertJsonPath('errors.0.code', 'parcel.invalid_transition');
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
            ->assertJsonPath('data.provider', 'fedapay')
            ->assertJsonPath('data.amount', (int) $parcel->delivery_fee)
            ->assertJsonPath('data.status', 'pending');
    }

    public function test_client_parcel_payment_returns_fedapay_checkout_url(): void
    {
        $this->app->instance(PaymentGateway::class, new PaymentGatewayFake('TX-PARCEL-CLIENT', 'https://checkout.fedapay.test/TX-PARCEL-CLIENT'));

        $client = $this->client();
        $parcel = app(ParcelService::class)->create($client, $this->pickup(), $this->dropoff());

        $this->postJson('/api/v1/payments/create', ['parcel_id' => $parcel->id])
            ->assertOk()
            ->assertJsonPath('data.provider', 'fedapay')
            ->assertJsonPath('data.checkout_url', 'https://checkout.fedapay.test/TX-PARCEL-CLIENT');

        $this->assertSame('TX-PARCEL-CLIENT', $parcel->payment->fresh()->gateway_txn_id);
    }

    public function test_vendor_parcel_payment_returns_fedapay_checkout_url(): void
    {
        $this->app->instance(PaymentGateway::class, new PaymentGatewayFake('TX-PARCEL-VENDOR', 'https://checkout.fedapay.test/TX-PARCEL-VENDOR'));

        $this->vendor();

        $this->postJson('/api/v1/parcels', [
            'pickup' => $this->pickup(),
            'dropoff' => $this->dropoff(),
            'description' => 'Colis boutique',
        ])->assertCreated();

        $parcel = Parcel::firstOrFail();

        $this->postJson('/api/v1/payments/create', ['parcel_id' => $parcel->id])
            ->assertOk()
            ->assertJsonPath('data.provider', 'fedapay')
            ->assertJsonPath('data.checkout_url', 'https://checkout.fedapay.test/TX-PARCEL-VENDOR');

        $this->assertSame('TX-PARCEL-VENDOR', $parcel->payment->fresh()->gateway_txn_id);
    }

    public function test_verify_settles_a_paid_parcel_when_webhook_is_unreachable(): void
    {
        $client = $this->client();
        $parcel = app(ParcelService::class)->create($client, $this->pickup(), $this->dropoff());
        $parcel->payment->update(['gateway_txn_id' => 'TX-PARCEL-VERIFY', 'status' => PaymentStatus::Initiated]);

        $fake = new PaymentGatewayFake;
        $fake->verifyResult = [
            'ok' => true,
            'status' => 'approved',
            'paid' => true,
            'amount' => $parcel->delivery_fee,
            'data' => ['id' => 'TX-PARCEL-VERIFY', 'status' => 'approved'],
        ];
        $this->app->instance(PaymentGateway::class, $fake);

        $this->postJson('/api/v1/payments/verify', ['transaction_id' => 'TX-PARCEL-VERIFY'])
            ->assertOk();

        $parcel->refresh();
        $this->assertSame(ParcelStatus::Paid, $parcel->status);
        $this->assertSame(PaymentStatus::Confirmed, $parcel->payment_status);
        $this->assertNotNull($parcel->payment->fresh()->paid_at);
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
        $this->assertSame(1000, (int) $wallet->fresh()->pending_balance);
        $this->assertSame(0, (int) $wallet->fresh()->available_balance);
    }

    public function test_parcel_exposes_driver_position_only_during_active_trip(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);

        $driver = $this->driver();
        $driver->update([
            'last_latitude' => 6.36,
            'last_longitude' => 2.43,
            'last_heading' => 90,
            'last_location_at' => now(),
        ]);

        Sanctum::actingAs($driver->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")
            ->assertOk()
            ->assertJsonPath('data.position.latitude', 6.36)
            ->assertJsonPath('data.position.longitude', 2.43)
            ->assertJsonPath('data.position.heading', 90)
            ->assertJsonPath('data.position.age_seconds', 0)
            ->assertJsonPath('data.position.distance_km', fn ($distance) => is_float($distance) && $distance > 0);

        Sanctum::actingAs($client);
        $this->getJson("/api/v1/parcels/{$parcel->id}")
            ->assertOk()
            ->assertJsonPath('data.position.latitude', 6.36)
            ->assertJsonPath('data.position.age_seconds', 0);

        $parcel->fresh()->forceFill([
            'status' => ParcelStatus::Delivered,
            'delivered_at' => now(),
        ])->save();

        $this->getJson("/api/v1/parcels/{$parcel->id}")
            ->assertOk()
            ->assertJsonPath('data.position', null);
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

        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/start-pickup")->assertOk()->assertJsonPath('data.status', 'en_route_pickup');
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/pickup")->assertOk()->assertJsonPath('data.status', 'picked_up');
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/start")->assertOk()->assertJsonPath('data.status', 'in_delivery');
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/deliver", ['proof_code' => (string) $parcel->fresh()->confirmation_code])->assertOk()->assertJsonPath('data.status', 'delivered');

        $wallet = app(FinanceService::class)->walletFor($driver);
        $this->assertSame(800, (int) $wallet->fresh()->available_balance);
        $this->assertNotNull($parcel->fresh()->delivered_at);
    }

    public function test_delivery_traces_gross_price_and_commission(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);
        $parcel->refresh();

        $driver = $this->driver();
        Sanctum::actingAs($driver->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")->assertOk();
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/pickup")->assertOk();
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/start")->assertOk();
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/deliver", ['proof_code' => (string) $parcel->fresh()->confirmation_code])->assertOk();

        $wallet = app(FinanceService::class)->walletFor($driver)->fresh();

        // Le solde net reste la part livreur (prix de livraison − commission).
        $this->assertSame((int) $parcel->partner_amount, (int) $wallet->available_balance);

        // La commission est tracée comme une ligne de débit dédiée.
        $this->assertDatabaseHas('wallet_transactions', [
            'wallet_id' => $wallet->id,
            'type' => 'debit',
            'reference_type' => 'driver_commission',
            'reference_id' => $parcel->id,
            'amount' => (int) $parcel->commission_amount,
        ]);

        // Le portefeuille expose le total et le nombre de commissions.
        $this->getJson('/api/v1/driver/me/wallet')
            ->assertOk()
            ->assertJsonPath('data.commission_total', (int) $parcel->commission_amount)
            ->assertJsonPath('data.commission_count', 1)
            ->assertJsonPath('data.commission_rate', 20);
    }

    public function test_cash_parcel_creates_paid_without_payment_record(): void
    {
        $this->client();

        $this->postJson('/api/v1/parcels', [
            'pickup' => $this->pickup(),
            'dropoff' => $this->dropoff(),
            'payment_method' => 'cash',
        ])
            ->assertCreated()
            ->assertJsonPath('data.payment_method', 'cash')
            ->assertJsonPath('data.status', 'paid')
            ->assertJsonPath('data.payment_status', 'pending')
            ->assertJsonPath('data.payment', null);

        $this->assertDatabaseCount('parcels', 1);
        $this->assertDatabaseCount('payments', 0);
    }

    public function test_cash_parcel_cannot_be_paid_online(): void
    {
        $client = $this->client();
        $parcel = app(ParcelService::class)->create($client, $this->pickup(), $this->dropoff(), 'Colis cash', paymentMethod: 'cash');

        $this->postJson('/api/v1/payments/create', ['parcel_id' => $parcel->id])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'payment.cash_not_online');
    }

    public function test_accepting_cash_parcel_requires_platform_float(): void
    {
        $client = $this->client();
        $parcel = app(ParcelService::class)->create($client, $this->pickup(), $this->dropoff(), 'Colis cash', paymentMethod: 'cash');

        $poor = $this->driver(0);
        Sanctum::actingAs($poor->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")
            ->assertStatus(409)
            ->assertJsonPath('errors.0.code', 'parcel.cash_insufficient_float');

        $rich = $this->driver(1000);
        Sanctum::actingAs($rich->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")
            ->assertOk()
            ->assertJsonPath('data.status', 'assigned')
            ->assertJsonPath('data.driver.id', $rich->id);

        $wallet = app(FinanceService::class)->walletFor($rich);
        $this->assertSame(0, (int) $wallet->fresh()->pending_balance);
    }

    public function test_cash_parcel_delivery_debits_platform_amount(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff(), paymentMethod: 'cash');

        $driver = $this->driver(1000);
        Sanctum::actingAs($driver->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")->assertOk();
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/pickup")->assertOk();
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/start")->assertOk();
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/deliver", ['proof_code' => (string) $parcel->fresh()->confirmation_code])->assertOk();

        $this->assertSame(1000 - (int) $parcel->platform_amount, (int) $driver->fresh()->prepaid_balance);
        $this->assertSame(1, $driver->fresh()->floatTransactions()->where('type', 'debit')->where('reference_type', 'parcel_cash_settle')->count());

        $wallet = app(FinanceService::class)->walletFor($driver);
        $this->assertSame((int) $parcel->partner_amount, (int) $wallet->fresh()->available_balance);
    }

    public function test_online_parcel_is_default_method(): void
    {
        $client = $this->client();
        $parcel = app(ParcelService::class)->create($client, $this->pickup(), $this->dropoff());

        $this->assertSame('online', $parcel->payment_method?->value);
        $this->assertFalse($parcel->isCash());
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

    public function test_online_parcel_payment_is_journalized_with_commission(): void
    {
        $client = $this->client();
        $parcel = app(ParcelService::class)->create($client, $this->pickup(), $this->dropoff());
        app(ParcelService::class)->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);
        $parcel->refresh();

        $this->assertDatabaseHas('financial_journal', [
            'entry_type' => 'payment',
            'reference_type' => 'parcel',
            'reference_id' => $parcel->id,
            'credit' => (int) $parcel->delivery_fee,
            'participant' => $client->id,
        ]);
        $this->assertDatabaseHas('financial_journal', [
            'entry_type' => 'commission',
            'reference_type' => 'parcel',
            'reference_id' => $parcel->id,
            'credit' => (int) $parcel->platform_amount,
        ]);
    }

    public function test_online_parcel_delivery_journalizes_driver_earning(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);

        $driver = $this->driver();
        $parcels->assignDriver($parcel->fresh(), $driver);
        $parcels->markPickedUp($parcel->fresh());
        $parcels->markInDelivery($parcel->fresh());
        $parcels->markDelivered($parcel->fresh(), (string) $parcel->fresh()->confirmation_code);

        $this->assertDatabaseHas('financial_journal', [
            'entry_type' => 'transfer',
            'reference_type' => 'parcel',
            'reference_id' => $parcel->id,
            'credit' => (int) $parcel->partner_amount,
            'participant' => $driver->user_id,
        ]);
    }

    public function test_cash_parcel_delivery_journalizes_commission_and_earning(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff(), paymentMethod: 'cash');

        $driver = $this->driver(1000);
        $parcels->assignDriver($parcel->fresh(), $driver);
        $parcels->markPickedUp($parcel->fresh());
        $parcels->markInDelivery($parcel->fresh());
        $parcels->markDelivered($parcel->fresh(), (string) $parcel->fresh()->confirmation_code);

        $this->assertDatabaseHas('financial_journal', [
            'entry_type' => 'commission',
            'reference_type' => 'parcel',
            'reference_id' => $parcel->id,
            'credit' => (int) $parcel->platform_amount,
        ]);
        $this->assertDatabaseHas('financial_journal', [
            'entry_type' => 'transfer',
            'reference_type' => 'parcel',
            'reference_id' => $parcel->id,
            'credit' => (int) $parcel->partner_amount,
            'participant' => $driver->user_id,
        ]);
    }

    public function test_cancelled_online_parcel_records_reversal(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);

        $driver = $this->driver();
        $parcels->assignDriver($parcel->fresh(), $driver);
        $parcels->cancel($parcel->fresh(), 'client', $client->id, 'Livraison reportée');

        $this->assertDatabaseHas('financial_journal', [
            'entry_type' => 'reversal',
            'reference_type' => 'parcel',
            'reference_id' => $parcel->id,
            'debit' => (int) $parcel->platform_amount,
        ]);
        $this->assertDatabaseHas('financial_journal', [
            'entry_type' => 'reversal',
            'reference_type' => 'parcel',
            'reference_id' => $parcel->id,
            'debit' => (int) $parcel->partner_amount,
        ]);
    }

    public function test_online_parcel_cancellation_creates_pending_refund(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);
        $parcels->cancel($parcel->fresh(), 'client', $client->id, 'Annulé');

        $this->assertDatabaseHas('refunds', [
            'parcel_id' => $parcel->id,
            'amount' => (int) $parcel->delivery_fee,
            'status' => 'pending',
        ]);
    }

    public function test_online_parcel_cancellation_auto_refunds_via_gateway(): void
    {
        config()->set('beninfood.refunds.automatic_execution', true);
        config()->set('fedapay.enabled', true);
        $this->app->instance(PaymentGateway::class, new PaymentGatewayFake);

        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);
        $parcels->cancel($parcel->fresh(), 'client', $client->id, 'Annulé');

        $refund = Refund::where('parcel_id', $parcel->id)->firstOrFail();
        $this->assertSame('executed', $refund->status->value);
        $this->assertSame('refunded', $parcel->fresh()->payment_status->value);
        $this->assertSame('refunded', $parcel->payment->fresh()->status->value);
    }

    public function test_pending_parcel_refund_can_be_executed(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);
        $parcels->cancel($parcel->fresh(), 'client', $client->id, 'Annulé');

        $refund = Refund::where('parcel_id', $parcel->id)->firstOrFail();
        app(RefundService::class)->executeParcelRefund($refund, $client->id);

        $this->assertSame('executed', $refund->fresh()->status->value);
        $this->assertSame('refunded', $parcel->fresh()->payment_status->value);
    }

    public function test_unpaid_parcel_cancellation_creates_no_refund(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->cancel($parcel->fresh(), 'client', $client->id, 'Annulé');

        $this->assertDatabaseMissing('refunds', ['parcel_id' => $parcel->id]);
    }

    public function test_vendor_can_create_list_and_pay_parcel(): void
    {
        $vendor = $this->vendor();

        $this->postJson('/api/v1/parcels', [
            'pickup' => $this->pickup(),
            'dropoff' => $this->dropoff(),
            'description' => 'Colis boutique',
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'awaiting_payment');

        $parcel = Parcel::firstOrFail();
        $this->assertSame($vendor->id, $parcel->user_id);

        $this->getJson('/api/v1/parcels')
            ->assertOk()
            ->assertJsonPath('data.0.id', $parcel->id);

        $this->getJson("/api/v1/parcels/{$parcel->id}")
            ->assertOk()
            ->assertJsonPath('data.reference', $parcel->reference);

        $this->postJson('/api/v1/payments/create', ['parcel_id' => $parcel->id])
            ->assertOk();
    }

    public function test_delivered_parcel_notifies_sender_with_parcel_template(): void
    {
        $this->seed(NotificationTemplatesSeeder::class);

        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);

        $driver = $this->driver();
        Sanctum::actingAs($driver->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/accept")->assertOk();
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/pickup")->assertOk();
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/start")->assertOk();
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/deliver", ['proof_code' => (string) $parcel->fresh()->confirmation_code])->assertOk();

        $notification = Notification::where('type', 'parcel.delivered')
            ->where('user_id', $client->id)
            ->firstOrFail();

        $this->assertSame('Colis livré', $notification->title);
        $this->assertStringContainsString($parcel->reference, $notification->body);
        $this->assertSame($parcel->id, data_get($notification->data, 'parcel_id'));
    }

    public function test_parcel_service_blocks_invalid_transitions(): void
    {
        $this->expectException(DomainException::class);

        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create($client, $this->pickup(), $this->dropoff());

        $parcels->markDelivered($parcel->fresh(), (string) $parcel->fresh()->confirmation_code);
    }
}
