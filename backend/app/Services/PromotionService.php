<?php

namespace App\Services;

use App\Exceptions\DomainException;
use App\Models\Product;
use App\Models\ProductPromotion;
use App\Models\Vendor;
use Carbon\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Promotions de produits créées par les vendeurs.
 *
 * Le prix promo est appliqué côté serveur au panier et à la commande. Une
 * seule promotion active et chevauchante est autorisée par produit.
 */
class PromotionService
{
    /**
     * Promotion en cours pour un produit, le cas échéant.
     */
    public function activeFor(Product $product): ?ProductPromotion
    {
        if ($product->relationLoaded('activePromotion')) {
            $active = $product->getRelation('activePromotion');

            if ($active instanceof ProductPromotion) {
                $active->setRelation('product', $product);

                return $active;
            }

            return null;
        }

        $active = $product->activePromotion()->first();
        $active?->setRelation('product', $product);

        return $active;
    }

    /**
     * Prix réellement facturé pour un produit à l'instant présent.
     */
    public function effectivePrice(Product $product): int
    {
        $promotion = $this->activeFor($product);

        return $promotion !== null ? (int) $promotion->promo_price : (int) $product->price;
    }

    /**
     * Convertit un pourcentage de remise en prix promo entier (FCFA).
     */
    public static function priceFromPercent(int $price, int $percent): int
    {
        $price = max(0, $price);
        $discount = max(0, 100 - $percent);

        return intdiv($price * $discount + 50, 100);
    }

    /**
     * Applique un même pourcentage à plusieurs produits (ou à toute la boutique).
     *
     * Les produits déjà couverts par une promotion active sur la période sont
     * ignorés et renvoyés dans `skipped` plutôt que de faire échouer tout le lot.
     *
     * @param  array{discount_percent: int, all_products?: bool, product_ids?: array<int, string>, starts_at: Carbon|string, ends_at: Carbon|string, title?: string|null, is_active?: bool}  $data
     * @return array{created: Collection<int, ProductPromotion>, skipped: array<int, array{product_id: string, product_name: string, code: string, message: string}>}
     */
    public function createBulkFromPercent(Vendor $vendor, array $data): array
    {
        $percent = (int) $data['discount_percent'];
        $startsAt = Carbon::parse($data['starts_at']);
        $endsAt = Carbon::parse($data['ends_at']);
        $allProducts = (bool) ($data['all_products'] ?? false);

        $this->assertValidPercent($percent);
        $this->assertValidPeriod($startsAt, $endsAt);

        $query = $vendor->products();
        $requestedIds = [];

        if (! $allProducts) {
            $requestedIds = array_values(array_unique(array_filter(
                $data['product_ids'] ?? [],
                static fn (mixed $id): bool => is_string($id) && $id !== '',
            )));

            if ($requestedIds === []) {
                throw new DomainException(
                    'promotion.target_required',
                    'Sélectionnez au moins un plat.',
                    422,
                );
            }

            $query->whereIn('id', $requestedIds);
        } else {
            $query->orderable();
        }

        $products = $query->orderBy('name')->get();
        $created = collect();
        $skipped = [];

        foreach ($products as $product) {
            try {
                $created->push($this->create($vendor, $product, [
                    'promo_price' => self::priceFromPercent((int) $product->price, $percent),
                    'starts_at' => $startsAt,
                    'ends_at' => $endsAt,
                    'title' => $data['title'] ?? null,
                    'is_active' => (bool) ($data['is_active'] ?? true),
                ]));
            } catch (DomainException $exception) {
                $skipped[] = [
                    'product_id' => (string) $product->id,
                    'product_name' => (string) $product->name,
                    'code' => $exception->errorCode,
                    'message' => $exception->getMessage(),
                ];
            }
        }

        if (! $allProducts) {
            $foundIds = $products->pluck('id')->map(static fn (mixed $id): string => (string) $id)->all();

            foreach ($requestedIds as $productId) {
                if (! in_array($productId, $foundIds, true)) {
                    $skipped[] = [
                        'product_id' => $productId,
                        'product_name' => 'Produit introuvable',
                        'code' => 'promotion.product_not_found',
                        'message' => 'Ce plat n’existe plus ou n’appartient pas à votre boutique.',
                    ];
                }
            }
        }

        return ['created' => $created, 'skipped' => $skipped];
    }

    /**
     * Économie réalisée sur une ligne, en FCFA.
     */
    public function savings(Product $product, int $quantity): int
    {
        if ($quantity < 1) {
            return 0;
        }

        return ((int) $product->price - $this->effectivePrice($product)) * $quantity;
    }

