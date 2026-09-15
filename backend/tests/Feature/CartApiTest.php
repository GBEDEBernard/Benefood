<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CartApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function clientUser(): User
    {
        $user = User::factory()->create(['phone' => '+22997000041']);
        $role = Role::where('slug', 'client')->firstOrFail();
        $user->roles()->attach($role, ['is_active' => true]);

        Sanctum::actingAs($user);

        return $user;
    }

    private function activeVendor(): Vendor
    {
        return Vendor::factory()->create(['status' => 'active']);
    }

    private function orderableProduct(Vendor $vendor): Product
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

    private function addProduct(Product $product, int $quantity = 1)
    {
        return $this->postJson('/api/v1/cart/items', [
            'product_id' => $product->id,
            'quantity' => $quantity,
        ]);
    }

    public function test_cart_add_item_returns_cart_with_item(): void
    {
        $this->clientUser();
        $product = $this->orderableProduct($this->activeVendor());

        $this->addProduct($product)
            ->assertOk()
            ->assertJsonPath('data.vendor.id', $product->vendor_id)
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.product.id', $product->id)
            ->assertJsonPath('data.subtotal', 500);
    }

    public function test_cart_requires_client_permission(): void
    {
        $user = User::factory()->create(['phone' => '+22997000042']);
        Sanctum::actingAs($user);

        $this->getJson('/api/v1/cart')
            ->assertStatus(403)
            ->assertJsonPath('errors.0.code', 'forbidden');
    }

    public function test_cart_requires_authentication(): void
    {
        $this->getJson('/api/v1/cart')
            ->assertStatus(401)
            ->assertJsonPath('errors.0.code', 'unauthenticated');
    }

    public function test_cart_is_mono_vendor(): void
    {
        $this->clientUser();
        $first = $this->orderableProduct($this->activeVendor());
        $second = $this->orderableProduct($this->activeVendor());

        $this->addProduct($first)->assertOk();
        $this->addProduct($second)
            ->assertStatus(409)
            ->assertJsonPath('errors.0.code', 'cart.vendor_conflict');
    }

    public function test_cart_reassigns_vendor_when_empty(): void
    {
        $this->clientUser();
        $first = $this->orderableProduct($this->activeVendor());
        $second = $this->orderableProduct($this->activeVendor());

        $this->addProduct($first)->assertOk();
        $this->deleteJson('/api/v1/cart')->assertNoContent();
        $this->addProduct($second)
            ->assertOk()
            ->assertJsonPath('data.vendor.id', $second->vendor_id);
    }

    public function test_cart_rejects_unavailable_product(): void
    {
        $this->clientUser();
        $vendor = $this->activeVendor();
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'is_active' => true,
            'is_available' => false,
            'stock_qty' => 5,
        ]);

        $this->addProduct($product)
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'cart.product_unavailable');
    }

    public function test_cart_rejects_quantity_below_one(): void
    {
        $this->clientUser();
        $product = $this->orderableProduct($this->activeVendor());

        $this->addProduct($product, 0)
            ->assertStatus(422)
            ->assertJsonStructure(['errors' => [['code', 'message', 'field']]]);
    }

    public function test_cart_rejects_insufficient_stock(): void
    {
        $this->clientUser();
        $vendor = $this->activeVendor();
        $product = Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'stock_qty' => 2,
        ]);

        $this->addProduct($product, 5)
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'cart.insufficient_stock');
    }

    public function test_cart_update_and_remove_item(): void
    {
        $this->clientUser();
        $product = $this->orderableProduct($this->activeVendor());

        $itemId = $this->addProduct($product)->assertOk()->json('data.items.0.id');

        $this->patchJson("/api/v1/cart/items/{$itemId}", ['quantity' => 3])
            ->assertOk()
            ->assertJsonPath('data.items.0.quantity', 3)
            ->assertJsonPath('data.subtotal', 1500);

        $this->deleteJson("/api/v1/cart/items/{$itemId}")
            ->assertNoContent();
    }

    public function test_cart_update_other_users_item_returns_404(): void
    {
        $this->clientUser();
        $product = $this->orderableProduct($this->activeVendor());
        $itemId = $this->addProduct($product)->assertOk()->json('data.items.0.id');

        $other = User::factory()->create(['phone' => '+22997000043']);
        $role = Role::where('slug', 'client')->firstOrFail();
        $other->roles()->attach($role, ['is_active' => true]);
        Sanctum::actingAs($other);

        $this->patchJson("/api/v1/cart/items/{$itemId}", ['quantity' => 2])
            ->assertStatus(404);
    }
}
