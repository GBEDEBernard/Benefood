<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\Vendor;
use App\Services\CatalogService;
use App\Services\MediaService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * CRUD produits côté vendeur (M4 — J62 à J65).
 *
 * La suppression logique est privilégiée : "destroy" désactive le produit
 * (désactivation sans suppression, J21/J65) pour préserver l'historique.
 */
class VendorProductController extends Controller
{
    public function __construct(
        private readonly CatalogService $catalog,
        private readonly MediaService $media,
    ) {}

    public function index(Request $request, Vendor $vendor): JsonResponse
    {
        $perPage = (int) $request->query('per_page', 15);
        $perPage = $perPage > 0 && $perPage <= 200 ? $perPage : 15;

        $q = trim((string) $request->query('q', ''));

        $query = $vendor->products()->where('is_active', true)->with(['category', 'images']);

        if ($q !== '') {
            $query->where('name', 'like', "%{$q}%");
        }

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->query('category_id'));
        }

        if ($request->filled('min_price')) {
            $query->where('price', '>=', (int) $request->query('min_price'));
        }

        if ($request->filled('max_price')) {
            $query->where('price', '<=', (int) $request->query('max_price'));
        }

        if ($request->filled('is_available')) {
            $query->where('is_available', (bool) $request->query('is_available'));
        }

        $paginator = $query->orderBy('name')->paginate($perPage);

        $items = ProductResource::collection(collect($paginator->items()))->resolve();

        return Api::ok($items, [
            'pagination' => [
                'total' => $paginator->total(),
                'per_page' => $paginator->perPage(),
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
            ],
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        if (! $user->hasPermission('vendor.products.manage')) {
            return Api::error('Accès refusé.', 'forbidden', 403);
        }

        $data = $request->validate([
            'category_id' => ['required', 'uuid'],
            'name' => ['required', 'string', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string'],
            'unit' => ['sometimes', 'string', 'max:20'],
            'price' => ['required', 'integer', 'min:0'],
            'stock_qty' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
            'is_available' => ['sometimes', 'boolean'],
        ]);

        $product = $this->catalog->storeProduct($vendor, $data, auth()->id());

        return Api::created(new ProductResource($product->load(['vendor', 'category', 'images'])));
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null || $product->vendor_id !== $vendor->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        if (! $user->hasPermission('vendor.products.manage')) {
            return Api::error('Accès refusé.', 'forbidden', 403);
        }

        $data = $request->validate([
            'category_id' => ['sometimes', 'uuid'],
            'name' => ['sometimes', 'string', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string'],
            'unit' => ['sometimes', 'string', 'max:20'],
            'price' => ['sometimes', 'integer', 'min:0'],
            'stock_qty' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'image_main' => ['sometimes', 'nullable', 'string'],
            'is_active' => ['sometimes', 'boolean'],
            'is_available' => ['sometimes', 'boolean'],
        ]);

        $product = $this->catalog->updateProduct($product, $data, auth()->id());

        return Api::ok(new ProductResource($product->load(['vendor', 'category', 'images'])));
    }

    /**
     * Désactivation sans suppression (J65) : le produit n'apparaît plus au catalogue,
     * mais reste dans l'historique des commandes.
     */
    public function destroy(Request $request, Product $product): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null || $product->vendor_id !== $vendor->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        if (! $user->hasPermission('vendor.products.manage')) {
            return Api::error('Accès refusé.', 'forbidden', 403);
        }

        $this->catalog->deactivate($product);

        return Api::noContent();
    }

    public function uploadImage(Request $request, Product $product): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null || $product->vendor_id !== $vendor->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        if (! $user->hasPermission('vendor.products.manage')) {
            return Api::error('Accès refusé.', 'forbidden', 403);
        }

        $data = $request->validate([
            'image' => ['required', 'file', 'image', 'mimes:jpeg,png,webp', 'max:5120'],
            'is_main' => ['sometimes', 'boolean'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
        ]);

        $stored = $this->media->storeProductImage($request->file('image'), $product->vendor_id, $product->id);
        $isMain = (bool) ($data['is_main'] ?? false) || $product->images()->count() === 0;

        if ($isMain) {
            ProductImage::where('product_id', $product->id)->update(['is_main' => false]);
        }

        $image = $product->images()->create([
            'path' => $stored['path'],
            'thumb_path' => $stored['thumb_path'],
            'mime' => $stored['mime'],
            'size' => $stored['size'],
            'is_main' => $isMain,
            'sort_order' => (int) ($data['sort_order'] ?? 0),
        ]);

        if ($isMain) {
            $product->update(['image_main' => $stored['path']]);
        }

        return Api::created([
            'id' => $image->id,
            'url' => Storage::disk('public')->url($stored['path']),
            'thumb_url' => Storage::disk('public')->url($stored['thumb_path']),
            'is_main' => $image->is_main,
            'sort_order' => $image->sort_order,
        ]);
    }

    public function removeImage(Request $request, Product $product, ProductImage $image): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null || $product->vendor_id !== $vendor->id || $image->product_id !== $product->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        if (! $user->hasPermission('vendor.products.manage')) {
            return Api::error('Accès refusé.', 'forbidden', 403);
        }

        $this->media->deleteProductImage($image->path);
        $wasMain = $image->is_main;
        $image->delete();

        if ($wasMain) {
            $next = $product->images()->whereKeyNot($image->id)->orderBy('sort_order')->first();

            $product->update(['image_main' => $next?->path]);
            if ($next !== null) {
                $next->update(['is_main' => true]);
            }
        }

        return Api::noContent();
    }
}
