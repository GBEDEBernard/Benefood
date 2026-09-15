<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AdminCatalogTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        Storage::fake('public');
    }

    private function admin(): User
    {
        $admin = User::factory()->create(['email' => 'admin@local']);
        $admin->roles()->attach(Role::where('slug', 'admin-technique')->first()->id, ['is_active' => true]);

        return $admin;
    }

    private function vendor(): Vendor
    {
        return Vendor::factory()->create();
    }

    private function category(): Category
    {
        return Category::factory()->create();
    }

    public function test_admin_can_list_products_and_view_detail(): void
    {
        $vendor = $this->vendor();
        $category = $this->category();
        $product = Product::factory()->create(['vendor_id' => $vendor->id, 'category_id' => $category->id]);

        $this->actingAs($this->admin())
            ->get(route('admin.products.index'))
            ->assertOk()
            ->assertSee($product->name);

        $this->get(route('admin.products.show', $product))
            ->assertOk()
            ->assertSee($product->name);
    }

    public function test_admin_can_create_product_with_initial_traceability(): void
    {
        $vendor = $this->vendor();
        $category = $this->category();
        $admin = $this->admin();

        $this->actingAs($admin)
            ->post(route('admin.products.store'), [
                'vendor_id' => $vendor->id,
                'category_id' => $category->id,
                'name' => 'Pâte d\'arachide',
                'unit' => 'pot',
                'price' => 2500,
                'stock_qty' => 10,
                'is_active' => 1,
            ])->assertRedirect();

        $product = Product::where('name', 'Pâte d\'arachide')->first();
        $this->assertNotNull($product);
        $this->assertSame(2500, $product->price);
        $this->assertDatabaseHas('stock_logs', [
            'product_id' => $product->id,
            'reason' => 'initial',
            'qty_after' => 10,
        ]);
        $this->assertDatabaseHas('product_price_history', [
            'product_id' => $product->id,
            'old_price' => 2500,
            'new_price' => 2500,
            'changed_by' => $admin->id,
        ]);
    }

    public function test_admin_can_update_product_price_records_history(): void
    {
        $product = Product::factory()->create([
            'vendor_id' => $this->vendor()->id,
            'category_id' => $this->category()->id,
            'price' => 1000,
        ]);
        $admin = $this->admin();

        $this->actingAs($admin)
            ->from(route('admin.products.edit', $product))
            ->put(route('admin.products.update', $product), ['price' => 1800])
            ->assertRedirect();

        $this->assertSame(1800, $product->fresh()->price);
        $this->assertDatabaseHas('product_price_history', [
            'product_id' => $product->id,
            'old_price' => 1000,
            'new_price' => 1800,
            'changed_by' => $admin->id,
        ]);
    }

    public function test_admin_can_toggle_active_and_set_availability(): void
    {
        $product = Product::factory()->create([
            'vendor_id' => $this->vendor()->id,
            'category_id' => $this->category()->id,
            'stock_qty' => 3,
            'is_active' => true,
            'is_available' => true,
        ]);
        $admin = $this->admin();

        $this->actingAs($admin)
            ->post(route('admin.products.active', $product))
            ->assertRedirect();
        $this->assertFalse($product->fresh()->is_active);

        $this->post(route('admin.products.availability', $product), [
            'is_available' => 0,
            'stock_qty' => 3,
        ])->assertRedirect();
        $this->assertFalse($product->fresh()->is_available);

        $this->post(route('admin.products.active', $product))
            ->assertRedirect();
        $this->assertTrue($product->fresh()->is_active);
    }

    public function test_admin_destroy_deactivates_product(): void
    {
        $product = Product::factory()->create([
            'vendor_id' => $this->vendor()->id,
            'category_id' => $this->category()->id,
            'is_active' => true,
        ]);

        $this->actingAs($this->admin())
            ->delete(route('admin.products.destroy', $product))
            ->assertRedirect();

        $this->assertDatabaseHas('products', ['id' => $product->id, 'is_active' => false]);
    }

    public function test_admin_can_upload_and_remove_product_image(): void
    {
        $product = Product::factory()->create([
            'vendor_id' => $this->vendor()->id,
            'category_id' => $this->category()->id,
        ]);

        $this->actingAs($this->admin())
            ->post(route('admin.products.images.store', $product), [
                'image' => UploadedFile::fake()->image('special.jpg', 800, 600),
            ])->assertOk();

        $this->assertDatabaseHas('product_images', [
            'product_id' => $product->id,
            'is_main' => true,
        ]);

        $image = $product->images()->first();
        $this->assertNotNull($image);
        Storage::disk('public')->assertExists($image->path);

        $this->delete(route('admin.products.images.destroy', [$product, $image]))
            ->assertRedirect();

        $this->assertDatabaseMissing('product_images', ['id' => $image->id]);
    }

    public function test_admin_can_manage_categories(): void
    {
        $admin = $this->admin();
        $root = $this->category();

        $this->actingAs($admin)
            ->post(route('admin.categories.store'), ['name' => 'Céréales'])
            ->assertRedirect();

        $created = Category::where('name', 'Céréales')->first();
        $this->assertNotNull($created);
        $this->assertSame('cereales', $created->slug);
        $this->assertTrue($created->is_active);

        $this->put(route('admin.categories.update', $created), [
            'name' => 'Céréales & légumineuses',
            'parent_id' => $root->id,
        ])->assertRedirect();
        $this->assertSame($root->id, $created->fresh()->parent_id);

        $this->post(route('admin.categories.destroy', $created))
            ->assertRedirect();
        $this->assertDatabaseHas('categories', ['id' => $created->id, 'is_active' => false]);
    }

    public function test_admin_category_slug_is_unique(): void
    {
        $admin = $this->admin();
        Category::factory()->create(['name' => 'Épices', 'slug' => 'epices']);

        $this->actingAs($admin)
            ->post(route('admin.categories.store'), ['name' => 'Épices'])
            ->assertRedirect();

        $this->assertDatabaseHas('categories', ['slug' => 'epices-1']);
    }

    public function test_client_cannot_access_backoffice_products(): void
    {
        $client = User::factory()->create(['phone' => '+22997000011']);
        $client->roles()->attach(Role::where('slug', 'client')->first()->id, ['is_active' => true]);

        $this->actingAs($client)
            ->get(route('admin.products.index'))
            ->assertForbidden();
    }
}