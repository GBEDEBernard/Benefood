<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Exceptions\DomainException;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Notification;
use App\Models\Order;
use App\Models\OrderFinancial;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Services\DeliveryAssignmentService;
use App\Services\DeliveryService;
use App\Services\FinanceService;
use App\Services\OrderService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DeliveryReassignmentTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    /**
     * @return array{0: User, 1: DriverProfile, 2: DriverProfile, 3: Order, 4: Delivery}
     */
    private function pickedUpOrderWithDriver(): array
    {
        $client = User::factory()->create();
        $client->roles()->attach(Role::where('slug', 'client')->firstOrFail(), ['is_active' => true]);
        $vendor = Vendor::factory()->create([
            'status' => 'active',
            'latitude' => 6.360,
            'longitude' => 2.420,
            'pickup_latitude' => 6.360,
            'pickup_longitude' => 2.420,
        ]);
        $finance = app(FinanceService::class);
        $breakdown = $finance->breakdown(0, 1000, 10, 150);

        $order = Order::create([
            'reference' => '#BF'.fake()->unique()->numerify('####'),
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => OrderStatus::PickedUp->value,
            'payment_status' => 'confirmed',
            'payment_method' => 'online',
            'currency' => 'XOF',
            'subtotal' => 0,
            'delivery_fee' => 1000,
            'approach_fee' => 150,
            'approach_distance_km' => 3.5,
            'total' => $breakdown['total_client'],
            'confirmation_code' => '123456',
            'confirmation_code_expires_at' => now()->addDay(),
            'address_snapshot' => [
                'latitude' => 6.380,
                'longitude' => 2.440,
                'full_address' => 'Cotonou',
            ],
            'delivery_rate_snapshot' => ['distance_km' => 8],
        ]);

        OrderFinancial::create(array_merge(['order_id' => $order->id, 'discount' => 0], $breakdown));

        $oldDriver = DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
            'last_latitude' => 6.360,
            'last_longitude' => 2.420,
            'last_location_at' => now(),
        ]);
        $newDriver = DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
            'last_latitude' => 6.390,
            'last_longitude' => 2.430,
            'last_location_at' => now(),
        ]);

        $delivery = Delivery::create([
            'order_id' => $order->id,
            'driver_profile_id' => $oldDriver->id,
            'vendor_id' => $vendor->id,
            'status' => 'picked_up',
            'fee' => $breakdown['delivery_total'],
            'partner_amount' => $breakdown['delivery_partner_amount'],
            'pickup_latitude' => 6.360,
            'pickup_longitude' => 2.420,
        ]);

        app(DeliveryAssignmentService::class)->start($delivery->fresh(), $oldDriver);

        return [$client, $oldDriver, $newDriver, $order->fresh('financials'), $delivery->fresh('assignments')];
    }

    public function test_reassignment_prorates_each_driver_share_and_releases_both_after_delivery(): void
    {
        [$client, $oldDriver, $newDriver, $order, $delivery] = $this->pickedUpOrderWithDriver();
        $finance = app(FinanceService::class);

        $result = app(DeliveryService::class)->reassignOrder(
            $order,
            $client,
            $newDriver,
            'Livreur en panne',
            6.370,
            2.430,
        );

        $oldAssignment = $delivery->fresh('assignments')->assignments->firstWhere('driver_profile_id', $oldDriver->id);
        $newAssignment = $result['assignment'];
        $oldWallet = $finance->walletFor($oldDriver)->fresh();
        $newWallet = $finance->walletFor($newDriver)->fresh();

        $this->assertSame(1150, (int) $oldAssignment->gross_amount + (int) $newAssignment->gross_amount);
        $this->assertSame(1000, (int) $oldAssignment->base_fee + (int) $newAssignment->base_fee);
        $this->assertSame(150, (int) $oldAssignment->approach_fee + (int) $newAssignment->approach_fee);
        $this->assertSame(920, (int) $oldAssignment->partner_amount + (int) $newAssignment->partner_amount);
        $this->assertSame(920, (int) $delivery->fresh('assignments')->partner_amount);
        $this->assertSame((int) $oldAssignment->gross_amount, (int) $oldWallet->pending_balance);
        $this->assertSame(0, (int) $newWallet->pending_balance);
        $this->assertDatabaseHas('delivery_incidents', [
            'delivery_id' => $delivery->id,
            'type' => 'reassignment',
            'message' => 'Livreur en panne',
        ]);

        $confirmed = app(DeliveryService::class)->confirmHandover(
            $delivery->fresh('assignments'),
            $newDriver,
            $result['handover_code'],
        );

        $this->assertSame('active', $confirmed->status);
        $this->assertSame((int) $newAssignment->gross_amount, (int) $finance->walletFor($newDriver)->fresh()->pending_balance);

        $finance->releaseOrderFunds($order->fresh(['financials', 'delivery.assignments']));

        $this->assertSame(0, (int) $finance->walletFor($oldDriver)->fresh()->pending_balance);
        $this->assertSame((int) $oldAssignment->partner_amount, (int) $finance->walletFor($oldDriver)->fresh()->available_balance);
        $this->assertSame(0, (int) $finance->walletFor($newDriver)->fresh()->pending_balance);
        $this->assertSame((int) $newAssignment->partner_amount, (int) $finance->walletFor($newDriver)->fresh()->available_balance);
        $this->assertSame(230, (int) $finance->platformWallet()->fresh()->available_balance);
    }

    public function test_driver_can_be_replaced_before_pickup_without_handover_code(): void
    {
        [$client, $oldDriver, $newDriver, $order, $delivery] = $this->pickedUpOrderWithDriver();
        $order->update(['status' => OrderStatus::Assigned->value]);
        $delivery->update(['status' => 'en_route_pickup']);

        $finance = app(FinanceService::class);
        $this->assertGreaterThan(0, (int) $finance->walletFor($oldDriver)->fresh()->pending_balance);

        $result = app(DeliveryService::class)->reassignOrder(
            $order->fresh(),
            $client,
            $newDriver,
            'Panne avant collecte',
        );

        $delivery->refresh();
        $this->assertSame('', $result['handover_code']);
        $this->assertSame($newDriver->id, $delivery->driver_profile_id);
        $this->assertSame('assigned', $delivery->status->value);
        $this->assertSame(1, (int) $delivery->reassignment_count);
        $this->assertSame(0, (int) $finance->walletFor($oldDriver)->fresh()->pending_balance);
        $this->assertGreaterThan(0, (int) $finance->walletFor($newDriver)->fresh()->pending_balance);
        $this->assertDatabaseHas('delivery_assignments', [
            'delivery_id' => $delivery->id,
            'driver_profile_id' => $oldDriver->id,
            'status' => 'cancelled',
        ]);
        $this->assertDatabaseHas('delivery_assignments', [
            'delivery_id' => $delivery->id,
            'driver_profile_id' => $newDriver->id,
            'status' => 'active',
        ]);
        $this->assertDatabaseHas('delivery_reassignment_requests', [
            'delivery_id' => $delivery->id,
            'old_driver_profile_id' => $oldDriver->id,
            'new_driver_profile_id' => $newDriver->id,
            'status' => 'accepted',
        ]);
    }

    public function test_open_driver_incident_is_exposed_to_the_client_before_pickup(): void
    {
        [$client, $oldDriver, , $order, $delivery] = $this->pickedUpOrderWithDriver();
        $order->update(['status' => OrderStatus::Assigned->value]);
        $delivery->update(['status' => 'en_route_pickup']);

        app(DeliveryService::class)->reportIncident($delivery->fresh(), $oldDriver, 'Panne de moto');

        Sanctum::actingAs($client);

        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.delivery.open_incident.type', 'other')
            ->assertJsonPath('data.delivery.open_incident.message', 'Panne de moto');
    }

    public function test_third_reassignment_is_rejected(): void
    {
        [$client, , $secondDriver, $order, $delivery] = $this->pickedUpOrderWithDriver();
        $service = app(DeliveryService::class);

        $thirdDriver = DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
            'last_latitude' => 6.375,
            'last_longitude' => 2.435,
            'last_location_at' => now(),
        ]);
        $fourthDriver = DriverProfile::factory()->create([
            'status' => 'active',
            'available' => true,
            'last_latitude' => 6.380,
            'last_longitude' => 2.440,
            'last_location_at' => now(),
        ]);

        $first = $service->reassignOrder($order, $client, $secondDriver, 'Premier remplacement', 6.370, 2.430);
        $service->confirmHandover($delivery->fresh('assignments'), $secondDriver, $first['handover_code']);

        $second = $service->reassignOrder(
            $order->fresh(),
            $client,
            $thirdDriver,
            'Deuxième remplacement',
            6.375,
            2.435,
        );
        $service->confirmHandover($delivery->fresh('assignments'), $thirdDriver, $second['handover_code']);

        try {
            $service->reassignOrder($order->fresh(), $client, $fourthDriver, 'Troisième remplacement', 6.380, 2.440);
            $this->fail('Un troisième remplacement doit être refusé.');
        } catch (DomainException $exception) {
            $this->assertSame('delivery.reassignment_limit', $exception->errorCode);
        }

        $this->assertSame(2, (int) $delivery->fresh()->reassignment_count);
    }

    public function test_replacement_drivers_endpoint_excludes_current_driver(): void
    {
        [$client, $oldDriver, $newDriver, $order] = $this->pickedUpOrderWithDriver();
        Sanctum::actingAs($client);

        $this->postJson("/api/v1/orders/{$order->id}/replacement-drivers", [
            'latitude' => 6.370,
            'longitude' => 2.430,
        ])
            ->assertOk()
            ->assertJsonCount(1, 'data.drivers')
            ->assertJsonPath('data.drivers.0.id', $newDriver->id)
            ->assertJsonMissing(['id' => $oldDriver->id]);
    }

    public function test_reassignment_rejects_cash_order_without_new_driver_float(): void
    {
        [$client, , $newDriver, $order] = $this->pickedUpOrderWithDriver();
        $order->update(['payment_method' => 'cash']);

        try {
            app(DeliveryService::class)->reassignOrder(
                $order->fresh(),
                $client,
                $newDriver,
                'Livreur en panne',
                6.370,
                2.430,
            );
            $this->fail('Un livreur sans flottant ne doit pas reprendre une commande cash.');
        } catch (DomainException $exception) {
            $this->assertSame('cash.insufficient_float', $exception->errorCode);
        }

        $this->assertSame(0, (int) $order->fresh()->delivery->reassignment_count);
    }

    public function test_client_cancellation_closes_delivery_assignment_and_notifies_driver(): void
    {
        [$client, $oldDriver, , $order, $delivery] = $this->pickedUpOrderWithDriver();
        $order->update([
            'status' => OrderStatus::Assigned->value,
            'payment_status' => 'pending',
        ]);
        $delivery->update(['status' => 'assigned']);

        app(OrderService::class)->cancelClientOrder($order->fresh(), $client->id, 'Changement d\'avis');

        $this->assertSame('cancelled', $delivery->fresh()->status->value);
        $this->assertDatabaseHas('delivery_assignments', [
            'delivery_id' => $delivery->id,
            'status' => 'cancelled',
        ]);

        $notification = Notification::query()
            ->where('user_id', $oldDriver->user_id)
            ->where('type', 'delivery.cancelled')
            ->first();

        $this->assertNotNull($notification);
        $this->assertSame($delivery->id, $notification->data['delivery_id']);
        $this->assertStringContainsString($order->reference, (string) $notification->body);
    }
}
