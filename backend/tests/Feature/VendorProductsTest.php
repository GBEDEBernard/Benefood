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
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class VendorProductsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        Storage::fake('public');
    }

    private function vendorUser(): array
    {
        $user = User::factory()->create(['phone' => '+22997000010']);
        $user->roles()->attach(Role::where('slug', 'vendor')->first()->id, ['is_active' => true]);

        $vendor = Vendor::create([
            'user_id' => $user->id,
            'business_name' => 'Resto Chez Awa',
            'phone' => '+22997000011',
            'city' => 'Cotonou',
            'status' => 'active',
            'approved_at' => now(),
        ]);

        return [$user, $vendor];
    }

    private function category(): Category
    {
        return Category::factory()->create();
    }

    public function test_vendor_can_create_product_with_stock_and_price_traceability(): void
    {
        [$user, $vendor] = $this->vendorUser();
        $category = $this->category();
        Sanctum::actingAs($user);

        $this->postJson(route('api.v1.vendors.me.products.store'), [
            'category_id' => $category->id,
            'name' => 'Ignames',
            'unit' => 'kg',
            'price' => 1500,
            'stock_qty' => 20,
        ])->assertCreated()
            ->assertJsonPath('data.name', 'Ignames')
            ->assertJsonPath('data.currency', 'XOF')
            ->assertJsonPath('data.is_orderable', true);

        $product = $vendor->products()->first();
        $this->assertNotNull($product);
        $this->assertDatabaseHas('stock_logs', [
            'product_id' => $product->id,
            'reason' => 'initial',
            'qty_after' => 20,
        ]);
        $this->assertDatabaseHas('product_price_history', [
            'product_id' => $product->id,
            'old_price' => 1500,
            'new_price' => 1500,
            'changed_by' => $user->id,
        ]);
    }

    public function test_vendor_can_update_price_records_history(): void
    {
        [$user] = $this->vendorUser();
        $product = Product::factory()->create([
            'vendor_id' => $user->vendor()->first()->id,
            'category_id' => $this->category()->id,
            'price' => 1000,
            'stock_qty' => 5,
        ]);
        Sanctum::actingAs($user);

        $this->patchJson(route('api.v1.vendors.me.products.update', $product), ['price' => 2000])
            ->assertOk()
            ->assertJsonPath('data.price', 2000);

        $this->assertDatabaseHas('product_price_history', [
            'product_id' => $product->id,
            'old_price' => 1000,
            'new_price' => 2000,
            'changed_by' => $user->id,
        ]);
    }

    public function test_vendor_stock_to_zero_marks_product_unavailable(): void
    {
        [$user] = $this->vendorUser();
        $product = Product::factory()->create([
            'vendor_id' => $user->vendor()->first()->id,
            'category_id' => $this->category()->id,
            'stock_qty' => 5,
            'is_available' => true,
        ]);
        Sanctum::actingAs($user);

        $this->patchJson(route('api.v1.vendors.me.products.update', $product), ['stock_qty' => 0])
            ->assertOk()
            ->assertJsonPath('data.is_available', false)
            ->assertJsonPath('data.is_orderable', false);

        $this->assertSame(0, $product->fresh()->stock_qty);
        $this->assertFalse($product->fresh()->is_available);
    }

    public function test_vendor_cannot_manage_another_vendors_product(): void
    {
        [$user] = $this->vendorUser();
        $other = Product::factory()->create([
            'vendor_id' => Vendor::factory()->create()->id,
            'category_id' => $this->category()->id,
        ]);
        Sanctum::actingAs($user);

        $this->patchJson(route('api.v1.vendors.me.products.update', $other), ['name' => 'Pirate'])
            ->assertNotFound()
            ->assertJsonPath('errors.0.code', 'not_found');
    }

    public function test_vendor_cannot_use_inactive_category(): void
    {
        [$user] = $this->vendorUser();
        $category = Category::factory()->create(['is_active' => false]);
        Sanctum::actingAs($user);

        $this->postJson(route('api.v1.vendors.me.products.store'), [
            'category_id' => $category->id,
            'name' => 'Interdit',
            'price' => 100,
        ])->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'catalog.category_inactive');
    }

    public function test_destroy_deactivates_product_instead_of_deleting(): void
    {
        [$user] = $this->vendorUser();
        $product = Product::factory()->create([
            'vendor_id' => $user->vendor()->first()->id,
            'category_id' => $this->category()->id,
            'is_active' => true,
        ]);
        Sanctum::actingAs($user);

        $this->deleteJson(route('api.v1.vendors.me.products.destroy', $product))
            ->assertNoContent();

        $this->assertDatabaseHas('products', ['id' => $product->id, 'is_active' => false]);
    }

    public function test_vendor_can_upload_and_remove_product_image(): void
    {
        [$user] = $this->vendorUser();
        $product = Product::factory()->create([
            'vendor_id' => $user->vendor()->first()->id,
            'category_id' => $this->category()->id,
        ]);
        Sanctum::actingAs($user);

        $upload = $this->postJson(route('api.v1.vendors.me.products.images.store', $product), [
            'image' => UploadedFile::fake()->image('photo.jpg', 800, 600),
        ])->assertCreated();

        $imageId = $upload->json('data.id');
        $this->assertDatabaseHas('product_images', [
            'id' => $imageId,
            'product_id' => $product->id,
            'is_main' => true,
            'mime' => 'image/webp',
        ]);

        $path = \App\Models\ProductImage::find($imageId)->path;
        Storage::disk('public')->assertExists($path);
        Storage::disk('public')->assertExists(preg_replace('/\.webp$/', '_thumb.webp', $path));

        $this->deleteJson(route('api.v1.vendors.me.products.images.destroy', [$product, $imageId]))
            ->assertNoContent();

        $this->assertDatabaseMissing('product_images', ['id' => $imageId]);
    }

    public function test_vendor_without_profile_gets_not_found_on_store(): void
    {
        $user = User::factory()->create(['phone' => '+22997000012']);
        $user->roles()->attach(Role::where('slug', 'vendor')->first()->id, ['is_active' => true]);
        Sanctum::actingAs($user);

        $this->postJson(route('api.v1.vendors.me.products.store'), [
            'category_id' => $this->category()->id,
            'name' => 'Sans boutique',
            'price' => 100,
        ])->assertNotFound()
            ->assertJsonPath('errors.0.code', 'vendor.not_onboarded');
    }
}