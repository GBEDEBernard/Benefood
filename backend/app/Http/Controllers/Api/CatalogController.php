<?php

namespace App\Http\Controllers\Api;

use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use App\Models\Category;
use App\Models\Product;
use App\Support\Api;
use App\Support\Geo;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Catalogue public (M4 — J67) : recherche, filtres et fiches produits côté client.
 */
class CatalogController extends Controller
{
    public function categories(): JsonResponse
    {
        $roots = Category::query()
            ->withCount('products')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        $tree = $this->buildTree($roots);

        return Api::ok($tree);
    }

    public function index(Request $request): JsonResponse
    {
        $perPage = (int) $request->query('per_page', 15);
        $perPage = $perPage > 0 && $perPage <= 100 ? $perPage : 15;

        $query = Product::query()
            ->with(['vendor', 'category', 'images'])
            ->withAvg('reviews as reviews_avg_rating', 'rating')
            ->withCount(['reviews', 'favorites'])
            ->orderable()
            ->whereHas('vendor', fn ($vendor) => $vendor->where('status', VendorStatus::Active->value));

        // Recherche « par km » : distance au vendeur, calculée en SQL.
        $latitude = Geo::coordinate($request->query('latitude'), -90, 90);
        $longitude = Geo::coordinate($request->query('longitude'), -180, 180);
        $hasLocation = $latitude !== null && $longitude !== null;

        $distanceSql = null;
        $distanceBindings = [];

        if ($hasLocation) {
            [$expression, $distanceBindings] = Geo::distanceKm('vendors.latitude', 'vendors.longitude', $latitude, $longitude);
            $distanceSql = "(select {$expression} from vendors where vendors.id = products.vendor_id)";
            $query->selectRaw("{$distanceSql} as distance_km", $distanceBindings);
        }

        $q = trim((string) $request->query('q'));
        if ($q !== '') {
            $query->where(function ($builder) use ($q) {
                $builder->where('products.name', 'like', "%{$q}%")
                    ->orWhere('products.description', 'like', "%{$q}%")
                    ->orWhereHas('vendor', fn ($vendor) => $vendor
                        ->where('business_name', 'like', "%{$q}%")
                        ->orWhere('city', 'like', "%{$q}%")
                        ->orWhere('area', 'like', "%{$q}%"));
            });
        }

        if ($request->filled('city')) {
            $query->whereHas('vendor', fn ($vendor) => $vendor->where('city', $request->query('city')));
        }

        if ($request->filled('area')) {
            $query->whereHas('vendor', fn ($vendor) => $vendor->where('area', $request->query('area')));
        }

        if ($request->filled('category_id')) {
            $ids = $this->categoryIdsRecursively((string) $request->query('category_id'));
            $query->whereIn('products.category_id', $ids);
        }

        if ($hasLocation && $request->filled('radius_km')) {
            $radius = (float) $request->query('radius_km');
            if ($radius > 0) {
                $query->whereRaw("{$distanceSql} <= ?", [...$distanceBindings, $radius]);
            }
        }

        if ($request->filled('vendor_id')) {
            $query->where('products.vendor_id', $request->query('vendor_id'));
        }

        if ($request->filled('min_price')) {
            $query->where('products.price', '>=', (int) $request->query('min_price'));
        }

        if ($request->filled('max_price')) {
            $query->where('products.price', '<=', (int) $request->query('max_price'));
        }

        if ($request->filled('in_stock')) {
            $inStock = (bool) $request->query('in_stock');
            $query->when($inStock, fn ($builder) => $builder->where(fn ($stock) => $stock->whereNull('products.stock_qty')->orWhere('products.stock_qty', '>', 0)))
                ->when(! $inStock, fn ($builder) => $builder->where(fn ($stock) => $stock->whereNotNull('products.stock_qty')->where('products.stock_qty', '<=', 0)));
        }

        $sort = (string) $request->query('sort', '-created_at');

        if ($hasLocation && $sort === 'distance') {
            $query->orderByRaw("{$distanceSql} asc", $distanceBindings);
        } else {
            $query->orderByRaw(...$this->orderByForSort($sort));
        }

        $paginator = $query->paginate($perPage);

        $items = ProductResource::collection($paginator->items())->resolve();

        return Api::ok($items, [
            'pagination' => [
                'total' => $paginator->total(),
                'per_page' => $paginator->perPage(),
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
            ],
        ]);
    }

    public function show(Product $product): JsonResponse
    {
        if (! $product->isOrderable()) {
            return Api::error('Produit introuvable.', 'not_found', 404);
        }

        if ($product->vendor->status !== VendorStatus::Active->value) {
            return Api::error('Produit introuvable.', 'not_found', 404);
        }

        $product->load(['vendor', 'category', 'images'])->loadCount(['favorites', 'reviews']);

        return Api::ok(new ProductResource($product));
    }

    /**
     * @param  Collection<int, Category>  $categories
     * @return array<int, array{id: string, name: string, slug: string, icon_path: ?string, products_count: int, children: array<mixed>}>
     */
    private function buildTree($categories): array
    {
        $grouped = $categories->groupBy(fn (Category $category) => $category->parent_id ?? '_root');

        $build = function (string $parentKey) use ($grouped, &$build): array {
            return $grouped->get($parentKey, collect())
                ->reject(fn (Category $category) => ! $category->is_active)
                ->sortBy([['sort_order', 'asc'], ['name', 'asc']])
                ->map(fn (Category $category) => [
                    'id' => $category->id,
                    'parent_id' => $category->parent_id,
                    'name' => $category->name,
                    'slug' => $category->slug,
                    'icon_path' => $category->icon_path,
                    'is_active' => $category->is_active,
                    'sort_order' => $category->sort_order,
                    'products_count' => (int) ($category->products_count ?? 0),
                    'children' => $build($category->id),
                ])
                ->values()
                ->all();
        };

        return $build('_root');
    }

    /**
     * Retourne l'id de la catégorie et ceux de toutes ses descendants.
     *
     * @return array<int, string>
     */
    private function categoryIdsRecursively(string $categoryId): array
    {
        $ids = [$categoryId];

        $all = DB::table('categories')->select('id', 'parent_id')->get();

        do {
            $added = false;

            foreach ($all as $row) {
                if (in_array($row->parent_id, $ids, true) && ! in_array($row->id, $ids, true)) {
                    $ids[] = $row->id;
                    $added = true;
                }
            }
        } while ($added);

        return $ids;
    }

    /**
     * @return array{string, array<int, mixed>}
     */
    private function orderByForSort(string $sort): array
    {
        return match ($sort) {
            'price_asc' => ['products.price asc', []],
            'price_desc' => ['products.price desc', []],
            'name' => ['products.name asc', []],
            'created_at' => ['products.created_at asc', []],
            default => ['products.created_at desc', []],
        };
    }
}
