<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use App\Models\Vendor;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class VendorProductController extends Controller
{
    public function index(Request $request, Vendor $vendor): JsonResponse
    {
        $perPage = (int) $request->query('per_page', 15);
        $perPage = $perPage > 0 && $perPage <= 200 ? $perPage : 15;

        $q = trim((string) $request->query('q', ''));

        $query = $vendor->products()->where('is_active', true);

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
            'image_main' => ['sometimes', 'nullable', 'string'],
            'is_active' => ['sometimes', 'boolean'],
            'is_available' => ['sometimes', 'boolean'],
        ]);

        $data['vendor_id'] = $vendor->id;

        $product = Product::create($data);

        return Api::created(new ProductResource($product));
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

        $product->update($data);

        return Api::ok(new ProductResource($product->fresh()));
    }

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

        $product->delete();

        return Api::noContent();
    }
}
