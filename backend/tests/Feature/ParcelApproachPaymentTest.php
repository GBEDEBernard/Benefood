<?php

namespace Tests\Feature;

use App\Enums\PaymentPurpose;
use App\Enums\PaymentStatus;
use App\Models\DriverProfile;
use App\Models\Parcel;
use App\Models\Payment;
use App\Models\Role;
use App\Models\User;
use App\Services\ParcelService;
use App\Services\Payments\PaymentGateway;
use App\Services\PlatformPricingSettings;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Fakes\PaymentGatewayFake;
use Tests\TestCase;

class ParcelApproachPaymentTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);

        app(PlatformPricingSettings::class)->update([
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

    private function paidParcelWithoutDriver(User $client): Parcel
    {
        $service = app(ParcelService::class);

        $parcel = $service->create(
            $client,
            [
                'label' => 'Carrefour Jericho',
                'city' => 'Cotonou',
                'latitude' => 6.360,
                'longitude' => 2.420,
            ],
            [
                'label' => 'Ganhi',
                'city' => 'Cotonou',
                'latitude' => 6.370,
                'longitude' => 2.430,
            ],
            'Documents',
            null,
            'cash',
        );

        return $parcel->fresh(['payment', 'approachPayment']);
    }

    private function driverAt(float $latitude, float $longitude, string $name): DriverProfile
    {
        return DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
            'last_latitude' => $latitude,
            'last_longitude' => $longitude,
            'last_location_at' => now(),
            'vehicle' => $name,
        ]);
    }

    public function test_online_parcel_approach_is_collected_then_targets_the_driver(): void
    {
        $client = $this->client();
        $driver = $this->driverAt(6.473045, 2.420, 'Moto');
        $parcel = $this->paidParcelWithoutDriver($client);
        $baseTotal = (int) $parcel->totalAmount();

        $fake = new PaymentGatewayFake('TX-PARCEL-APPROACH-1', 'https://checkout.fedapay.test/TX-PARCEL-APPROACH-1');
        $this->app->instance(PaymentGateway::class, $fake);

        $response = $this->postJson('/api/v1/payments/approach', [
            'parcel_id' => $parcel->id,
            'driver_profile_id' => $driver->id,
            'payment_method' => 'online',
        ])->assertOk();

        $fee = (int) $response->json('data.approach_fee');

        $this->assertGreaterThan(0, $fee);
        $this->assertSame('https://checkout.fedapay.test/TX-PARCEL-APPROACH-1', $response->json('data.checkout_url'));

        $parcel->refresh();
        $this->assertSame($baseTotal, $parcel->totalAmount());
        $this->assertSame(PaymentStatus::Initiated, $parcel->approach_payment_status);
        $this->assertSame($driver->id, $parcel->approach_driver_profile_id);

        $approachPayment = Payment::query()
            ->where('parcel_id', $parcel->id)
            ->where('purpose', PaymentPurpose::ParcelApproach->value)
            ->firstOrFail();

        $this->assertSame($fee, (int) $approachPayment->amount);

        $fake->webhookEvent = [
            'event' => 'transaction.approved',
            'status' => 'success',
            'transaction_id' => 'TX-PARCEL-APPROACH-1',
            'type' => 'parcel_approach',
            'parcel_id' => $parcel->id,
            'payment_id' => $approachPayment->id,
            'amount' => $fee,
            'raw' => ['name' => 'transaction.approved'],
        ];

        $this->postJson('/api/v1/payments/webhook', ['name' => 'transaction.approved'])
            ->assertOk()
            ->assertJson(['ok' => true]);

        $parcel->refresh()->load(['driverAssignmentRequest']);

        $this->assertSame(PaymentStatus::Confirmed, $parcel->approach_payment_status);
        $this->assertSame($baseTotal + $fee, $parcel->totalAmount());
        $this->assertSame($fee, (int) $parcel->approach_fee);
        $this->assertSame($driver->id, $parcel->targeted_driver_profile_id);
        $this->assertNotNull($parcel->driverAssignmentRequest);
        $this->assertSame($driver->id, $parcel->driverAssignmentRequest->driver_profile_id);
    }

    public function test_cash_parcel_approach_is_added_to_the_total_and_targets_the_driver(): void
    {
        $client = $this->client();
        $driver = $this->driverAt(6.473045, 2.420, 'Moto');
        $parcel = $this->paidParcelWithoutDriver($client);
        $baseTotal = (int) $parcel->totalAmount();

        $response = $this->postJson('/api/v1/payments/approach', [
            'parcel_id' => $parcel->id,
            'driver_profile_id' => $driver->id,
            'payment_method' => 'cash',
        ])->assertOk();

        $fee = (int) $response->json('data.approach_fee');
        $parcel->refresh();

        $this->assertGreaterThan(0, $fee);
        $this->assertSame($baseTotal + $fee, $parcel->totalAmount());
        $this->assertSame(PaymentStatus::Pending, $parcel->approach_payment_status);
        $this->assertSame($driver->id, $parcel->approach_driver_profile_id);
        $this->assertSame($driver->id, $parcel->targeted_driver_profile_id);
    }

    public function test_free_parcel_approach_is_confirmed_without_payment(): void
    {
        $client = $this->client();
        $driver = $this->driverAt(6.361, 2.421, 'Vélo');
        $parcel = $this->paidParcelWithoutDriver($client);
        $baseTotal = (int) $parcel->totalAmount();

        $response = $this->postJson('/api/v1/payments/approach', [
            'parcel_id' => $parcel->id,
            'driver_profile_id' => $driver->id,
            'payment_method' => 'cash',
        ])->assertOk();

        $parcel->refresh();

        $this->assertSame('free', $response->json('data.status'));
        $this->assertSame(0, (int) $response->json('data.amount'));
        $this->assertSame($baseTotal, $parcel->totalAmount());
        $this->assertSame(PaymentStatus::Confirmed, $parcel->approach_payment_status);
        $this->assertSame($driver->id, $parcel->approach_driver_profile_id);
        $this->assertSame($driver->id, $parcel->targeted_driver_profile_id);
    }

    public function test_paid_parcel_approach_can_target_a_replacement_driver_without_charging_again(): void
    {
        $client = $this->client();
        $driver = $this->driverAt(6.473045, 2.420, 'Moto');
        $replacement = $this->driverAt(6.361, 2.421, 'Vélo');
        $parcel = $this->paidParcelWithoutDriver($client);

        $fake = new PaymentGatewayFake('TX-PARCEL-APPROACH-2', 'https://checkout.fedapay.test/TX-PARCEL-APPROACH-2');
        $this->app->instance(PaymentGateway::class, $fake);

        $first = $this->postJson('/api/v1/payments/approach', [
            'parcel_id' => $parcel->id,
            'driver_profile_id' => $driver->id,
            'payment_method' => 'online',
        ])->assertOk();

        $fee = (int) $first->json('data.approach_fee');
        $payment = Payment::query()
            ->where('parcel_id', $parcel->id)
            ->where('purpose', PaymentPurpose::ParcelApproach->value)
            ->firstOrFail();

        $fake->webhookEvent = [
            'event' => 'transaction.approved',
            'status' => 'success',
            'transaction_id' => 'TX-PARCEL-APPROACH-2',
            'type' => 'parcel_approach',
            'parcel_id' => $parcel->id,
            'payment_id' => $payment->id,
            'amount' => $fee,
            'raw' => ['name' => 'transaction.approved'],
        ];

        $this->postJson('/api/v1/payments/webhook', ['name' => 'transaction.approved'])->assertOk();

        $parcel->refresh();
        $total = $parcel->totalAmount();

        $response = $this->postJson('/api/v1/payments/approach', [
            'parcel_id' => $parcel->id,
            'driver_profile_id' => $replacement->id,
            'payment_method' => 'cash',
        ])->assertOk();

        $parcel->refresh();

        $this->assertSame('already_paid', $response->json('data.status'));
        $this->assertSame(0, (int) $response->json('data.amount'));
        $this->assertSame($total, $parcel->totalAmount());
        $this->assertSame($fee, (int) $parcel->approach_fee);
        $this->assertSame($replacement->id, $parcel->approach_driver_profile_id);
        $this->assertSame($replacement->id, $parcel->targeted_driver_profile_id);
    }

    public function test_parcel_approach_quote_exposes_the_supplement_for_a_favorite_driver(): void
    {
        $this->client();
        $driver = $this->driverAt(6.473045, 2.420, 'Moto');

        $response = $this->postJson('/api/v1/parcels/approach-quote', [
            'driver_profile_id' => $driver->id,
            'latitude' => 6.360,
            'longitude' => 2.420,
        ])->assertOk();

        $this->assertGreaterThan(3, (float) $response->json('data.distance_km'));
        $this->assertGreaterThan(0, (int) $response->json('data.fee'));
    }

    public function test_pending_cash_parcel_approach_is_carried_to_a_replacement_driver(): void
    {
        $client = $this->client();
        $driver = $this->driverAt(6.473045, 2.420, 'Moto');
        $replacement = $this->driverAt(6.361, 2.421, 'Vélo');
        $parcel = $this->paidParcelWithoutDriver($client);

        $this->postJson('/api/v1/payments/approach', [
            'parcel_id' => $parcel->id,
            'driver_profile_id' => $driver->id,
            'payment_method' => 'cash',
        ])->assertOk();

        $parcel->refresh();
        $fee = (int) $parcel->approach_fee;
        $total = $parcel->totalAmount();

        $response = $this->postJson('/api/v1/payments/approach', [
            'parcel_id' => $parcel->id,
            'driver_profile_id' => $replacement->id,
            'payment_method' => 'cash',
        ])->assertOk();

        $parcel->refresh();

        $this->assertSame('cash', $response->json('data.status'));
        $this->assertSame($fee, (int) $response->json('data.amount'));
        $this->assertSame($total, $parcel->totalAmount());
        $this->assertSame($fee, (int) $parcel->approach_fee);
        $this->assertSame($replacement->id, $parcel->approach_driver_profile_id);
        $this->assertSame($replacement->id, $parcel->targeted_driver_profile_id);
    }
}
