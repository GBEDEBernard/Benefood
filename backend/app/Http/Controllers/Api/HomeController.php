<?php

namespace App\Http\Controllers\Api;

use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use App\Models\Category;
use App\Models\Product;
use App\Models\Vendor;
use App\Support\Api;
use Illuminate\Http\JsonResponse;

/**
 * Accueil client (M5 — J77) : catégories, produits mis en avant et boutiques.
 */
class HomeController extends Controller
{
    public function index(): JsonResponse
    {
        $categories = Category::query()
            ->where('is_active', true)
            ->whereNull('parent_id')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get()
            ->map(fn (Category $category) => [
                'id' => $category->id,
                'name' => $category->name,
                'slug' => $category->slug,
                'icon_path' => $category->icon_path,
            ])
            ->values();

        $products = Product::query()
            ->with(['vendor', 'category'])
            ->orderable()
            ->whereHas('vendor', fn ($vendor) => $vendor->where('status', VendorStatus::Active->value)->whereNull('closed_at'))
            ->latest('products.created_at')
            ->limit(12)
            ->get();

        $vendors = Vendor::query()
            ->with(['settings'])
            ->where('status', VendorStatus::Active->value)
            ->whereNull('closed_at')
            ->orderByDesc('approved_at')
            ->limit(6)
            ->get()
            ->map(fn (Vendor $vendor) => [
                'id' => $vendor->id,
                'business_name' => $vendor->business_name,
                'description' => $vendor->description,
                'logo_url' => $vendor->logo_url,
                'cover_url' => $vendor->cover_url,
                'city' => $vendor->city,
                'is_open' => $vendor->isOpenNow(),
            ])
            ->values();

        return Api::ok([
            'categories' => $categories,
            'featured_products' => ProductResource::collection($products)->resolve(),
            'vendors' => $vendors,
        ]);
    }
}
