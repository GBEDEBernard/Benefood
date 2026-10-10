<?php

namespace App\Http\Controllers\Api;

use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use App\Models\Category;
use App\Models\Product;
use App\Models\Review;
use App\Models\Vendor;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

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
                'is_active' => $category->is_active,
            ])
            ->values();

        $products = Product::query()
            ->with(['vendor', 'category'])
            ->withAvg('reviews as reviews_avg_rating', 'rating')
            ->withCount(['reviews', 'favorites'])
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
            ->get();

        $vendorIds = $vendors->pluck('id');

        // Note moyenne et nombre d'avis calculés depuis les avis des commandes.
        $ratings = Review::query()
            ->join('orders', 'orders.id', '=', 'reviews.order_id')
            ->whereIn('orders.vendor_id', $vendorIds)
            ->groupBy('orders.vendor_id')
            ->select([
                'orders.vendor_id as vendor_id',
                DB::raw('AVG(reviews.rating) as average_rating'),
                DB::raw('COUNT(reviews.id) as reviews_count'),
            ])
            ->get()
            ->keyBy('vendor_id');

        // Catégorie du dernier produit publié : sous-titre « Plats locaux • Cotonou ».
        $categoryNames = Category::query()->pluck('name', 'id');
        $latestCategories = Product::query()
            ->orderable()
            ->whereIn('vendor_id', $vendorIds)
            ->latest('products.created_at')
            ->get(['vendor_id', 'category_id'])
            ->unique('vendor_id')
            ->mapWithKeys(fn (Product $product) => [
                $product->vendor_id => $categoryNames->get($product->category_id),
            ]);

        $vendors = $vendors
            ->map(function (Vendor $vendor) use ($ratings, $latestCategories) {
                $stat = $ratings->get($vendor->id);

                return [
                    'id' => $vendor->id,
                    'business_name' => $vendor->business_name,
                    'description' => $vendor->description,
                    'logo_url' => $this->mediaUrl($vendor->logo_url),
                    'cover_url' => $this->mediaUrl($vendor->cover_url),
                    'city' => $vendor->city,
                    'is_open' => $vendor->isOpenNow(),
                    'category' => $latestCategories->get($vendor->id),
                    'rating' => $stat !== null ? round((float) $stat->average_rating, 1) : null,
                    'reviews_count' => $stat !== null ? (int) $stat->reviews_count : 0,
                    'prep_minutes' => (int) ($vendor->settings?->max_preparation_minutes ?? 30),
                ];
            })
            ->values();

        return Api::ok([
            'categories' => $categories,
            'featured_products' => ProductResource::collection($products)->resolve(),
            'vendors' => $vendors,
        ]);
    }

    /**
     * Normalise un chemin de média en URL publique (chemins relatifs legacy
     * compris, URL absolues renvoyées telles quelles).
     */
    private function mediaUrl(?string $path): ?string
    {
        if ($path === null || $path === '') {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        return Storage::disk('public')->url($path);
    }
}
