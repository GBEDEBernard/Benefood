<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\OrderFinancial;
use App\Models\OrderItem;
use App\Models\Parcel;
use App\Models\Product;
use App\Models\Review;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Services\FinanceService;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Tableaux de bord statistiques (vendeur + livreur) : agrégats de la période,
 * comparaison, séries et notes.
 */
class StatsDashboardTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_vendor_stats_aggregate_delivered_orders_and_period_comparison(): void
    {
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $client = User::factory()->create();

        $delivered = $this->order($vendor, $client, OrderStatus::Delivered, 10000);
        $delivered->update(['delivered_at' => now()->subDay()]);
        OrderItem::create([
            'order_id' => $delivered->id,
            'name_snapshot' => 'Poulet braisé',
            'unit_price_snapshot' => 5000,
            'quantity' => 2,
            'subtotal' => 10000,
        ]);
        Review::create([
            'order_id' => $delivered->id,
            'user_id' => $client->id,
            'rating' => 4,
        ]);

        $cancelled = $this->order($vendor, $client, OrderStatus::Cancelled, 3000);

        // Commande livrée sur la période précédente (comparaison).
        $previous = $this->order($vendor, $client, OrderStatus::Delivered, 5000);
        $previous->update([
            'delivered_at' => now()->subDays(40),
            'created_at' => now()->subDays(40),
        ]);

        Sanctum::actingAs($vendor->user);

        $response = $this->getJson('/api/v1/vendors/me/stats?period=7d');

        $response->assertOk()
            ->assertJsonPath('data.kpis.revenue', 10000)
            ->assertJsonPath('data.kpis.orders_delivered', 1)
            ->assertJsonPath('data.kpis.orders_total', 2)
            ->assertJsonPath('data.kpis.orders_cancelled', 1)
            ->assertJsonPath('data.kpis.items_sold', 2)
            ->assertJsonPath('data.kpis.unique_clients', 1)
            ->assertJsonPath('data.kpis.rating.average', 4)
            ->assertJsonPath('data.kpis.rating.count', 1)
            ->assertJsonPath('data.comparison.revenue_pct', 100)
            ->assertJsonPath('data.top_products.0.name', 'Poulet braisé')
            ->assertJsonPath('data.top_products.0.quantity', 2)
            ->assertJsonPath('data.period.granularity', 'day');

        $this->assertNotEmpty($response->json('data.series'));
        $this->assertNotEmpty($response->json('data.status_breakdown'));
        $this->assertSame($cancelled->status->value, 'cancelled');
    }

    public function test_vendor_top_products_merge_renamed_products_and_count_pending_orders(): void
    {
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $client = User::factory()->create();
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'name' => 'Poulet braisé',
        ]);

        // Première vente : le produit porte encore son nom d'origine.
        $first = $this->order($vendor, $client, OrderStatus::Delivered, 5000);
        $first->update(['delivered_at' => now()->subDay()]);
        OrderItem::create([
            'order_id' => $first->id,
            'product_id' => $product->id,
            'name_snapshot' => 'Poulet braisé',
            'unit_price_snapshot' => 5000,
            'quantity' => 1,
            'subtotal' => 5000,
        ]);

        // Le produit est renommé puis vendu à nouveau : une seule ligne attendue.
        $product->update(['name' => 'Poulet braisé maison']);
        $second = $this->order($vendor, $client, OrderStatus::Delivered, 5000);
        $second->update(['delivered_at' => now()->subDays(2)]);
        OrderItem::create([
            'order_id' => $second->id,
            'product_id' => $product->id,
            'name_snapshot' => 'Poulet braisé',
            'unit_price_snapshot' => 5000,
            'quantity' => 1,
            'subtotal' => 5000,
        ]);

        // Commande payée en attente de traitement (badge du footer vendeur).
        $this->order($vendor, $client, OrderStatus::Paid, 3000);

        Sanctum::actingAs($vendor->user);

        $response = $this->getJson('/api/v1/vendors/me/stats?period=30d');

        $response->assertOk()
            ->assertJsonPath('data.kpis.pending_orders', 1)
            ->assertJsonCount(1, 'data.top_products')
            ->assertJsonPath('data.top_products.0.id', $product->id)
            ->assertJsonPath('data.top_products.0.name', 'Poulet braisé maison')
            ->assertJsonPath('data.top_products.0.quantity', 2)
            ->assertJsonPath('data.top_products.0.revenue', 10000);
    }

    public function test_driver_stats_merge_orders_and_parcels_and_use_driver_rating(): void
    {
        $driver = DriverProfile::factory()->create();
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);

        $order = $this->order($vendor, $client, OrderStatus::Delivered, 8000);
        $order->update(['delivered_at' => now()->subDay()]);
        Delivery::create([
            'order_id' => $order->id,
            'vendor_id' => $vendor->id,
            'driver_profile_id' => $driver->id,
            'status' => 'delivered',
            'fee' => 1000,
            'partner_amount' => 800,
            'delivered_at' => now()->subDay(),
        ]);

        Parcel::create([
            'reference' => 'COL-0001',
            'user_id' => $client->id,
            'driver_profile_id' => $driver->id,
            'status' => 'delivered',
            'payment_status' => 'confirmed',
            'pickup_snapshot' => ['label' => 'A'],
            'dropoff_snapshot' => ['label' => 'B'],
            'distance_km' => 3.5,
            'delivery_fee' => 500,
            'commission_amount' => 100,
            'partner_amount' => 400,
            'platform_amount' => 100,
            'delivered_at' => now()->subDay(),
        ]);

        Review::create([
            'user_id' => $client->id,
            'driver_profile_id' => $driver->id,
            'rating' => 5,
            'driver_rating' => 5,
        ]);

        // Mission annulée sur la période : baisse le taux de réussite.
        $cancelledOrder = $this->order($vendor, $client, OrderStatus::Cancelled, 2000);
        Delivery::create([
            'order_id' => $cancelledOrder->id,
            'vendor_id' => $vendor->id,
            'driver_profile_id' => $driver->id,
            'status' => 'cancelled',
            'fee' => 1000,
            'partner_amount' => 0,
        ]);

        Sanctum::actingAs($driver->user);

        $response = $this->getJson('/api/v1/driver/me/stats?period=7d');

        $response->assertOk()
            ->assertJsonPath('data.kpis.earnings', 1200)
            ->assertJsonPath('data.kpis.orders_earnings', 800)
            ->assertJsonPath('data.kpis.parcels_earnings', 400)
            ->assertJsonPath('data.kpis.missions_completed', 2)
            ->assertJsonPath('data.kpis.orders_delivered', 1)
            ->assertJsonPath('data.kpis.parcels_delivered', 1)
            ->assertJsonPath('data.kpis.missions_cancelled', 1)
            ->assertJsonPath('data.kpis.completion_rate', 66.7)
            ->assertJsonPath('data.kpis.distance_km', 3.5)
            ->assertJsonPath('data.kpis.rating.average', 5)
            ->assertJsonPath('data.kpis.rating.count', 1)
            ->assertJsonPath('data.breakdown.0.type', 'orders')
            ->assertJsonPath('data.breakdown.1.type', 'parcels');

        $this->assertNotEmpty($response->json('data.series'));
        $this->assertNotEmpty($response->json('data.recent'));
        $this->assertSame(2, count($response->json('data.recent')));
    }

    public function test_driver_stats_require_a_driver_profile(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/driver/me/stats')
            ->assertNotFound()
            ->assertJsonPath('errors.0.code', 'stats.no_driver_profile');
    }

    public function test_driver_earnings_expose_day_week_month_totals_and_series(): void
    {
        $this->travelTo(Carbon::parse('2026-10-21 12:00:00'));

        $driver = DriverProfile::factory()->create();
        $driver->user->roles()->attach(
            Role::where('slug', 'driver-independent')->firstOrFail(),
            ['is_active' => true],
        );
        $client = User::factory()->create();
        $vendor = Vendor::factory()->create(['status' => 'active']);

        // Aujourd'hui, hier, plus tôt ce mois, et le mois précédent.
        $this->delivery($driver, $vendor, $client, 800, now());
        $this->delivery($driver, $vendor, $client, 400, now()->subDay());
        $this->delivery($driver, $vendor, $client, 300, now()->startOfMonth()->addDay());
        $this->delivery($driver, $vendor, $client, 900, now()->subMonthNoOverflow()->startOfMonth()->addDays(14));

        Sanctum::actingAs($driver->user);

        $response = $this->getJson('/api/v1/driver/me/earnings');

        $response->assertOk()
            ->assertJsonPath('data.currency', 'XOF')
            ->assertJsonPath('data.eur_rate', 655.957)
            ->assertJsonPath('data.periods.day.earnings', 800)
            ->assertJsonPath('data.periods.day.missions', 1)
            ->assertJsonPath('data.periods.week.earnings', 1200)
            ->assertJsonPath('data.periods.week.missions', 2)
            ->assertJsonPath('data.periods.month.earnings', 1500)
            ->assertJsonPath('data.periods.month.missions', 3)
            ->assertJsonPath('data.series.day.6.earnings', 800)
            ->assertJsonPath('data.series.day.6.current', true)
            ->assertJsonPath('data.series.month.5.earnings', 1500);

        $this->assertCount(7, $response->json('data.series.day'));
        $this->assertCount(4, $response->json('data.series.week'));
        $this->assertCount(6, $response->json('data.series.month'));
    }

    public function test_driver_earnings_require_a_driver_profile(): void
    {
        $user = User::factory()->create();
        $user->roles()->attach(
            Role::where('slug', 'driver-independent')->firstOrFail(),
            ['is_active' => true],
        );
        Sanctum::actingAs($user);

        $this->getJson('/api/v1/driver/me/earnings')
            ->assertNotFound()
            ->assertJsonPath('errors.0.code', 'stats.no_driver_profile');
    }

    private function delivery(
        DriverProfile $driver,
        Vendor $vendor,
        User $client,
        int $partnerAmount,
        Carbon $deliveredAt,
    ): Delivery {
        $order = $this->order($vendor, $client, OrderStatus::Delivered, 5000);

        return Delivery::create([
            'order_id' => $order->id,
            'vendor_id' => $vendor->id,
            'driver_profile_id' => $driver->id,
            'status' => 'delivered',
            'fee' => 1000,
            'partner_amount' => $partnerAmount,
            'delivered_at' => $deliveredAt,
        ]);
    }

    private function order(
        Vendor $vendor,
        User $client,
        OrderStatus $status,
        int $subtotal,
    ): Order {
        $breakdown = app(FinanceService::class)->breakdown($subtotal, 1000, 10);

        $order = Order::create([
            'reference' => '#BF'.fake()->unique()->numerify('#####'),
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => $status->value,
            'payment_status' => 'initiated',
            'currency' => 'XOF',
            'subtotal' => $subtotal,
            'delivery_fee' => 1000,
            'total' => $breakdown['total_client'],
        ]);

        OrderFinancial::create(array_merge(
            ['order_id' => $order->id, 'discount' => 0],
            $breakdown,
        ));

        return $order->fresh();
    }
}
