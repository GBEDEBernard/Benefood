<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\Product;
use App\Models\Vendor;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Product>
 */
class ProductFactory extends Factory
{
    protected $model = Product::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'vendor_id' => Vendor::factory(),
            'category_id' => Category::factory(),
            'name' => ucfirst(fake()->words(3, true)),
            'unit' => fake()->randomElement(['pièce', 'kg', 'pack', 'litre']),
            'price' => fake()->numberBetween(50, 50000),
            'stock_qty' => fake()->numberBetween(0, 500),
            'is_active' => true,
            'is_available' => true,
            'status' => 'active',
        ];
    }
}
