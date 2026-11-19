<?php

namespace Database\Factories;

use App\Models\Product;
use App\Models\ProductPromotion;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ProductPromotion>
 */
class ProductPromotionFactory extends Factory
{
    protected $model = ProductPromotion::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $startsAt = fake()->dateTimeBetween('-1 day', '+1 day');

        return [
            'promo_price' => 7000,
            'starts_at' => $startsAt,
            'ends_at' => (clone $startsAt)->modify('+7 days'),
            'is_active' => true,
            'title' => fake()->optional()->sentence(3),
        ];
    }

    public function forProduct(Product $product): static
    {
        return $this->state(fn (): array => [
            'product_id' => $product->id,
            'vendor_id' => $product->vendor_id,
        ]);
    }

    public function active(): static
    {
        return $this->state(fn (): array => [
            'is_active' => true,
            'starts_at' => now()->subDay(),
            'ends_at' => now()->addDays(3),
        ]);
    }
}
