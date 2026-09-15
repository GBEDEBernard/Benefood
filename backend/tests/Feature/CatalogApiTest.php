<?php

namespace Tests\Feature;

use App\Enums\VendorStatus;
use App\Models\Category;
use App\Models\Product;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CatalogApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function activeVendor(): Vendor
    {
        return Vendor::factory()->create(['status' => VendorStatus::Active->value]);
    }

    public function test_categories_returns_active_tree_with_children(): void
    {
        $root = Category::factory()->create(['name' => 'Fruits et légumes']);
        $child = Category::factory()->create(['name' => 'Légumes frais', 'parent_id' => $root->id]);
        Category::factory()->create(['name' => 'Cachée', 'is_active' => false]);

        $this->getJson(route('api.v1.categories.index'))
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Fruits et légumes')
            ->assertJsonPath('data.0.children.0.name', 'Légumes frais')
            ->assertJsonMissing(['name' => 'Cachée']);
    }

    public function test_catalog_index_returns_only_orderable_products_from_active_vendors(): void
    {
        $vendor = $this->activeVendor();
        $category = Category::factory()->create();

        $orderable = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'stock_qty' => 5,
            'is_active' => true,
            'is_available' => true,
        ]);
        Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'name' => 'Inactif',
            'stock_qty' => 5,
            'is_active' => false,
        ]);
        Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'name' => 'Rupture',
            'stock_qty' => 0,
            'is_available' => false,
        ]);
        $suspendedVendor = Vendor::factory()->create(['status' => VendorStatus::Suspended->value]);
        Product::factory()->create([
            'vendor_id' => $suspendedVendor->id,
            'category_id' => $category->id,
            'stock_qty' => 5,
            'is_active' => true,
            'is_available' => true,
        ]);

        $this->getJson(route('api.v1.products.index'))
            ->assertOk()
            ->assertJsonPath('data.0.id', $orderable->id)
            ->assertJsonPath('data.0.is_orderable', true)
            ->assertJsonCount(1, 'data');
    }

    public function test_catalog_index_filters_recursively_by_category(): void
    {
        $vendor = $this->activeVendor();
        $root = Category::factory()->create();
        $child = Category::factory()->create(['parent_id' => $root->id]);
        $other = Category::factory()->create();

        Product::factory()->create(['vendor_id' => $vendor->id, 'category_id' => $child->id, 'stock_qty' => 3]);
        Product::factory()->create(['vendor_id' => $vendor->id, 'category_id' => $other->id, 'stock_qty' => 3]);

        $this->getJson(route('api.v1.products.index', ['category_id' => $root->id]))
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_catalog_index_filters_by_price_range_and_availability(): void
    {
        $vendor = $this->activeVendor();
        $category = Category::factory()->create();

        $cheap = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'price' => 500,
            'stock_qty' => 4,
        ]);
        Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'price' => 5000,
            'stock_qty' => 4,
        ]);
        Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'price' => 500,
            'stock_qty' => 0,
            'is_available' => false,
        ]);

        $this->getJson(route('api.v1.products.index', ['min_price' => 100, 'max_price' => 1000, 'in_stock' => 1]))
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $cheap->id);
    }

    public function test_catalog_show_returns_orderable_product(): void
    {
        $vendor = $this->activeVendor();
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'stock_qty' => 3,
        ]);

        $this->getJson(route('api.v1.products.show', $product))
            ->assertOk()
            ->assertJsonPath('data.id', $product->id)
            ->assertJsonPath('data.is_orderable', true)
            ->assertJsonPath('data.is_available', true);
    }

    public function test_catalog_show_hides_inactive_and_stock_zero_and_vendor_suspended(): void
    {
        $category = Category::factory()->create();

        $inactive = Product::factory()->create([
            'category_id' => $category->id,
            'vendor_id' => $this->activeVendor()->id,
            'is_active' => false,
            'stock_qty' => 3,
        ]);
        $outOfStock = Product::factory()->create([
            'category_id' => $category->id,
            'vendor_id' => $this->activeVendor()->id,
            'stock_qty' => 0,
        ]);
        $suspended = Product::factory()->create([
            'category_id' => $category->id,
            'vendor_id' => Vendor::factory()->create(['status' => VendorStatus::Suspended->value])->id,
            'stock_qty' => 3,
        ]);

        foreach ([$inactive, $outOfStock, $suspended] as $product) {
            $this->getJson(route('api.v1.products.show', $product))
                ->assertNotFound()
                ->assertJsonPath('errors.0.code', 'not_found');
        }
    }

    public function test_catalog_show_returns_404_for_unknown_product(): void
    {
        $this->getJson(route('api.v1.products.show', '00000000-0000-4000-8000-000000000000'))
            ->assertNotFound();
    }
}