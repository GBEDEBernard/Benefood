<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Enums\VendorStatus;
use App\Models\Category;
use App\Models\Favorite;
use App\Models\Order;
use App\Models\Product;
use App\Models\Review;
use App\Models\ReviewItem;
use App\Models\User;
use App\Models\Vendor;
use Carbon\Carbon;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class HomeAndShopApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_home_returns_categories_featured_products_and_vendors(): void
    {
        $vendor = Vendor::factory()->create(['status' => VendorStatus::Active->value]);
        $category = Category::factory()->create();
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'stock_qty' => 5,
        ]);
        $product->images()->create([
            'path' => 'products/demo/main.webp',
            'thumb_path' => 'products/demo/main_thumb.webp',
            'mime' => 'image/webp',
            'size' => 1024,
            'is_main' => true,
            'sort_order' => 0,
        ]);

        $response = $this->getJson('/api/v1/home')
            ->assertOk()
            ->assertJsonCount(1, 'data.categories')
            ->assertJsonCount(1, 'data.featured_products')
            ->assertJsonCount(1, 'data.featured_products.0.images')
            ->assertJsonPath('data.vendors.0.id', $vendor->id)
            ->assertJsonPath('data.vendors.0.is_open', true);

        $this->assertStringEndsWith(
            '/storage/products/demo/main.webp',
            $response->json('data.featured_products.0.image_url'),
        );
    }

    public function test_home_excludes_suspended_vendor_products(): void
    {
        $category = Category::factory()->create();
        $suspended = Vendor::factory()->create(['status' => VendorStatus::Suspended->value]);
        Product::factory()->create([
            'vendor_id' => $suspended->id,
            'category_id' => $category->id,
            'stock_qty' => 5,
        ]);

        $this->getJson('/api/v1/home')
            ->assertOk()
            ->assertJsonCount(0, 'data.featured_products')
            ->assertJsonCount(0, 'data.vendors');
    }

    public function test_home_vendors_expose_rating_category_and_prep_time(): void
    {
        $vendor = Vendor::factory()->create(['status' => VendorStatus::Active->value]);
        $category = Category::factory()->create(['name' => 'Plats locaux']);
        Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'stock_qty' => 5,
        ]);

        $client = User::factory()->create();
        foreach ([5, 4] as $index => $rating) {
            $order = Order::create([
                'reference' => 'REF-HOME-'.$index,
                'user_id' => $client->id,
                'vendor_id' => $vendor->id,
                'status' => OrderStatus::Delivered->value,
            ]);
            Review::create([
                'order_id' => $order->id,
                'user_id' => $client->id,
                'rating' => $rating,
            ]);
        }

        $this->getJson('/api/v1/home')
            ->assertOk()
            ->assertJsonPath('data.vendors.0.category', 'Plats locaux')
            ->assertJsonPath('data.vendors.0.rating', 4.5)
            ->assertJsonPath('data.vendors.0.reviews_count', 2)
            ->assertJsonPath('data.vendors.0.prep_minutes', 30);
    }

    public function test_home_vendors_without_reviews_expose_neutral_rating(): void
    {
        Vendor::factory()->create(['status' => VendorStatus::Active->value]);

        $this->getJson('/api/v1/home')
            ->assertOk()
            ->assertJsonPath('data.vendors.0.rating', null)
            ->assertJsonPath('data.vendors.0.reviews_count', 0)
            ->assertJsonPath('data.vendors.0.prep_minutes', 30);
    }

    public function test_home_ranks_best_rated_vendors_and_products_and_preserves_xof_prices(): void
    {
        $category = Category::factory()->create();
        $client = User::factory()->create();
        $lowRatedVendor = Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'approved_at' => now(),
        ]);
        $topRatedVendor = Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'approved_at' => now()->subDays(5),
        ]);

        $lowProduct = Product::factory()->create([
            'vendor_id' => $lowRatedVendor->id,
            'category_id' => $category->id,
            'price' => 2000,
            'stock_qty' => 5,
        ]);
        $topProduct = Product::factory()->create([
            'vendor_id' => $topRatedVendor->id,
            'category_id' => $category->id,
            'price' => 2500,
            'stock_qty' => 5,
        ]);

        foreach ([[$lowRatedVendor, $lowProduct, 3], [$topRatedVendor, $topProduct, 5]] as [$vendor, $product, $rating]) {
            $order = Order::create([
                'reference' => 'REF-RANK-'.$vendor->id,
                'user_id' => $client->id,
                'vendor_id' => $vendor->id,
                'status' => OrderStatus::Delivered->value,
            ]);
            $review = Review::create([
                'order_id' => $order->id,
                'user_id' => $client->id,
                'rating' => $rating,
            ]);
            ReviewItem::create(['review_id' => $review->id, 'product_id' => $product->id]);
        }

        Favorite::create(['user_id' => $client->id, 'product_id' => $topProduct->id]);

        $this->getJson('/api/v1/home')
            ->assertOk()
            ->assertJsonPath('data.vendors.0.id', $topRatedVendor->id)
            ->assertJsonPath('data.vendors.0.rating', 5)
            ->assertJsonPath('data.featured_products.0.id', $topProduct->id)
            ->assertJsonPath('data.featured_products.0.price', 2500)
            ->assertJsonPath('data.featured_products.0.reviews_count', 1)
            ->assertJsonPath('data.featured_products.0.likes_count', 1);
    }

    public function test_vendor_shop_exposes_rating_reviews_and_prep_time(): void
    {
        $vendor = Vendor::factory()->create(['status' => VendorStatus::Active->value]);
        Category::factory()->create();

        $client = User::factory()->create();
        foreach ([5, 4] as $index => $rating) {
            $order = Order::create([
                'reference' => 'REF-SHOP-'.$index,
                'user_id' => $client->id,
                'vendor_id' => $vendor->id,
                'status' => OrderStatus::Delivered->value,
            ]);
            Review::create([
                'order_id' => $order->id,
                'user_id' => $client->id,
                'rating' => $rating,
            ]);
        }

        $this->getJson("/api/v1/vendors/{$vendor->id}")
            ->assertOk()
            ->assertJsonPath('data.rating', 4.5)
            ->assertJsonPath('data.reviews_count', 2)
            ->assertJsonPath('data.max_preparation_minutes', 30);
    }

    public function test_vendor_opening_hours_handle_windows_crossing_midnight(): void
    {
        $vendor = Vendor::factory()->create(['status' => VendorStatus::Active->value]);
        $vendor->hours()->create([
            'day_of_week' => 2, // mardi (2026-10-13)
            'opens_at' => '20:00',
            'closes_at' => '01:00',
        ]);

        // Ouverte pendant la plage du soir, y compris après minuit : sans le
        // traitement « plage qui traverse minuit », 23:30 serait fermée.
        $this->assertTrue($vendor->isOpenNow(Carbon::parse('2026-10-13 20:30:00')));
        $this->assertTrue($vendor->isOpenNow(Carbon::parse('2026-10-13 23:30:00')));
        $this->assertTrue($vendor->isOpenNow(Carbon::parse('2026-10-14 00:30:00')));

        // Fermée avant l'ouverture.
        $this->assertFalse($vendor->isOpenNow(Carbon::parse('2026-10-13 19:00:00')));
    }

    public function test_vendor_shop_returns_products_and_hours(): void
    {
        $vendor = Vendor::factory()->create(['status' => VendorStatus::Active->value]);
        $category = Category::factory()->create();
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'stock_qty' => 5,
        ]);
        $now = now();
        $vendor->hours()->create([
            'day_of_week' => $now->dayOfWeek,
            'opens_at' => $now->copy()->subMinutes(30)->format('H:i'),
            'closes_at' => $now->copy()->addHours(5)->format('H:i'),
        ]);

        $this->getJson("/api/v1/vendors/{$vendor->id}")
            ->assertOk()
            ->assertJsonPath('data.id', $vendor->id)
            ->assertJsonPath('data.is_open', true)
            ->assertJsonPath('data.rating', null)
            ->assertJsonPath('data.reviews_count', 0)
            ->assertJsonCount(1, 'data.products')
            ->assertJsonPath('data.products.0.id', $product->id)
            ->assertJsonPath('data.products.0.is_orderable', true)
            ->assertJsonCount(1, 'data.hours');
    }

    public function test_vendor_shop_products_expose_images_rating_and_likes(): void
    {
        Storage::fake('public');

        $vendor = Vendor::factory()->create(['status' => VendorStatus::Active->value]);
        $category = Category::factory()->create();
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'stock_qty' => 5,
        ]);

        $product->images()->create([
            'path' => 'products/p1.jpg',
            'thumb_path' => 'products/p1-thumb.jpg',
            'mime' => 'image/jpeg',
            'size' => 1024,
            'is_main' => true,
            'sort_order' => 0,
        ]);

        $client = User::factory()->create();
        $review = Review::create([
            'user_id' => $client->id,
            'rating' => 5,
            'status' => 'new',
        ]);
        ReviewItem::create(['review_id' => $review->id, 'product_id' => $product->id]);

        $this->getJson("/api/v1/vendors/{$vendor->id}")
            ->assertOk()
            ->assertJsonCount(1, 'data.products.0.images')
            ->assertJsonPath('data.products.0.rating', 5)
            ->assertJsonPath('data.products.0.reviews_count', 1)
            ->assertJsonPath('data.products.0.likes_count', 0);
    }

    public function test_vendor_shop_hides_inactive_and_closed_vendor(): void
    {
        $suspended = Vendor::factory()->create(['status' => VendorStatus::Suspended->value]);
        $closed = Vendor::factory()->create(['status' => VendorStatus::Active->value, 'closed_at' => now()]);

        foreach ([$suspended, $closed] as $vendor) {
            $this->getJson("/api/v1/vendors/{$vendor->id}")
                ->assertStatus(404)
                ->assertJsonPath('errors.0.code', 'not_found');
        }
    }

    public function test_vendors_index_filters_by_city_and_category(): void
    {
        $category = Category::factory()->create();
        $vendor = Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'city' => 'Cotonou',
        ]);
        Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'stock_qty' => 5,
        ]);

        $this->getJson('/api/v1/vendors?city=Cotonou')
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->getJson('/api/v1/vendors?city=Parakou')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson("/api/v1/vendors?category_id={$category->id}")
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_vendors_index_filters_by_type_and_exposes_it(): void
    {
        $restaurant = Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'business_name' => 'Chez Awa',
            'type' => 'restaurant',
        ]);
        Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'business_name' => 'Primeur',
            'type' => 'boutique',
        ]);

        $this->getJson('/api/v1/vendors?type=restaurant')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $restaurant->id)
            ->assertJsonPath('data.0.type', 'restaurant');

        $this->getJson('/api/v1/vendors?type=maquis')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_vendors_index_open_filter_returns_only_open_shops(): void
    {
        // Sans horaire du jour : la boutique est considérée ouverte.
        Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'business_name' => 'Ouvert',
            'type' => 'restaurant',
        ]);

        // Horaire du jour explicitement fermé.
        $closed = Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'business_name' => 'Fermé',
            'type' => 'restaurant',
        ]);
        $closed->hours()->create([
            'day_of_week' => now()->dayOfWeek,
            'is_closed' => true,
        ]);

        $this->getJson('/api/v1/vendors?type=restaurant&open=1')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.business_name', 'Ouvert');
    }

    public function test_home_exposes_vendor_type(): void
    {
        Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'type' => 'maquis',
        ]);

        $this->getJson('/api/v1/home')
            ->assertOk()
            ->assertJsonPath('data.vendors.0.type', 'maquis');
    }
}
