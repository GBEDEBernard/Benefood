<?php

namespace Tests\Feature;

use App\Models\Address;
use App\Models\Category;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\Order;
use App\Models\Product;
use App\Models\ProductPromotion;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProductPromotionApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    /**
     * @return array{0: User, 1: Vendor}
     */
    private function vendorContext(): array
    {
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $user = $vendor->user;
        $user->roles()->attach(Role::where('slug', 'vendor')->firstOrFail(), ['is_active' => true]);
        Sanctum::actingAs($user);

        return [$user, $vendor];
    }

    private function clientUser(): User
    {
        $user = User::factory()->create(['phone' => fake()->unique()->numerify('+22997######')]);
        $user->roles()->attach(Role::where('slug', 'client')->firstOrFail(), ['is_active' => true]);
        Sanctum::actingAs($user);

        return $user;
    }

    private function orderableProduct(Vendor $vendor, int $price = 10000, ?string $name = null): Product
    {
        return Product::factory()->create([
            'vendor_id' => $vendor->id,
            'category_id' => Category::factory()->create()->id,
            'name' => $name ?? 'Attiéké poisson',
            'price' => $price,
            'stock_qty' => 10,
            'is_active' => true,
            'is_available' => true,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function promotionPayload(int $promoPrice = 7000): array
    {
        return [
            'promo_price' => $promoPrice,
            'starts_at' => now()->subDay()->toIso8601String(),
            'ends_at' => now()->addDays(2)->toIso8601String(),
            'title' => 'Offre du jour',
        ];
    }

    public function test_promotion_endpoints_require_authentication(): void
    {
        $this->getJson('/api/v1/vendors/me/promotions')
            ->assertStatus(401)
            ->assertJsonPath('errors.0.code', 'unauthenticated');
    }

    public function test_client_cannot_manage_promotions(): void
    {
        $this->clientUser();

        $this->getJson('/api/v1/vendors/me/promotions')
            ->assertStatus(403)
            ->assertJsonPath('errors.0.code', 'forbidden');
    }

    public function test_vendor_can_create_promotion_and_discount_is_exposed(): void
    {
        [, $vendor] = $this->vendorContext();
        $product = $this->orderableProduct($vendor);

        $this->postJson("/api/v1/vendors/me/promotions/products/{$product->id}", $this->promotionPayload())
            ->assertCreated()
            ->assertJsonPath('data.product.id', $product->id)
            ->assertJsonPath('data.promo_price', 7000)
            ->assertJsonPath('data.original_price', 10000)
            ->assertJsonPath('data.discount_percent', 30)
            ->assertJsonPath('data.is_currently_active', true);

        $this->assertDatabaseHas('product_promotions', [
            'vendor_id' => $vendor->id,
            'product_id' => $product->id,
            'promo_price' => 7000,
        ]);
    }

    public function test_promotion_price_must_be_lower_than_original_price(): void
    {
        [, $vendor] = $this->vendorContext();
        $product = $this->orderableProduct($vendor, 5000);

        $this->postJson("/api/v1/vendors/me/promotions/products/{$product->id}", $this->promotionPayload(5000))
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'promotion.price_invalid');

        $this->assertDatabaseCount('product_promotions', 0);
    }

    public function test_promotion_period_must_be_coherent(): void
    {
        [, $vendor] = $this->vendorContext();
        $product = $this->orderableProduct($vendor);

        $this->postJson("/api/v1/vendors/me/promotions/products/{$product->id}", [
            'promo_price' => 7000,
            'starts_at' => now()->addDays(3)->toIso8601String(),
            'ends_at' => now()->addDay()->toIso8601String(),
        ])
            ->assertStatus(422);
    }

    public function test_active_promotions_cannot_overlap_for_same_product(): void
    {
        [, $vendor] = $this->vendorContext();
        $product = $this->orderableProduct($vendor);
        ProductPromotion::factory()->forProduct($product)->active()->create(['promo_price' => 8000]);

        $this->postJson("/api/v1/vendors/me/promotions/products/{$product->id}", $this->promotionPayload(7000))
            ->assertStatus(409)
            ->assertJsonPath('errors.0.code', 'promotion.overlap');
    }

    public function test_vendor_cannot_promote_another_vendors_product(): void
    {
        [, $vendor] = $this->vendorContext();
        $otherProduct = $this->orderableProduct(Vendor::factory()->create(['status' => 'active']));

        $this->postJson("/api/v1/vendors/me/promotions/products/{$otherProduct->id}", $this->promotionPayload())
            ->assertStatus(404)
            ->assertJsonPath('errors.0.code', 'promotion.product_not_found');

        $this->assertNull($vendor->promotions()->first());
    }

    public function test_vendor_can_update_toggle_and_delete_promotion(): void
    {
        [, $vendor] = $this->vendorContext();
        $product = $this->orderableProduct($vendor);
        $promotion = ProductPromotion::factory()->forProduct($product)->active()->create(['promo_price' => 8000]);

        $this->patchJson("/api/v1/vendors/me/promotions/{$promotion->id}", ['promo_price' => 6500])
            ->assertOk()
            ->assertJsonPath('data.promo_price', 6500);

        $this->postJson("/api/v1/vendors/me/promotions/{$promotion->id}/toggle")
            ->assertOk()
            ->assertJsonPath('data.is_active', false);

        $this->deleteJson("/api/v1/vendors/me/promotions/{$promotion->id}")
            ->assertNoContent();

        $this->assertDatabaseMissing('product_promotions', ['id' => $promotion->id]);
    }

    public function test_vendor_cannot_update_another_vendors_promotion(): void
    {
        [, $vendor] = $this->vendorContext();
        $otherVendor = Vendor::factory()->create(['status' => 'active']);
        $otherProduct = $this->orderableProduct($otherVendor);
        $promotion = ProductPromotion::factory()->forProduct($otherProduct)->active()->create();

        $this->patchJson("/api/v1/vendors/me/promotions/{$promotion->id}", ['promo_price' => 5000])
            ->assertStatus(404)
            ->assertJsonPath('errors.0.code', 'not_found');

        $this->assertSame(7000, (int) $promotion->fresh()->promo_price);
        $this->assertNull($vendor->promotions()->first());
    }

    public function test_home_catalog_and_product_detail_expose_active_promotion(): void
    {
        [, $vendor] = $this->vendorContext();
        $product = $this->orderableProduct($vendor);
        ProductPromotion::factory()->forProduct($product)->active()->create([
            'promo_price' => 7000,
            'title' => 'Offre du jour',
        ]);

        $this->getJson('/api/v1/home')
            ->assertOk()
            ->assertJsonPath('data.promotions.0.product.id', $product->id)
            ->assertJsonPath('data.promotions.0.promo_price', 7000)
            ->assertJsonPath('data.promotions.0.discount_percent', 30);

        $this->getJson('/api/v1/products?on_promo=1')
            ->assertOk()
            ->assertJsonPath('data.0.id', $product->id)
            ->assertJsonPath('data.0.price', 10000)
            ->assertJsonPath('data.0.effective_price', 7000)
            ->assertJsonPath('data.0.promotion.discount_percent', 30);

        $this->getJson("/api/v1/products/{$product->id}")
            ->assertOk()
            ->assertJsonPath('data.effective_price', 7000)
            ->assertJsonPath('data.promotion.promo_price', 7000);
    }

    public function test_cart_uses_promotional_price(): void
    {
        $this->clientUser();
        $vendor = Vendor::factory()->create(['status' => 'active']);
        $product = $this->orderableProduct($vendor);
        ProductPromotion::factory()->forProduct($product)->active()->create(['promo_price' => 7000]);

        $this->postJson('/api/v1/cart/items', [
            'product_id' => $product->id,
            'quantity' => 2,
        ])
            ->assertOk()
            ->assertJsonPath('data.items.0.product.unit_price', 7000)
            ->assertJsonPath('data.items.0.product.original_price', 10000)
            ->assertJsonPath('data.items.0.subtotal', 14000)
            ->assertJsonPath('data.subtotal', 14000)
            ->assertJsonPath('data.savings', 6000);
    }

    public function test_checkout_charges_promotional_price_and_records_savings(): void
    {
        $client = $this->clientUser();
        $vendor = Vendor::factory()->create(['status' => 'active', 'city' => 'Cotonou']);
        $product = $this->orderableProduct($vendor);
        ProductPromotion::factory()->forProduct($product)->active()->create(['promo_price' => 7000]);

        $zone = DeliveryZone::factory()->create(['name' => 'Cotonou Centre', 'city' => 'Cotonou']);
        DeliveryRate::factory()->create(['zone_id' => $zone->id, 'price' => 1500]);
        $address = Address::factory()->create(['user_id' => $client->id, 'city' => 'Cotonou']);

        $this->postJson('/api/v1/cart/items', [
            'product_id' => $product->id,
            'quantity' => 2,
        ])->assertOk();

        $this->postJson('/api/v1/orders/summary', ['address_id' => $address->id])
            ->assertOk()
            ->assertJsonPath('data.subtotal', 14000)
            ->assertJsonPath('data.original_subtotal', 20000)
            ->assertJsonPath('data.discount', 6000)
            ->assertJsonPath('data.total', 16200);

        $reference = $this->postJson('/api/v1/orders', ['address_id' => $address->id])
            ->assertCreated()
            ->json('data.reference');

        $order = Order::where('reference', $reference)->firstOrFail();

        $this->assertSame(14000, (int) $order->subtotal);
        $this->assertSame(6000, (int) $order->discount);
        $this->assertSame(16200, (int) $order->total);
        $this->assertDatabaseHas('order_items', [
            'order_id' => $order->id,
            'product_id' => $product->id,
            'unit_price_snapshot' => 7000,
            'subtotal' => 14000,
        ]);
        $this->assertDatabaseHas('order_financials', [
            'order_id' => $order->id,
            'subtotal' => 14000,
            'discount' => 6000,
            'total_client' => 16200,
        ]);
    }

    public function test_vendor_can_create_promotion_from_percentage(): void
    {
        [, $vendor] = $this->vendorContext();
        $product = $this->orderableProduct($vendor, 10000, 'Plat pourcentage');

        $this->postJson("/api/v1/vendors/me/promotions/products/{$product->id}", [
            'discount_percent' => 25,
            'starts_at' => now()->subDay()->toIso8601String(),
            'ends_at' => now()->addDays(2)->toIso8601String(),
        ])
            ->assertCreated()
            ->assertJsonPath('data.promo_price', 7500)
            ->assertJsonPath('data.discount_percent', 25);

        $this->assertDatabaseHas('product_promotions', [
            'product_id' => $product->id,
            'promo_price' => 7500,
        ]);
    }

    public function test_vendor_can_apply_percentage_to_selected_products(): void
    {
        [, $vendor] = $this->vendorContext();
        $first = $this->orderableProduct($vendor, 10000, 'Plat A');
        $second = $this->orderableProduct($vendor, 5000, 'Plat B');
        $untouched = $this->orderableProduct($vendor, 8000, 'Plat C');

        $this->postJson('/api/v1/vendors/me/promotions/bulk', [
            'discount_percent' => 20,
            'product_ids' => [$first->id, $second->id],
            'starts_at' => now()->subDay()->toIso8601String(),
            'ends_at' => now()->addDays(2)->toIso8601String(),
            'title' => 'Remise groupée',
        ])
            ->assertCreated()
            ->assertJsonPath('data.created_count', 2)
            ->assertJsonPath('data.skipped_count', 0)
            ->assertJsonPath('data.promotions.0.title', 'Remise groupée');

        $this->assertDatabaseHas('product_promotions', ['product_id' => $first->id, 'promo_price' => 8000]);
        $this->assertDatabaseHas('product_promotions', ['product_id' => $second->id, 'promo_price' => 4000]);
        $this->assertDatabaseCount('product_promotions', 2);
        $this->assertSame(0, ProductPromotion::where('product_id', $untouched->id)->count());
    }

    public function test_vendor_can_apply_percentage_to_all_orderable_products_and_skip_conflicts(): void
    {
        [, $vendor] = $this->vendorContext();
        $first = $this->orderableProduct($vendor, 10000, 'Plat A');
        $conflicted = $this->orderableProduct($vendor, 9000, 'Plat B');
        $third = $this->orderableProduct($vendor, 8000, 'Plat C');
        ProductPromotion::factory()->forProduct($conflicted)->active()->create(['promo_price' => 7000]);

        $this->postJson('/api/v1/vendors/me/promotions/bulk', [
            'discount_percent' => 30,
            'all_products' => true,
            'starts_at' => now()->subDay()->toIso8601String(),
            'ends_at' => now()->addDays(2)->toIso8601String(),
        ])
            ->assertCreated()
            ->assertJsonPath('data.created_count', 2)
            ->assertJsonPath('data.skipped_count', 1)
            ->assertJsonPath('data.skipped.0.code', 'promotion.overlap');

        $this->assertDatabaseHas('product_promotions', ['product_id' => $first->id, 'promo_price' => 7000]);
        $this->assertDatabaseHas('product_promotions', ['product_id' => $third->id, 'promo_price' => 5600]);
        $this->assertSame(7000, (int) $conflicted->promotions()->first()->promo_price);
    }

    public function test_bulk_promotion_requires_a_target_and_a_valid_percentage(): void
    {
        [, $vendor] = $this->vendorContext();
        $product = $this->orderableProduct($vendor);
        $payload = [
            'starts_at' => now()->subDay()->toIso8601String(),
            'ends_at' => now()->addDays(2)->toIso8601String(),
        ];

        $this->postJson('/api/v1/vendors/me/promotions/bulk', $payload + ['discount_percent' => 20])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'promotion.target_required');

        $this->postJson('/api/v1/vendors/me/promotions/bulk', $payload + [
            'discount_percent' => 100,
            'product_ids' => [$product->id],
        ])->assertStatus(422);

        $this->assertDatabaseCount('product_promotions', 0);
    }

    public function test_vendor_can_update_promotion_from_percentage(): void
    {
        [, $vendor] = $this->vendorContext();
        $product = $this->orderableProduct($vendor, 10000);
        $promotion = ProductPromotion::factory()->forProduct($product)->active()->create(['promo_price' => 8000]);

        $this->patchJson("/api/v1/vendors/me/promotions/{$promotion->id}", ['discount_percent' => 40])
            ->assertOk()
            ->assertJsonPath('data.promo_price', 6000)
            ->assertJsonPath('data.discount_percent', 40);
    }
}
