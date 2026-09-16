<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\Address;
use App\Models\Category;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\FinancialTransaction;
use App\Models\Order;
use App\Models\PaymentEvent;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PaymentApiTest extends TestCase
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

    private function createOrderWithPayment(User $client, ?string $status = null): Order
    {
        $vendor = Vendor::factory()->create(['status' => 'active', 'user_id' => $client->id]);
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'name' => 'Piment frais',
            'price' => 500,
            'stock_qty' => 10,
            'is_active' => true,
            'is_available' => true,
        ]);

        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);

        $address = Address::factory()->create(['user_id' => $client->id, 'city' => 'Cotonou']);

        $this->postJson('/api/v1/cart/items', [
            'product_id' => $product->id,
            'quantity' => 2,
        ])->assertOk();

        $this->postJson('/api/v1/orders', ['address_id' => $address->id])
            ->assertCreated();

        $order = Order::where('user_id', $client->id)->latest()->first();

        if ($status) {
            $order->update(['status' => $status]);
        }

        return $order;
    }

    // ---------------------------------------------------------------
    // J90 — Création de paiement
    // ---------------------------------------------------------------

    public function test_client_can_create_payment_for_own_awaiting_order(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);

        $this->postJson('/api/v1/payments/create', ['order_id' => $order->id])
            ->assertOk()
            ->assertJsonPath('data.provider', 'kkiapay')
            ->assertJsonStructure(['data' => ['provider' => [], 'widget' => []]]);
    }

    public function test_create_payment_rejects_other_user_order(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);

        $other = $this->actingUser('client');
        $this->postJson('/api/v1/payments/create', ['order_id' => $order->id])
            ->assertStatus(404);
    }

    public function test_create_payment_rejects_already_paid_order(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client, OrderStatus::Paid->value);

        $this->postJson('/api/v1/payments/create', ['order_id' => $order->id])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'payment.invalid_state');
    }

    public function test_create_payment_rejects_cancelled_order(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client, OrderStatus::Cancelled->value);

        $this->postJson('/api/v1/payments/create', ['order_id' => $order->id])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'payment.invalid_state');
    }

    public function test_create_payment_rejects_expired_deadline(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);
        $order->update(['payment_deadline_at' => now()->subMinutes(5)]);

        $this->postJson('/api/v1/payments/create', ['order_id' => $order->id])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'payment.expired');
    }

    // ---------------------------------------------------------------
    // J93 — Retry de paiement
    // ---------------------------------------------------------------

    public function test_client_can_retry_failed_payment(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);
        $order->payment->update(['status' => PaymentStatus::Failed]);

        $this->postJson("/api/v1/payments/orders/{$order->id}/retry")
            ->assertOk()
            ->assertJsonPath('data.provider', 'kkiapay');
    }

    public function test_client_can_retry_expired_payment_and_deadline_is_extended(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);
        $order->update(['payment_deadline_at' => now()->subMinutes(5)]);
        $order->payment->update(['status' => PaymentStatus::Expired]);

        $this->postJson("/api/v1/payments/orders/{$order->id}/retry")
            ->assertOk();

        $order->refresh();
        $this->assertTrue($order->payment_deadline_at->isFuture());
        $this->assertSame(PaymentStatus::Initiated, $order->payment->fresh()->status);
    }

    public function test_retry_rejects_confirmed_payment(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);
        $order->payment->update(['status' => PaymentStatus::Confirmed, 'paid_at' => now()]);

        $this->postJson("/api/v1/payments/orders/{$order->id}/retry")
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'payment.cannot_retry');
    }

    public function test_retry_rejects_other_user_order(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);

        $this->actingUser('client');
        $this->postJson("/api/v1/payments/orders/{$order->id}/retry")
            ->assertStatus(404);
    }

    // ---------------------------------------------------------------
    // J91 — Vérification serveur de transaction
    // ---------------------------------------------------------------

    public function test_verify_endpoint_returns_result(): void
    {
        $this->actingUser('client');

        $this->postJson('/api/v1/payments/verify', ['transaction_id' => 'fake-txn-id'])
            ->assertOk();
    }

    public function test_verify_requires_transaction_id(): void
    {
        $this->actingUser('client');

        $this->postJson('/api/v1/payments/verify', [])
            ->assertStatus(422);
    }

    // ---------------------------------------------------------------
    // J92 — Webhook idempotent et protection doublons
    // ---------------------------------------------------------------

    public function test_webhook_processes_successful_payment_and_transitions_order(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);

        $payload = [
            'event' => 'success',
            'data' => [
                'transaction' => [
                    'id' => 'txn-test-001',
                    'status' => 'successful',
                    'amount' => $order->total,
                    'currency' => 'XOF',
                    'metadata' => ['order_id' => $order->id],
                ],
            ],
        ];

        $this->postJson('/api/v1/payments/webhook', $payload)
            ->assertOk()
            ->assertJson(['ok' => true]);

        $order->refresh();

        $this->assertSame(OrderStatus::Paid->value, $order->status->value);
        $this->assertSame(PaymentStatus::Confirmed->value, $order->payment_status->value);

        $order->payment->refresh();
        $this->assertSame(PaymentStatus::Confirmed, $order->payment->status);
        $this->assertNotNull($order->payment->paid_at);
        $this->assertSame('txn-test-001', $order->payment->gateway_txn_id);

        $this->assertDatabaseHas('order_status_history', [
            'order_id' => $order->id,
            'from_status' => OrderStatus::AwaitingPayment->value,
            'to_status' => OrderStatus::Paid->value,
        ]);

        $this->assertDatabaseHas('financial_transactions', [
            'order_id' => $order->id,
            'type' => 'payment',
            'amount' => $order->total,
        ]);
    }

    public function test_webhook_is_idempotent(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);

        $payload = [
            'event' => 'success',
            'data' => [
                'transaction' => [
                    'id' => 'txn-test-002',
                    'status' => 'successful',
                    'amount' => $order->total,
                    'currency' => 'XOF',
                    'metadata' => ['order_id' => $order->id],
                ],
            ],
        ];

        $this->postJson('/api/v1/payments/webhook', $payload)->assertOk();

        $this->postJson('/api/v1/payments/webhook', $payload)->assertOk();

        $this->assertSame(1, PaymentEvent::where('provider_transaction_id', 'txn-test-002')->count());

        $this->assertSame(1, FinancialTransaction::where('order_id', $order->id)->count());
    }

    public function test_webhook_handles_failure_status(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);

        $payload = [
            'event' => 'failed',
            'data' => [
                'transaction' => [
                    'id' => 'txn-fail-001',
                    'status' => 'failed',
                    'amount' => $order->total,
                    'currency' => 'XOF',
                    'metadata' => ['order_id' => $order->id],
                ],
            ],
        ];

        $this->postJson('/api/v1/payments/webhook', $payload)
            ->assertOk();

        $order->refresh();
        $this->assertSame(PaymentStatus::Failed->value, $order->payment_status->value);
        $this->assertSame(OrderStatus::AwaitingPayment->value, $order->status->value);
    }

    public function test_webhook_rejects_missing_transaction_id(): void
    {
        $this->postJson('/api/v1/payments/webhook', ['event' => 'success', 'data' => []])
            ->assertStatus(400);
    }

    public function test_webhook_rejects_invalid_signature_when_secret_configured(): void
    {
        config(['kkiapay.webhook_secret' => 'my-secret']);

        $this->postJson('/api/v1/payments/webhook', ['event' => 'success'])
            ->assertStatus(400);
    }

    public function test_webhook_accepts_valid_signature(): void
    {
        config(['kkiapay.webhook_secret' => 'my-secret']);

        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);

        $payload = [
            'event' => 'success',
            'data' => [
                'transaction' => [
                    'id' => 'txn-sig-001',
                    'status' => 'successful',
                    'amount' => $order->total,
                    'currency' => 'XOF',
                    'metadata' => ['order_id' => $order->id],
                ],
            ],
        ];

        $signature = hash_hmac('sha256', json_encode($payload), 'my-secret');

        $this->postJson('/api/v1/payments/webhook', $payload, ['X-Kkiapay-Signature' => $signature])
            ->assertOk();
    }

    // ---------------------------------------------------------------
    // J94 — Recalcul montant côté serveur
    // ---------------------------------------------------------------

    public function test_create_payment_recalculates_amount_server_side(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);

        $this->postJson('/api/v1/payments/create', ['order_id' => $order->id])
            ->assertOk()
            ->assertJsonPath('data.widget.amount', $order->total * 100);
    }

    // ---------------------------------------------------------------
    // J95 — Confirmation liée à la commande et écritures financières
    // ---------------------------------------------------------------

    public function test_successful_webhook_creates_financial_transaction(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);

        $payload = [
            'event' => 'success',
            'data' => [
                'transaction' => [
                    'id' => 'txn-fin-001',
                    'status' => 'successful',
                    'amount' => $order->total,
                    'currency' => 'XOF',
                    'metadata' => ['order_id' => $order->id],
                ],
            ],
        ];

        $this->postJson('/api/v1/payments/webhook', $payload)->assertOk();

        $ft = FinancialTransaction::where('order_id', $order->id)->first();
        $this->assertNotNull($ft);
        $this->assertSame('payment', $ft->type);
        $this->assertSame($order->total, $ft->amount);
        $this->assertSame('XOF', $ft->currency);
        $this->assertNotNull($ft->payment_id);
    }

    // ---------------------------------------------------------------
    // J96 — Cas limites
    // ---------------------------------------------------------------

    public function test_webhook_for_unknown_order_still_stores_event(): void
    {
        $payload = [
            'event' => 'success',
            'data' => [
                'transaction' => [
                    'id' => 'txn-orphan-001',
                    'status' => 'successful',
                    'amount' => 1000,
                    'currency' => 'XOF',
                    'metadata' => ['order_id' => 'non-existent-uuid'],
                ],
            ],
        ];

        $this->postJson('/api/v1/payments/webhook', $payload)->assertOk();

        $this->assertDatabaseHas('payment_events', [
            'provider' => 'kkiapay',
            'provider_transaction_id' => 'txn-orphan-001',
        ]);
    }

    public function test_create_payment_with_invalid_order_id(): void
    {
        $this->actingUser('client');

        $this->postJson('/api/v1/payments/create', ['order_id' => 'non-existent'])
            ->assertStatus(422);
    }

    public function test_order_expires_and_cannot_be_paid_after_deadline(): void
    {
        $client = $this->actingUser('client');
        $order = $this->createOrderWithPayment($client);
        $order->update(['payment_deadline_at' => now()->subMinutes(1)]);

        $this->postJson('/api/v1/payments/create', ['order_id' => $order->id])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'payment.expired');
    }
}