    /**
     * @param  array{promo_price: int, starts_at: Carbon|string, ends_at: Carbon|string, title?: string|null, is_active?: bool}  $data
     */
    public function create(Vendor $vendor, Product $product, array $data): ProductPromotion
    {
        $this->assertProductOwnership($vendor, $product);

        $startsAt = Carbon::parse($data['starts_at']);
        $endsAt = Carbon::parse($data['ends_at']);
        $promoPrice = (int) $data['promo_price'];
        $isActive = (bool) ($data['is_active'] ?? true);

        $this->assertValidPrice($product, $promoPrice);
        $this->assertValidPeriod($startsAt, $endsAt);

        if ($isActive) {
            $this->assertNoOverlap($product, $startsAt, $endsAt);
        }

        return DB::transaction(fn (): ProductPromotion => $product->promotions()->create([
            'vendor_id' => $vendor->id,
            'promo_price' => $promoPrice,
            'starts_at' => $startsAt,
            'ends_at' => $endsAt,
            'is_active' => $isActive,
            'title' => $data['title'] ?? null,
        ]));
    }

    /**
     * @param  array{promo_price?: int, starts_at?: Carbon|string, ends_at?: Carbon|string, title?: string|null, is_active?: bool}  $data
     */
    public function update(Vendor $vendor, ProductPromotion $promotion, array $data): ProductPromotion
    {
        $this->assertPromotionOwnership($vendor, $promotion);

        $promoPrice = array_key_exists('promo_price', $data)
            ? (int) $data['promo_price']
            : (int) $promotion->promo_price;
        $startsAt = array_key_exists('starts_at', $data)
            ? Carbon::parse($data['starts_at'])
            : $promotion->starts_at;
        $endsAt = array_key_exists('ends_at', $data)
            ? Carbon::parse($data['ends_at'])
            : $promotion->ends_at;
        $isActive = array_key_exists('is_active', $data)
            ? (bool) $data['is_active']
            : (bool) $promotion->is_active;

        $this->assertValidPrice($promotion->product, $promoPrice);
        $this->assertValidPeriod($startsAt, $endsAt);

        if ($isActive) {
            $this->assertNoOverlap($promotion->product, $startsAt, $endsAt, $promotion->id);
        }

        $promotion->update([
            'promo_price' => $promoPrice,
            'starts_at' => $startsAt,
            'ends_at' => $endsAt,
            'is_active' => $isActive,
            'title' => array_key_exists('title', $data) ? $data['title'] : $promotion->title,
        ]);

        return $promotion->fresh()->load('product');
    }

    public function toggle(Vendor $vendor, ProductPromotion $promotion): ProductPromotion
    {
        $this->assertPromotionOwnership($vendor, $promotion);

        if (! $promotion->is_active) {
            $this->assertNoOverlap($promotion->product, $promotion->starts_at, $promotion->ends_at, $promotion->id);
        }

        $promotion->update(['is_active' => ! $promotion->is_active]);

        return $promotion->fresh()->load('product');
    }

    public function delete(Vendor $vendor, ProductPromotion $promotion): void
    {
        $this->assertPromotionOwnership($vendor, $promotion);

        $promotion->delete();
    }

    private function assertProductOwnership(Vendor $vendor, Product $product): void
    {
        if ($product->vendor_id !== $vendor->id) {
            throw new DomainException(
                'promotion.product_not_found',
                'Produit introuvable.',
                404,
            );
        }
    }

    private function assertPromotionOwnership(Vendor $vendor, ProductPromotion $promotion): void
    {
        if ($promotion->vendor_id !== $vendor->id) {
            throw new DomainException(
                'promotion.not_found',
                'Promotion introuvable.',
                404,
            );
        }
    }

    private function assertValidPercent(int $percent): void
    {
        if ($percent < 1 || $percent > 99) {
            throw new DomainException(
                'promotion.percent_invalid',
                'Le pourcentage de réduction doit être compris entre 1 et 99.',
                422,
            );
        }
    }

    private function assertValidPrice(Product $product, int $promoPrice): void
    {
        if ($promoPrice < 1 || $promoPrice >= (int) $product->price) {
            throw new DomainException(
                'promotion.price_invalid',
                'Le prix promo doit être strictement inférieur au prix du produit.',
                422,
            );
        }
    }

    private function assertValidPeriod(Carbon $startsAt, Carbon $endsAt): void
    {
        if ($endsAt->lessThanOrEqualTo($startsAt)) {
            throw new DomainException(
                'promotion.period_invalid',
                'La date de fin doit être postérieure à la date de début.',
                422,
            );
        }
    }

    private function assertNoOverlap(Product $product, Carbon $startsAt, Carbon $endsAt, ?string $excludeId = null): void
    {
        $overlaps = $product->promotions()
            ->where('is_active', true)
            ->where('starts_at', '<=', $endsAt)
            ->where('ends_at', '>=', $startsAt)
            ->when($excludeId !== null, fn ($query) => $query->whereKeyNot($excludeId))
            ->exists();

        if ($overlaps) {
            throw new DomainException(
                'promotion.overlap',
                'Une autre promotion active chevauche cette période pour ce produit.',
                409,
            );
        }
    }
}
