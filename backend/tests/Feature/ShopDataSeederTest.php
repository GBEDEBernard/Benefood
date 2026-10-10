<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Models\Favorite;
use App\Models\Order;
use App\Models\Review;
use App\Models\ReviewItem;
use App\Models\User;
use App\Models\Vendor;
use Database\Seeders\AdminDashboardSeeder;
use Database\Seeders\CategoriesSeeder;
use Database\Seeders\CommissionRatesSeeder;
use Database\Seeders\DeliveryZonesSeeder;
use Database\Seeders\NotificationTemplatesSeeder;
use Database\Seeders\RolesAndPermissionsSeeder;
use Database\Seeders\ShopDataSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ShopDataSeederTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed([
            RolesAndPermissionsSeeder::class,
            CommissionRatesSeeder::class,
            DeliveryZonesSeeder::class,
            CategoriesSeeder::class,
            NotificationTemplatesSeeder::class,
            AdminDashboardSeeder::class,
        ]);

        Storage::fake('private');
        Storage::fake('public');
    }

    public function test_seeder_creates_edna_shop_clients_orders_reviews_and_favorites(): void
    {
        $this->seed(ShopDataSeeder::class);

        $marion = User::where('email', 'marion@shop.demo')->firstOrFail();
        $ednaUser = User::where('email', 'edna@shop.demo')->firstOrFail();
        $edna = Vendor::where('user_id', $ednaUser->id)->firstOrFail();

        // Boutique d'Edna : une dizaine de produits commandables.
        $this->assertGreaterThanOrEqual(10, $edna->products()->count());

        // Marion a bien commandé chez Edna (plusieurs commandes livrées).
        $marionOrders = Order::query()
            ->where('user_id', $marion->id)
            ->where('vendor_id', $edna->id)
            ->get();
        $this->assertGreaterThanOrEqual(4, $marionOrders->count());

        $deliveredEdna = Order::query()
            ->where('vendor_id', $edna->id)
            ->where('status', OrderStatus::Delivered->value)
            ->get();
        $this->assertCount(4, $deliveredEdna);

        // Avis clients sur chaque commande livrée, liés aux produits commandés.
        $reviews = Review::query()
            ->whereIn('order_id', $deliveredEdna->pluck('id'))
            ->get();
        $this->assertCount(4, $reviews);
        $this->assertGreaterThanOrEqual(1, ReviewItem::count());

        // Favoris des clients sur les produits d'Edna (3 chacun).
        $this->assertDatabaseCount('favorites', 9);
        $this->assertCount(9, Favorite::whereIn('product_id', $edna->products()->pluck('id'))->get());

        // Re-exécution : la purge nettoie puis recrée (idempotent). Les
        // modèles d'avant reset sont périmés (nouvelles clés) → on les re-lect.
        $this->seed(ShopDataSeeder::class);
        $this->assertDatabaseCount('favorites', 9);

        $ednaUser = User::where('email', 'edna@shop.demo')->firstOrFail();
        $edna = Vendor::where('user_id', $ednaUser->id)->firstOrFail();
        $this->assertCount(4, Order::query()
            ->where('vendor_id', $edna->id)
            ->where('status', OrderStatus::Delivered->value)
            ->get());

        $afterReset = Review::query()
            ->whereIn('order_id', Order::query()
                ->where('vendor_id', $edna->id)
                ->where('status', OrderStatus::Delivered->value)
                ->pluck('id'))
            ->count();
        $this->assertSame(4, $afterReset);
    }

    public function test_products_expose_rating_reviews_and_likes_dynamically(): void
    {
        $this->seed(ShopDataSeeder::class);

        $ednaUser = User::where('email', 'edna@shop.demo')->firstOrFail();
        $edna = Vendor::where('user_id', $ednaUser->id)->firstOrFail();

        // Le vendeur voit ses produits avec les statistiques d'avis/favoris.
        Sanctum::actingAs($ednaUser);
        $response = $this->getJson('/api/v1/vendors/me/products')
            ->assertOk();

        $data = collect($response->json('data'));

        $rated = $data->filter(fn (array $p) => ($p['reviews_count'] ?? 0) > 0);
        $this->assertTrue($rated->count() > 0);

        $liked = $data->filter(fn (array $p) => ($p['likes_count'] ?? 0) > 0);
        $this->assertTrue($liked->count() > 0);

        foreach ($rated as $product) {
            // 4.0 est sérialisé en entier par json_encode.
            $this->assertTrue(
                is_int($product['rating']) || is_float($product['rating']),
                "La note du produit n'est pas numérique.",
            );
            $this->assertGreaterThanOrEqual(1, $product['rating']);
            $this->assertGreaterThanOrEqual(1, $product['reviews_count']);
        }

        // La note d'Edna est dérivée des avis (moyenne 4.5 sur 4 avis).
        $home = $this->getJson('/api/v1/home')->assertOk();
        $ednaEntry = collect($home->json('data.vendors'))
            ->first(fn (array $v) => $v['id'] === $edna->id);
        $this->assertNotNull($ednaEntry);
        $this->assertSame(4.5, $ednaEntry['rating']);
        $this->assertSame(4, $ednaEntry['reviews_count']);
    }
}
