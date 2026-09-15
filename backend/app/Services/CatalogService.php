<?php

namespace App\Services;

use App\Exceptions\DomainException;
use App\Models\Category;
use App\Models\Product;
use App\Models\Vendor;

/**
 * Catalogue (M4 — J61 à J65) : création/édition produits, désactivation sans
 * suppression, versioning des prix, traçabilité du stock.
 */
class CatalogService
{
    public function storeProduct(Vendor $vendor, array $data, ?string $actorId = null): Product
    {
        $category = $this->assertCategoryUsable($data['category_id'] ?? null);

        $stockQty = $data['stock_qty'] ?? null;
        $price = (int) $data['price'];

        $product = Product::create([
            'vendor_id' => $vendor->id,
            'category_id' => $category->id,
            'name' => $data['name'],
            'description' => $data['description'] ?? null,
            'unit' => $data['unit'] ?? 'unit',
            'price' => $price,
            'stock_qty' => $stockQty,
            'image_main' => $data['image_main'] ?? null,
            'is_active' => (bool) ($data['is_active'] ?? true),
            'is_available' => (bool) ($data['is_available'] ?? ($stockQty === null || $stockQty > 0)),
            'status' => 'active',
        ]);

        $product->stockLogs()->create([
            'delta' => $stockQty,
            'qty_after' => $stockQty,
            'reason' => 'initial',
        ]);

        $product->priceHistory()->create([
            'old_price' => $price,
            'new_price' => $price,
            'changed_by' => $actorId,
            'changed_at' => now(),
        ]);

        return $product->fresh();
    }

    public function updateProduct(Product $product, array $data, ?string $actorId = null): Product
    {
        if (array_key_exists('category_id', $data)) {
            $category = $this->assertCategoryUsable($data['category_id']);
            $data['category_id'] = $category->id;
        }

        if (array_key_exists('price', $data) && (int) $data['price'] !== (int) $product->price) {
            $this->recordPriceChange($product, (int) $data['price'], $actorId);
        }

        if (array_key_exists('stock_qty', $data)) {
            $this->applyStockChange($product, $data['stock_qty']);
            unset($data['stock_qty']);

            if ($product->fresh()->stock_qty !== null && $product->fresh()->stock_qty <= 0) {
                $data['is_available'] = false;
            }
        }

        $product->update($data);

        return $product->fresh();
    }

    public function recordPriceChange(Product $product, int $newPrice, ?string $actorId): void
    {
        $product->priceHistory()->create([
            'old_price' => (int) $product->price,
            'new_price' => $newPrice,
            'changed_by' => $actorId,
            'changed_at' => now(),
        ]);
    }

    public function adjustStock(Product $product, int $delta, string $reason = 'adjust', ?string $referenceType = null, ?string $referenceId = null): int
    {
        if ($delta === 0) {
            return (int) ($product->stock_qty ?? 0);
        }

        $current = (int) ($product->stock_qty ?? 0);
        $after = max(0, $current + $delta);
        $product->update(['stock_qty' => $after]);

        $product->stockLogs()->create([
            'delta' => $delta,
            'qty_after' => $after,
            'reason' => $reason,
            'reference_type' => $referenceType,
            'reference_id' => $referenceId,
        ]);

        if ($after === 0 && $product->fresh()->is_available) {
            $product->update(['is_available' => false]);
        }

        return $after;
    }

    public function setAvailability(Product $product, bool $available, ?int $stockQty = null): Product
    {
        $data = ['is_available' => $available];

        if ($stockQty !== null) {
            $this->applyStockChange($product, $stockQty);
            $data['stock_qty'] = $stockQty;

            if ($stockQty <= 0) {
                $data['is_available'] = false;
            } elseif ($available) {
                $data['is_available'] = true;
            }
        }

        $product->update($data);

        return $product->fresh();
    }

    public function toggleActive(Product $product, bool $active): Product
    {
        $product->update(['is_active' => $active]);

        return $product->fresh();
    }

    /**
     * Désactivation sans suppression (J21/J65) — le produit reste dans l'historique
     * des commandes mais n'est plus visible ni commandable.
     */
    public function deactivate(Product $product): void
    {
        $product->update(['is_active' => false]);
    }

    private function assertCategoryUsable(?string $categoryId): Category
    {
        $category = $categoryId !== null ? Category::find($categoryId) : null;

        if ($category === null) {
            throw new DomainException('catalog.category_not_found', 'La catégorie sélectionnée n\'existe pas.', 422);
        }

        if (! $category->is_active) {
            throw new DomainException('catalog.category_inactive', 'La catégorie sélectionnée est inactive.', 422);
        }

        return $category;
    }

    private function applyStockChange(Product $product, ?int $newStock): void
    {
        $oldStock = $product->stock_qty;

        if ($newStock === null) {
            $product->update(['stock_qty' => null]);

            return;
        }

        if ($oldStock === null) {
            $delta = $newStock;
            $reason = 'initial';
        } else {
            $delta = $newStock - $oldStock;
            $reason = 'adjust';
        }

        $product->update(['stock_qty' => $newStock]);

        if ($delta !== 0 || $reason === 'initial') {
            $product->stockLogs()->create([
                'delta' => $delta,
                'qty_after' => $newStock,
                'reason' => $reason,
            ]);
        }
    }
}
