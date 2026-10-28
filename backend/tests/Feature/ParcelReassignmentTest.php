<?php

namespace Tests\Feature;

use App\Models\DriverProfile;
use App\Models\Parcel;
use App\Models\ParcelAssignment;
use App\Models\Role;
use App\Models\User;
use App\Services\FinanceService;
use App\Services\ParcelService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ParcelReassignmentTest extends TestCase
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

    private function driverAt(float $latitude, float $longitude): DriverProfile
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22996######')]);
        $user->roles()->attach(Role::where('slug', 'driver-independent')->firstOrFail(), ['is_active' => true]);

        return DriverProfile::factory()->create([
            'user_id' => $user->id,
            'status' => 'active',
            'available' => true,
            'last_latitude' => $latitude,
            'last_longitude' => $longitude,
            'last_location_at' => now(),
        ]);
    }

    private function activeParcel(User $client): array
    {
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create(
            $client,
            ['label' => 'Carrefour Jericho', 'city' => 'Cotonou', 'latitude' => 6.37, 'longitude' => 2.42],
            ['label' => 'Ganhi', 'city' => 'Cotonou', 'latitude' => 6.35, 'longitude' => 2.44],
        );
        $parcels->confirmPayment($parcel->fresh(), (int) $parcel->delivery_fee);

        $oldDriver = $this->driverAt(6.36, 2.43);
        $parcels->assignDriver($parcel->fresh(), $oldDriver);
        $parcels->markPickedUp($parcel->fresh());
        $parcels->markInDelivery($parcel->fresh());

        return [$parcel->fresh(), $oldDriver];
    }

    public function test_client_reassigns_a_picked_up_parcel_with_handover_code_and_split(): void
    {
        $client = $this->client();
        [$parcel, $oldDriver] = $this->activeParcel($client);
        $newDriver = $this->driverAt(6.36, 2.43);
        $finance = app(FinanceService::class);
        $oldWallet = $finance->walletFor($oldDriver);
        $originalPending = (int) $oldWallet->pending_balance;

        $response = $this->postJson("/api/v1/parcels/{$parcel->id}/reassign", [
            'driver_profile_id' => $newDriver->id,
            'reason' => 'Livreur injoignable',
            'latitude' => 6.36,
            'longitude' => 2.43,
        ])->assertOk();

        $code = $response->json('data.handover_code');
        $this->assertIsString($code);
        $this->assertSame(6, strlen($code));

        $parcel->refresh();
        $this->assertSame($newDriver->id, $parcel->driver_profile_id);
        $this->assertSame(1, (int) $parcel->reassignment_count);
        $this->assertSame(2, ParcelAssignment::where('parcel_id', $parcel->id)->count());

        $oldAssignment = ParcelAssignment::where('parcel_id', $parcel->id)
            ->where('driver_profile_id', $oldDriver->id)
            ->firstOrFail();
        $newAssignment = ParcelAssignment::where('parcel_id', $parcel->id)
            ->where('driver_profile_id', $newDriver->id)
            ->firstOrFail();

        $this->assertSame(ParcelAssignment::STATUS_REASSIGNED, $oldAssignment->status);
        $this->assertSame(ParcelAssignment::STATUS_PENDING_HANDOVER, $newAssignment->status);
        $this->assertLessThan($originalPending, (int) $oldWallet->fresh()->pending_balance);
        $this->assertSame(0, (int) $finance->walletFor($newDriver)->pending_balance);

        Sanctum::actingAs($newDriver->user);

        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/handover", [
            'code' => $code,
        ])->assertOk();

        $newAssignment->refresh();
        $this->assertSame(ParcelAssignment::STATUS_ACTIVE, $newAssignment->status);
        $this->assertSame((int) $newAssignment->gross_amount, (int) $finance->walletFor($newDriver)->fresh()->pending_balance);

        Sanctum::actingAs($client);
        $this->getJson("/api/v1/parcels/{$parcel->id}")
            ->assertOk()
            ->assertJsonPath('data.open_incident', null);

        app(ParcelService::class)->markDelivered(
            $parcel->fresh(),
            (string) $parcel->fresh()->confirmation_code,
        );

        $this->assertSame(0, (int) $oldWallet->fresh()->pending_balance);
        $this->assertSame(0, (int) $finance->walletFor($newDriver)->fresh()->pending_balance);
        $this->assertSame((int) $oldAssignment->fresh()->partner_amount, (int) $oldWallet->fresh()->available_balance);
        $this->assertSame((int) $newAssignment->fresh()->partner_amount, (int) $finance->walletFor($newDriver)->fresh()->available_balance);
    }

    public function test_cash_parcel_reassignment_credits_both_drivers_at_delivery(): void
    {
        $client = $this->client();
        $parcels = app(ParcelService::class);
        $parcel = $parcels->create(
            $client,
            ['label' => 'Carrefour Jericho', 'city' => 'Cotonou', 'latitude' => 6.37, 'longitude' => 2.42],
            ['label' => 'Ganhi', 'city' => 'Cotonou', 'latitude' => 6.35, 'longitude' => 2.44],
            paymentMethod: 'cash',
        );

        $oldDriver = $this->driverAt(6.36, 2.43);
        $oldDriver->update(['prepaid_balance' => 1000]);
        $parcels->assignDriver($parcel->fresh(), $oldDriver);
        $parcels->markPickedUp($parcel->fresh());
        $parcels->markInDelivery($parcel->fresh());

        $newDriver = $this->driverAt(6.36, 2.43);
        $newDriver->update(['prepaid_balance' => 1000]);

        $response = $this->postJson("/api/v1/parcels/{$parcel->id}/reassign", [
            'driver_profile_id' => $newDriver->id,
            'reason' => 'Livreur injoignable',
            'latitude' => 6.36,
            'longitude' => 2.43,
        ])->assertOk();

        Sanctum::actingAs($newDriver->user);
        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/handover", [
            'code' => $response->json('data.handover_code'),
        ])->assertOk();

        app(ParcelService::class)->markDelivered(
            $parcel->fresh(),
            (string) $parcel->fresh()->confirmation_code,
        );

        $finance = app(FinanceService::class);
        $oldAssignment = ParcelAssignment::where('parcel_id', $parcel->id)
            ->where('driver_profile_id', $oldDriver->id)
            ->firstOrFail();
        $newAssignment = ParcelAssignment::where('parcel_id', $parcel->id)
            ->where('driver_profile_id', $newDriver->id)
            ->firstOrFail();

        $this->assertSame((int) $oldAssignment->partner_amount, (int) $finance->walletFor($oldDriver)->fresh()->available_balance);
        $this->assertSame((int) $newAssignment->partner_amount, (int) $finance->walletFor($newDriver)->fresh()->available_balance);
        $this->assertSame('confirmed', $parcel->fresh()->payment_status->value);
    }

    public function test_driver_incident_is_exposed_to_the_client_before_reassignment(): void
    {
        $client = $this->client();
        [$parcel, $oldDriver] = $this->activeParcel($client);

        Sanctum::actingAs($oldDriver->user);

        $this->postJson("/api/v1/driver/me/parcels/{$parcel->id}/incident", [
            'message' => 'Pneu crevé',
            'type' => 'breakdown',
        ])->assertOk();

        Sanctum::actingAs($client);

        $this->getJson("/api/v1/parcels/{$parcel->id}")
            ->assertOk()
            ->assertJsonPath('data.open_incident.message', 'Pneu crevé')
            ->assertJsonPath('data.open_incident.type', 'breakdown');
    }
}
