<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\Address;
use App\Models\Category;
use App\Models\Complaint;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\Notification;
use App\Models\Order;
use App\Models\Product;
use App\Models\Refund;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Database\Seeders\NotificationTemplatesSeeder;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CancellationAndSupportTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function actingUser(string $roleSlug, array $attributes = []): User
    {
        $user = User::factory()->create(array_merge(['phone' => fake()->unique()->numerify('+22997######')], $attributes));
        $role = Role::where('slug', $roleSlug)->firstOrFail();
        $user->roles()->attach($role, ['is_active' => true]);

        Sanctum::actingAs($user);

        return $user;
    }

    private function actAs(User $user): void
    {
        Sanctum::actingAs($user);
    }

    private function deliverySetup(Vendor $vendor): DeliveryZone
    {
        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);

        return $zone;
    }

    private function activeVendor(User $owner): Vendor
    {
        return Vendor::factory()->create(['status' => 'active', 'user_id' => $owner->id]);
    }

    private function vendorProduct(Vendor $vendor, int $price = 500, ?int $stock = 10): Product
    {
        return Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'name' => 'Piment frais',
            'price' => $price,
            'stock_qty' => $stock,
            'is_active' => true,
            'is_available' => true,
        ]);
    }

    private function placeOrder(User $client): Order
    {
        $vendor = $this->activeVendor($client);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = Address::factory()->create(['user_id' => $client->id, 'city' => 'Cotonou']);

        $this->actAs($client);
        $this->postJson('/api/v1/cart/items', [
            'product_id' => $product->id,
            'quantity' => 2,
        ])->assertOk();

        $this->postJson('/api/v1/orders', ['address_id' => $address->id])
            ->assertCreated();

        return Order::where('user_id', $client->id)->latest()->first();
    }

    private function markPaid(Order $order, string $status = OrderStatus::Paid->value): Order
    {
        $order->update([
            'status' => $status,
            'payment_status' => PaymentStatus::Confirmed->value,
        ]);

        $order->payment->update([
            'status' => PaymentStatus::Confirmed->value,
            'paid_at' => now(),
            'gateway_txn_id' => 'txn-'.uniqid(),
        ]);

        return $order->fresh();
    }

    private function supportUser(string $roleSlug = 'admin-technique'): User
    {
        return $this->actingUser($roleSlug);
    }

    // ---------------------------------------------------------------
    // J117/J118 — Matrice d'annulation et motif obligatoire
    // ---------------------------------------------------------------

    public function test_client_cancel_requires_reason(): void
    {
        $client = $this->actingUser('client');
        $order = $this->placeOrder($client);

        $this->actAs($client);
        $this->postJson("/api/v1/orders/{$order->id}/cancel", [])
            ->assertStatus(422);

        $this->assertSame(OrderStatus::AwaitingPayment->value, $order->fresh()->status->value);
    }

    public function test_client_cancel_before_payment_restores_stock_without_refund(): void
    {
        $client = $this->actingUser('client');
        $order = $this->placeOrder($client);
        $product = $order->items()->first()->product;

        $this->assertSame(8, $product->fresh()->stock_qty);

        $this->actAs($client);
        $this->postJson("/api/v1/orders/{$order->id}/cancel", ['reason' => 'Plus besoin'])
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');

        $this->assertSame(OrderStatus::Cancelled->value, $order->fresh()->status->value);
        $this->assertDatabaseHas('payments', ['order_id' => $order->id, 'status' => 'cancelled']);
        $this->assertDatabaseMissing('refunds', ['order_id' => $order->id]);
        $this->assertSame(10, $product->fresh()->stock_qty);
    }

    public function test_client_cancel_after_payment_creates_pending_total_refund(): void
    {
        $client = $this->actingUser('client');
        $order = $this->placeOrder($client);
        $order = $this->markPaid($order);

        $this->actAs($client);
        $this->postJson("/api/v1/orders/{$order->id}/cancel", ['reason' => 'Rétractation dans le délai'])
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');

        $refund = Refund::where('order_id', $order->id)->first();
        $this->assertNotNull($refund);
        $this->assertSame('pending', $refund->status->value);
        $this->assertSame($order->total, $refund->amount);
        $this->assertSame($order->id, $refund->order_id);
    }

    public function test_client_cancel_during_preparation_applies_preparation_fee(): void
    {
        $client = $this->actingUser('client');
        $order = $this->placeOrder($client);
        $order = $this->markPaid($order, OrderStatus::Preparing->value);

        $this->actAs($client);
        $this->postJson("/api/v1/orders/{$order->id}/cancel", ['reason' => 'Changement de programme'])
            ->assertOk();

        $refund = Refund::where('order_id', $order->id)->first();
        $this->assertNotNull($refund);
        $preparationFee = (int) config('beninfood.cancel.preparation_fee', 1000);
        $this->assertSame($order->total - $preparationFee, $refund->amount);
    }

    public function test_client_cannot_cancel_a_delivered_order(): void
    {
        $client = $this->actingUser('client');
        $order = $this->placeOrder($client);
        $order->update(['status' => OrderStatus::Delivered->value, 'delivered_at' => now()]);

        $this->actAs($client);
        $this->postJson("/api/v1/orders/{$order->id}/cancel", ['reason' => 'Annulation'])
            ->assertStatus(404);
    }

    public function test_vendor_can_cancel_preparing_order_with_total_refund(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = Address::factory()->create(['user_id' => $client->id, 'city' => 'Cotonou']);

        $this->actAs($client);
        $this->postJson('/api/v1/cart/items', ['product_id' => $product->id, 'quantity' => 2])->assertOk();
        $this->postJson('/api/v1/orders', ['address_id' => $address->id])->assertCreated();
        $order = Order::where('user_id', $client->id)->latest()->first();
        $this->markPaid($order, OrderStatus::Preparing->value);

        $this->actAs($vendorUser);
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/cancel", ['reason' => 'Rupture de stock'])
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');

        $refund = Refund::where('order_id', $order->id)->first();
        $this->assertNotNull($refund);
        $this->assertSame($order->total, $refund->amount);
    }

    public function test_vendor_cannot_cancel_an_assigned_order(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = Address::factory()->create(['user_id' => $client->id, 'city' => 'Cotonou']);

        $this->actAs($client);
        $this->postJson('/api/v1/cart/items', ['product_id' => $product->id, 'quantity' => 2])->assertOk();
        $this->postJson('/api/v1/orders', ['address_id' => $address->id])->assertCreated();
        $order = Order::where('user_id', $client->id)->latest()->first();
        $this->markPaid($order, OrderStatus::Assigned->value);

        $this->actAs($vendorUser);
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/cancel", ['reason' => 'Annulation'])
            ->assertStatus(409)
            ->assertJsonPath('errors.0.code', 'order.cannot_cancel');
    }

    public function test_vendor_refuse_requires_reason(): void
    {
        $client = $this->actingUser('client');
        $vendorUser = $this->actingUser('vendor');
        $vendor = $this->activeVendor($vendorUser);
        $product = $this->vendorProduct($vendor);
        $this->deliverySetup($vendor);
        $address = Address::factory()->create(['user_id' => $client->id, 'city' => 'Cotonou']);

        $this->actAs($client);
        $this->postJson('/api/v1/cart/items', ['product_id' => $product->id, 'quantity' => 1])->assertOk();
        $this->postJson('/api/v1/orders', ['address_id' => $address->id])->assertCreated();
        $order = Order::where('user_id', $client->id)->latest()->first();
        $this->markPaid($order);

        $this->actAs($vendorUser);
        $this->postJson("/api/v1/vendors/me/orders/{$order->id}/refuse", [])
            ->assertStatus(422);
    }

    public function test_admin_cancels_paid_order_with_override_refund(): void
    {
        $client = $this->actingUser('client');
        $order = $this->placeOrder($client);
        $this->markPaid($order);

        $this->actingUser('admin-technique');
        $this->postJson("/api/v1/admin/orders/{$order->id}/cancel", [
            'reason' => 'Litige qualité',
            'refund_amount' => 500,
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');

        $refund = Refund::where('order_id', $order->id)->first();
        $this->assertNotNull($refund);
        $this->assertSame(500, $refund->amount);
    }

    // ---------------------------------------------------------------
    // J120/J121 — Exécution du remboursement
    // ---------------------------------------------------------------

    public function test_pending_refund_is_executed_by_admin(): void
    {
        $client = $this->actingUser('client');
        $order = $this->placeOrder($client);
        $this->markPaid($order);

        $this->actAs($client);
        $this->postJson("/api/v1/orders/{$order->id}/cancel", ['reason' => 'Double commande'])
            ->assertOk();

        $refund = Refund::where('order_id', $order->id)->firstOrFail();

        $this->actingUser('admin-technique');
        $this->postJson("/api/v1/admin/refunds/{$refund->id}/execute")
            ->assertOk()
            ->assertJsonPath('data.status', 'executed');

        $order->refresh();
        $this->assertSame(OrderStatus::Refunded->value, $order->status->value);
        $this->assertSame(PaymentStatus::Refunded->value, $order->payment_status->value);
        $this->assertSame(PaymentStatus::Refunded->value, $order->payment->fresh()->status->value);

        $this->assertDatabaseHas('financial_journal', [
            'reference_type' => 'refund',
            'reference_id' => $refund->id,
            'entry_type' => 'refund',
        ]);
        $this->assertDatabaseHas('notifications', ['type' => 'order.refunded']);
    }

    public function test_client_cannot_execute_a_refund(): void
    {
        $client = $this->actingUser('client');
        $order = $this->placeOrder($client);
        $this->markPaid($order);

        $this->actAs($client);
        $this->postJson("/api/v1/orders/{$order->id}/cancel", ['reason' => 'Annulation'])
            ->assertOk();

        $refund = Refund::where('order_id', $order->id)->firstOrFail();

        $this->actAs($client);
        $this->postJson("/api/v1/admin/refunds/{$refund->id}/execute")
            ->assertStatus(403);
    }

    // ---------------------------------------------------------------
    // J122 — Réclamations
    // ---------------------------------------------------------------

    public function test_client_can_open_complaint_with_own_order(): void
    {
        $client = $this->actingUser('client');
        $order = $this->placeOrder($client);

        $this->actAs($client);
        $this->postJson('/api/v1/complaints', [
            'order_id' => $order->id,
            'type' => 'delivery',
            'subject' => 'Colis non reçu',
            'description' => 'Le livreur n\'est jamais passé.',
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'open');

        $this->assertDatabaseHas('complaints', [
            'user_id' => $client->id,
            'order_id' => $order->id,
            'status' => 'open',
        ]);
    }

    public function test_complaint_rejects_foreign_order(): void
    {
        $client = $this->actingUser('client');
        $order = $this->placeOrder($client);

        $this->actingUser('client');

        $this->postJson('/api/v1/complaints', [
            'order_id' => $order->id,
            'type' => 'product',
            'subject' => 'Remboursement produit',
            'description' => 'Article défectueux.',
        ])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'complaint.order_forbidden');
    }

    public function test_support_can_track_and_close_complaint(): void
    {
        $client = $this->actingUser('client');
        $order = $this->placeOrder($client);

        $this->actAs($client);
        $this->postJson('/api/v1/complaints', [
            'order_id' => $order->id,
            'type' => 'payment',
            'subject' => 'Paiement prélevé deux fois',
            'description' => 'Le paiement a été débité à deux reprises.',
        ])->assertCreated();

        $complaint = Complaint::where('user_id', $client->id)->firstOrFail();

        $support = $this->supportUser();

        $this->getJson('/api/v1/admin/complaints')
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->postJson("/api/v1/admin/complaints/{$complaint->id}/mark-in-progress")
            ->assertOk()
            ->assertJsonPath('data.status', 'in_progress');

        $this->postJson("/api/v1/admin/complaints/{$complaint->id}/reply", [
            'message' => 'Nous vérifions votre paiement.',
        ])->assertCreated();

        $this->postJson("/api/v1/admin/complaints/{$complaint->id}/close", [
            'resolution' => 'Double débit constaté, remboursement initié.',
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'closed');

        $complaint->refresh();
        $this->assertSame('closed', $complaint->status->value);
        $this->assertSame($support->id, $complaint->closed_by);
        $this->assertNotNull($complaint->closed_at);

        $this->assertDatabaseHas('complaint_messages', [
            'complaint_id' => $complaint->id,
            'sender_type' => 'porteuse',
            'message' => 'Nous vérifions votre paiement.',
        ]);
    }

    public function test_closed_complaint_rejects_new_messages(): void
    {
        $client = $this->actingUser('client');
        $this->placeOrder($client);

        $this->actAs($client);
        $this->postJson('/api/v1/complaints', [
            'type' => 'other',
            'subject' => 'Réclamation diverse',
            'description' => 'Question générale.',
        ])->assertCreated();

        $complaint = Complaint::where('user_id', $client->id)->firstOrFail();

        $support = $this->supportUser();
        $this->postJson("/api/v1/admin/complaints/{$complaint->id}/close", ['resolution' => 'Classé sans suite'])
            ->assertOk();

        $this->actAs($client);
        $this->postJson("/api/v1/complaints/{$complaint->id}/messages", ['message' => 'Suite à mon message'])
            ->assertStatus(409)
            ->assertJsonPath('errors.0.code', 'complaint.closed');
    }

    // ---------------------------------------------------------------
    // J124 — Notifications applicatives
    // ---------------------------------------------------------------

    public function test_cancellation_and_refund_notifications_use_templates(): void
    {
        $this->seed(NotificationTemplatesSeeder::class);

        $client = $this->actingUser('client');
        $order = $this->placeOrder($client);
        $this->markPaid($order);

        $this->actAs($client);
        $this->postJson("/api/v1/orders/{$order->id}/cancel", ['reason' => 'Rétractation'])
            ->assertOk();

        $reference = $order->reference;

        $this->assertDatabaseHas('notifications', [
            'user_id' => $client->id,
            'type' => 'order.cancelled',
        ]);

        $notification = Notification::where('type', 'order.cancelled')->where('user_id', $client->id)->first();
        $this->assertStringContainsString($reference, $notification->body);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $client->id,
            'type' => 'order.refund_initiated',
        ]);
    }
}
