<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\AuditLog;
use App\Models\Category;
use App\Models\CommissionRate;
use App\Models\Complaint;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\OrderFinancial;
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
            'gateway' => 'fedapay',
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
            ->assertSee('Chiffre d’affaires')
            ->assertSee('Évolution des commissions plateforme')
            ->assertSee('Commandes par statut')
            ->assertSee('Livreurs actifs')
            ->assertSee('Dernières commandes');
    }

    public function test_admin_dashboard_accepts_a_custom_date_range(): void
    {
        $this->actingAs($this->admin())
            ->get(route('admin.dashboard', ['from' => now()->startOfMonth()->toDateString(), 'to' => now()->toDateString()]))
            ->assertOk()
            ->assertSee('Chiffre d’affaires par boutique');
    }

    public function test_admin_dashboard_rejects_date_ranges_over_one_year(): void
    {
        $this->actingAs($this->admin())
            ->from(route('admin.dashboard'))
            ->get(route('admin.dashboard', ['from' => '2024-01-01', 'to' => '2026-01-01']))
            ->assertRedirect(route('admin.dashboard'))
            ->assertSessionHasErrors('to');
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
                'email' => 'issa.kora@mail.com',
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

    public function test_orders_status_filter_supports_the_in_progress_group(): void
    {
        $vendor = $this->activeVendor();
        $product = $this->product($vendor);
        $buyer = $this->client();
        $inProgress = $this->paidOrder($buyer, $vendor, $product);
        $delivered = $this->paidOrder($buyer, $vendor, $product);
        $delivered->update(['status' => OrderStatus::Delivered->value]);

        $this->actingAs($this->admin())
            ->get(route('admin.orders.index', ['status' => 'in_progress']))
            ->assertOk()
            ->assertSee($inProgress->reference)
            ->assertDontSee($delivered->reference);
    }

    public function test_order_detail_renders_delivery_support_refund_and_financial_sections(): void
    {
        $admin = $this->admin();
        $vendor = $this->activeVendor();
        $product = $this->product($vendor);
        $buyer = $this->client();
        $order = $this->paidOrder($buyer, $vendor, $product);
        $driver = DriverProfile::factory()->active()->create();

        Delivery::create([
            'order_id' => $order->id,
            'driver_profile_id' => $driver->id,
            'vendor_id' => $vendor->id,
            'status' => 'delivered',
            'fee' => 500,
            'partner_amount' => 400,
            'assigned_at' => now(),
            'picked_up_at' => now(),
            'delivered_at' => now(),
        ]);

        Complaint::create([
            'user_id' => $buyer->id,
            'order_id' => $order->id,
            'type' => 'delivery',
            'subject' => 'Retard de livraison',
            'description' => 'La commande est arrivée en retard.',
            'status' => 'open',
        ]);

        Refund::create([
            'payment_id' => $order->payment->id,
            'order_id' => $order->id,
            'amount' => 1000,
            'reason' => 'Geste commercial',
            'status' => 'executed',
            'executed_at' => now(),
            'executed_by' => $admin->id,
        ]);

        OrderFinancial::create([
            'order_id' => $order->id,
            'subtotal' => 1000,
            'delivery_fee' => 500,
            'commission_base' => 1000,
            'commission_rate' => 10,
            'commission_amount' => 100,
            'vendor_amount' => 900,
            'delivery_partner_amount' => 400,
            'platform_amount' => 100,
            'total_client' => 1500,
            'currency' => 'XOF',
        ]);

        $this->actingAs($admin)
            ->get(route('admin.orders.show', $order))
            ->assertOk()
            ->assertSee('Livraison & adresse')
            ->assertSee($driver->user->name)
            ->assertSee('Réclamations liées')
            ->assertSee('Retard de livraison')
            ->assertSee('Remboursements')
            ->assertSee('Geste commercial')
            ->assertSee('Répartition financière')
            ->assertSee('Commission plateforme');
    }

    public function test_orders_page_uses_custom_pagination_and_page_size(): void
    {
        $vendor = $this->activeVendor();
        $buyer = $this->client();

        foreach (range(1, 12) as $index) {
            Order::create([
                'user_id' => $buyer->id,
                'vendor_id' => $vendor->id,
                'reference' => 'BEN-PAGE-'.str_pad((string) $index, 2, '0', STR_PAD_LEFT),
                'status' => OrderStatus::Paid->value,
                'currency' => 'XOF',
                'subtotal' => 1000,
                'discount' => 0,
                'delivery_fee' => 0,
                'total' => 1000,
                'payment_status' => PaymentStatus::Confirmed->value,
            ]);
        }

        $this->actingAs($this->admin())
            ->get(route('admin.orders.index', ['q' => 'BEN-PAGE-', 'per_page' => 10]))
            ->assertOk()
            ->assertSeeText('Affichage de 1 à 10 sur 12 commandes')
            ->assertSeeText('Page 1 sur 2')
            ->assertSee('q=BEN-PAGE-', false)
            ->assertSee('per_page=10', false)
            ->assertSee('page=2', false);
    }

    public function test_orders_page_falls_back_to_twenty_rows_for_unsupported_page_sizes(): void
    {
        $this->actingAs($this->admin())
            ->get(route('admin.orders.index', ['per_page' => 1000]))
            ->assertOk()
            ->assertViewHas('orders', fn ($orders): bool => $orders->perPage() === 20);
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
