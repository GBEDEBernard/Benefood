<?php

namespace Tests\Feature;

use App\Enums\VendorStatus;
use App\Models\Category;
use App\Models\Product;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
        Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'stock_qty' => 5,
        ]);

        $this->getJson('/api/v1/home')
            ->assertOk()
            ->assertJsonCount(1, 'data.categories')
            ->assertJsonCount(1, 'data.featured_products')
            ->assertJsonPath('data.vendors.0.id', $vendor->id)
            ->assertJsonPath('data.vendors.0.is_open', true);
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

    public function test_vendor_shop_returns_products_and_hours(): void
    {
        $vendor = Vendor::factory()->create(['status' => VendorStatus::Active->value]);
        $category = Category::factory()->create();
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'stock_qty' => 5,
        ]);
        $vendor->hours()->create(['day_of_week' => 1, 'opens_at' => '08:00', 'closes_at' => '20:00']);

        $this->getJson("/api/v1/vendors/{$vendor->id}")
            ->assertOk()
            ->assertJsonPath('data.id', $vendor->id)
            ->assertJsonPath('data.is_open', true)
            ->assertJsonCount(1, 'data.products')
            ->assertJsonPath('data.products.0.id', $product->id)
            ->assertJsonPath('data.products.0.is_orderable', true)
            ->assertJsonCount(1, 'data.hours');
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
}
