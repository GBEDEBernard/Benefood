<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductPromotionResource;
use App\Models\Product;
use App\Models\ProductPromotion;
use App\Models\Vendor;
use App\Services\PromotionService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Promotions de produits du vendeur connecté.
 */
class VendorPromotionController extends Controller
{
    public function __construct(private readonly PromotionService $promotions) {}

    public function index(Request $request): JsonResponse
    {
        $vendor = $this->vendorFor($request);

        if ($vendor === null) {
            return $this->notOnboarded();
        }

        $permissionError = $this->assertPermission($request);
        if ($permissionError !== null) {
            return $permissionError;
        }

        $items = $vendor->promotions()
            ->with('product')
            ->orderByDesc('starts_at')
            ->get();

        return Api::ok(ProductPromotionResource::collection($items)->resolve());
    }

    public function store(Request $request, Product $product): JsonResponse
    {
        $vendor = $this->vendorFor($request);

        if ($vendor === null) {
            return $this->notOnboarded();
        }

        $permissionError = $this->assertPermission($request);
        if ($permissionError !== null) {
            return $permissionError;
        }

        $data = $request->validate([
            'promo_price' => ['sometimes', 'integer', 'min:1'],
            'discount_percent' => ['sometimes', 'integer', 'min:1', 'max:99'],
            'starts_at' => ['required', 'date'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
            'title' => ['sometimes', 'nullable', 'string', 'max:120'],
            'is_active' => ['sometimes', 'boolean'],
        ], [
            'promo_price.integer' => 'Le prix promo doit être un montant entier.',
            'promo_price.min' => 'Le prix promo doit être supérieur à 0.',
            'discount_percent.integer' => 'Le pourcentage doit être un entier.',
            'discount_percent.min' => 'Le pourcentage doit être supérieur à 0.',
            'discount_percent.max' => 'Le pourcentage ne peut pas atteindre 100.',
            'starts_at.required' => 'La date de début est requise.',
            'ends_at.required' => 'La date de fin est requise.',
            'ends_at.after' => 'La date de fin doit être postérieure à la date de début.',
        ]);

        if (! isset($data['promo_price']) && ! isset($data['discount_percent'])) {
            return Api::error(
                'Renseignez un prix promo ou un pourcentage de réduction.',
                'promotion.discount_required',
                422,
            );
        }

        $data['promo_price'] = isset($data['discount_percent'])
            ? PromotionService::priceFromPercent((int) $product->price, (int) $data['discount_percent'])
            : (int) $data['promo_price'];

        $promotion = $this->promotions->create($vendor, $product, $data);

        return Api::created(new ProductPromotionResource($promotion->load('product')));
    }

    /**
     * Applique un pourcentage à un ou plusieurs plats, ou à toute la boutique.
     */
    public function bulk(Request $request): JsonResponse
    {
        $vendor = $this->vendorFor($request);

        if ($vendor === null) {
            return $this->notOnboarded();
        }

        $permissionError = $this->assertPermission($request);
        if ($permissionError !== null) {
            return $permissionError;
        }

        $data = $request->validate([
            'discount_percent' => ['required', 'integer', 'min:1', 'max:99'],
            'all_products' => ['sometimes', 'boolean'],
            'product_ids' => ['sometimes', 'array', 'min:1'],
            'product_ids.*' => ['string'],
            'starts_at' => ['required', 'date'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
            'title' => ['sometimes', 'nullable', 'string', 'max:120'],
            'is_active' => ['sometimes', 'boolean'],
        ], [
            'discount_percent.required' => 'Le pourcentage de réduction est requis.',
            'discount_percent.integer' => 'Le pourcentage doit être un entier.',
            'discount_percent.min' => 'Le pourcentage doit être supérieur à 0.',
            'discount_percent.max' => 'Le pourcentage ne peut pas atteindre 100.',
            'product_ids.min' => 'Sélectionnez au moins un plat.',
            'starts_at.required' => 'La date de début est requise.',
            'ends_at.required' => 'La date de fin est requise.',
            'ends_at.after' => 'La date de fin doit être postérieure à la date de début.',
        ]);

        if (empty($data['product_ids']) && empty($data['all_products'])) {
            return Api::error(
                'Sélectionnez au moins un plat ou choisissez tous les plats.',
                'promotion.target_required',
                422,
            );
        }

        $result = $this->promotions->createBulkFromPercent($vendor, $data);
        $result['created']->each(static fn (ProductPromotion $item): ProductPromotion => $item->load('product'));
        $promotions = ProductPromotionResource::collection($result['created'])->resolve();

        return Api::created([
            'promotions' => $promotions,
            'skipped' => $result['skipped'],
            'created_count' => count($promotions),
            'skipped_count' => count($result['skipped']),
        ], [
            'created' => count($promotions),
            'skipped' => count($result['skipped']),
        ]);
    }

    public function update(Request $request, ProductPromotion $promotion): JsonResponse
    {
        $vendor = $this->vendorFor($request);

        if ($vendor === null) {
            return $this->notOnboarded();
        }

        $permissionError = $this->assertPermission($request);
        if ($permissionError !== null) {
            return $permissionError;
        }

        if ($promotion->vendor_id !== $vendor->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'promo_price' => ['sometimes', 'integer', 'min:1'],
            'discount_percent' => ['sometimes', 'integer', 'min:1', 'max:99'],
            'starts_at' => ['sometimes', 'date'],
            'ends_at' => ['sometimes', 'date'],
            'title' => ['sometimes', 'nullable', 'string', 'max:120'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        if (isset($data['discount_percent'])) {
            $data['promo_price'] = PromotionService::priceFromPercent(
                (int) $promotion->product->price,
                (int) $data['discount_percent'],
            );
        }

        $promotion = $this->promotions->update($vendor, $promotion, $data);

        return Api::ok(new ProductPromotionResource($promotion));
    }

    public function toggle(Request $request, ProductPromotion $promotion): JsonResponse
    {
        $vendor = $this->vendorFor($request);

        if ($vendor === null) {
            return $this->notOnboarded();
        }

        $permissionError = $this->assertPermission($request);
        if ($permissionError !== null) {
            return $permissionError;
        }

        if ($promotion->vendor_id !== $vendor->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        return Api::ok(new ProductPromotionResource($this->promotions->toggle($vendor, $promotion)));
    }

    public function destroy(Request $request, ProductPromotion $promotion): JsonResponse
    {
        $vendor = $this->vendorFor($request);

        if ($vendor === null) {
            return $this->notOnboarded();
        }

        $permissionError = $this->assertPermission($request);
        if ($permissionError !== null) {
            return $permissionError;
        }

        if ($promotion->vendor_id !== $vendor->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $this->promotions->delete($vendor, $promotion);

        return Api::noContent();
    }

    private function vendorFor(Request $request): ?Vendor
    {
        return $request->user()?->vendor()->first();
    }

    private function assertPermission(Request $request): ?JsonResponse
    {
        if (! $request->user()?->hasPermission('vendor.products.manage')) {
            return Api::error('Accès refusé.', 'forbidden', 403);
        }

        return null;
    }

    private function notOnboarded(): JsonResponse
    {
        return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
    }
}
