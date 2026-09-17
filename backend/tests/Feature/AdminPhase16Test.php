<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\AuditLog;
use App\Models\Category;
use App\Models\CommissionRate;
use App\Models\Complaint;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Product;
use App\Models\Refund;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class AdminPhase16Test extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function admin(): User
    {
        $admin = User::factory()->create(['email' => 'admin@local']);
        $admin->roles()->attach(Role::where('slug', 'admin-technique')->first()->id, ['is_active' => true]);

        return $admin;
    }

    private function client(): User
    {
        $client = User::factory()->create(['phone' => '+22997100001']);
        $client->roles()->attach(Role::where('slug', 'client')->first()->id, ['is_active' => true]);

        return $client;
    }

    private function activeVendor(): Vendor
    {
        $owner = User::factory()->create(['phone' => '+22997100002']);

        return Vendor::factory()->create(['user_id' => $owner->id, 'status' => 'active']);
    }

    private function product(Vendor $vendor): Product
    {
        return Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'name' => 'Piment frais',
            'price' => 500,
            'stock_qty' => 10,
            'is_active' => true,
            'is_available' => true,
        ]);
    }

    private function paidOrder(User $buyer, Vendor $vendor, Product $product): Order
    {
        $order = Order::create([
            'user_id' => $buyer->id,
            'vendor_id' => $vendor->id,
            'reference' => 'BEN-TEST-'.uniqid(),
            'status' => OrderStatus::Paid->value,
            'currency' => 'XOF',
            'subtotal' => 1000,
            'discount' => 0,
            'delivery_fee' => 0,
            'total' => 1000,
            'payment_status' => PaymentStatus::Confirmed->value,
        ]);

        $order->items()->create([
            'product_id' => $product->id,
            'name_snapshot' => $product->name,
            'unit_price_snapshot' => 500,
            'quantity' => 2,
            'subtotal' => 1000,
        ]);

        $order->payment()->create([
            'reference' => 'PAY-'.uniqid(),
            'gateway' => 'kkiapay',
            'amount' => 1000,
            'status' => PaymentStatus::Confirmed->value,
            'paid_at' => now(),
            'gateway_txn_id' => 'txn-'.uniqid(),
        ]);

        return $order->fresh();
    }

    // -----------------------------------------------------------------
    // J133 — Dashboard KPI
    // -----------------------------------------------------------------

    public function test_client_cannot_access_dashboard(): void
    {
        $this->actingAs($this->client())->get(route('admin.dashboard'))->assertForbidden();
    }

    public function test_admin_can_view_dashboard_with_kpis(): void
    {
        $vendor = $this->activeVendor();
        $product = $this->product($vendor);
        $this->paidOrder($this->client(), $vendor, $product);

        DriverProfile::factory()->active()->available()->create();
        Refund::create([
            'payment_id' => Payment::first()->id,
            'order_id' => Order::first()->id,
            'amount' => 500,
            'reason' => 'Test',
            'status' => 'pending',
        ]);

        $this->actingAs($this->admin())
            ->get(route('admin.dashboard'))
            ->assertOk()
            ->assertSee('Commandes aujourd’hui')
            ->assertSee('CA ce mois')
            ->assertSee('Commissions ce mois')
            ->assertSee('Livreurs en ligne');
    }

    // -----------------------------------------------------------------
    // J136 — Livreurs
    // -----------------------------------------------------------------

    public function test_admin_can_list_and_create_internal_driver(): void
    {
        $this->actingAs($this->admin());

        $this->get(route('admin.drivers.index'))->assertOk();
        $this->get(route('admin.drivers.create'))->assertOk();

        $this->from(route('admin.drivers.create'))
            ->post(route('admin.drivers.store'), [
                'name' => 'Issa Kora',
                'phone' => '+22997100003',
                'vehicle' => 'Moto',
            ])
            ->assertRedirect();

        $this->assertDatabaseHas('driver_profiles', ['type' => 'beninfood', 'status' => 'validated']);
        $this->assertDatabaseHas('users', ['name' => 'Issa Kora']);
    }

    public function test_driver_suspend_requires_reason(): void
    {
        $driver = DriverProfile::factory()->active()->create();

        $this->actingAs($this->admin())
            ->from(route('admin.drivers.show', $driver))
            ->post(route('admin.drivers.suspend', $driver), ['reason' => ''])
            ->assertSessionHasErrors('reason');

        $this->assertSame('active', $driver->fresh()->status);
    }

    public function test_admin_can_suspend_then_activate_driver(): void
    {
        $driver = DriverProfile::factory()->active()->create();

        $this->actingAs($this->admin())
            ->from(route('admin.drivers.show', $driver))
            ->post(route('admin.drivers.suspend', $driver), ['reason' => 'Comportement'])
            ->assertRedirect(route('admin.drivers.show', $driver));

        $this->assertSame('suspended', $driver->fresh()->status);

        $this->post(route('admin.drivers.activate', $driver))
            ->assertRedirect(route('admin.drivers.show', $driver));

        $this->assertSame('active', $driver->fresh()->status);
    }

    // -----------------------------------------------------------------
    // J137 — Commandes
    // -----------------------------------------------------------------

    public function test_client_cannot_access_orders_backoffice(): void
    {
        $this->actingAs($this->client())->get(route('admin.orders.index'))->assertForbidden();
    }

    public function test_admin_can_list_orders_and_cancel_with_reason(): void
    {
        $vendor = $this->activeVendor();
        $product = $this->product($vendor);
        $order = $this->paidOrder($this->client(), $vendor, $product);

        $this->actingAs($this->admin())
            ->get(route('admin.orders.index'))
            ->assertOk()
            ->assertSee($order->reference);

        $this->get(route('admin.orders.show', $order))->assertOk()->assertSee($order->reference);

        $this->from(route('admin.orders.show', $order))
            ->post(route('admin.orders.cancel', $order), ['reason' => 'Fraude détectée'])
            ->assertRedirect(route('admin.orders.show', $order));

        $this->assertSame('cancelled', $order->fresh()->status->value);
        $this->assertDatabaseHas('refunds', [
            'order_id' => $order->id,
            'status' => 'pending',
            'amount' => 1000,
        ]);
    }

    public function test_cancel_requires_reason(): void
    {
        $vendor = $this->activeVendor();
        $product = $this->product($vendor);
        $order = $this->paidOrder($this->client(), $vendor, $product);

        $this->actingAs($this->admin())
            ->from(route('admin.orders.show', $order))
            ->post(route('admin.orders.cancel', $order), ['reason' => ''])
            ->assertSessionHasErrors('reason');

        $this->assertSame('paid', $order->fresh()->status->value);
    }

    // -----------------------------------------------------------------
    // J138 — Commissions
    // -----------------------------------------------------------------

    public function test_admin_can_manage_commission_rates(): void
    {
        $admin = $this->admin();

        CommissionRate::create([
            'rate' => 10,
            'effective_from' => now()->subMonth(),
            'is_active' => true,
            'notes' => 'Taux initial',
            'created_by' => $admin->id,
        ]);

        $this->actingAs($admin)
            ->get(route('admin.commissions.index'))
            ->assertOk()
            ->assertSee('Historique des taux');

        $this->post(route('admin.commissions.store'), [
            'rate' => 12,
            'notes' => 'Nouvelle grille',
        ])->assertRedirect(route('admin.commissions.index'));

        $this->assertSame(1, CommissionRate::where('is_active', true)->count());
        $this->assertSame(12, CommissionRate::where('is_active', true)->first()->rate);
        $this->assertDatabaseHas('commission_rates', ['rate' => 10, 'is_active' => 0]);
    }

    // -----------------------------------------------------------------
    // J140 — Remboursements
    // -----------------------------------------------------------------

    public function test_admin_can_execute_pending_refund(): void
    {
        $vendor = $this->activeVendor();
        $product = $this->product($vendor);
        $order = $this->paidOrder($this->client(), $vendor, $product);
        $refund = Refund::create([
            'payment_id' => $order->payment->id,
            'order_id' => $order->id,
            'amount' => 1000,
            'reason' => 'Annulation porteuse',
            'status' => 'pending',
        ]);

        $this->actingAs($this->admin());

        $this->get(route('admin.refunds.index'))->assertOk()->assertSee($order->reference);
        $this->get(route('admin.refunds.show', $refund))->assertOk();

        $this->from(route('admin.refunds.show', $refund))
            ->post(route('admin.refunds.execute', $refund))
            ->assertRedirect(route('admin.refunds.show', $refund));

        $this->assertSame('executed', $refund->fresh()->status->value);
        $this->assertSame('refunded', $order->fresh()->status->value);
        $this->assertSame('refunded', $order->fresh()->payment->status->value);
    }

    public function test_client_cannot_access_refunds(): void
    {
        $this->actingAs($this->client())->get(route('admin.refunds.index'))->assertForbidden();
    }

    // -----------------------------------------------------------------
    // J141 — Réclamations
    // -----------------------------------------------------------------

    public function test_admin_can_process_complaint(): void
    {
        $vendor = $this->activeVendor();
        $product = $this->product($vendor);
        $order = $this->paidOrder($this->client(), $vendor, $product);
        $complaint = Complaint::create([
            'user_id' => $order->user_id,
            'order_id' => $order->id,
            'type' => 'delivery',
            'subject' => 'Retard de livraison',
            'description' => 'La commande n\'est jamais arrivée.',
            'status' => 'open',
        ]);

        $this->actingAs($this->admin());

        $this->get(route('admin.complaints.index'))->assertOk()->assertSee('Retard de livraison');
        $this->get(route('admin.complaints.show', $complaint))->assertOk();

        $this->from(route('admin.complaints.show', $complaint))
            ->post(route('admin.complaints.reply', $complaint), ['message' => 'Nous investiguons.'])
            ->assertRedirect(route('admin.complaints.show', $complaint));

        $this->post(route('admin.complaints.in-progress', $complaint))
            ->assertRedirect(route('admin.complaints.show', $complaint));

        $this->assertSame('in_progress', $complaint->fresh()->status->value);

        $this->post(route('admin.complaints.close', $complaint), ['resolution' => 'Livreur suspendu, remboursement du client.'])
            ->assertRedirect(route('admin.complaints.show', $complaint));

        $this->assertSame('closed', $complaint->fresh()->status->value);
        $this->assertDatabaseHas('complaint_messages', ['complaint_id' => $complaint->id, 'sender_type' => 'porteuse']);
    }

    // -----------------------------------------------------------------
    // J142 — Audit & rapports
    // -----------------------------------------------------------------

    public function test_admin_can_view_audit_log_and_export_csv(): void
    {
        $admin = $this->admin();

        AuditLog::create([
            'actor_type' => 'admin',
            'actor_id' => (string) $admin->id,
            'action' => 'vendor.suspend',
            'entity_type' => 'App\\Models\\Vendor',
            'entity_id' => (string) Str::uuid(),
            'changes' => ['status' => 'active', 'to' => 'suspended'],
            'ip' => '127.0.0.1',
            'created_at' => now(),
        ]);

        $this->actingAs($admin);

        $this->get(route('admin.audit.index'))->assertOk()->assertSee('vendor.suspend');

        $response = $this->get(route('admin.audit.export'));
        $response->assertOk();
        $this->assertStringContainsString('vendor.suspend', $response->streamedContent());
    }

    public function test_admin_can_open_reports_page_and_export_orders(): void
    {
        $vendor = $this->activeVendor();
        $product = $this->product($vendor);
        $order = $this->paidOrder($this->client(), $vendor, $product);

        $this->actingAs($this->admin());

        $this->get(route('admin.reports.index'))->assertOk()->assertSee('Export CSV');

        $response = $this->get(route('admin.reports.export.orders'));
        $response->assertOk();
        $this->assertStringContainsString($order->reference, $response->streamedContent());
    }

    public function test_client_cannot_access_audit(): void
    {
        $this->actingAs($this->client())->get(route('admin.audit.index'))->assertForbidden();
    }
}
