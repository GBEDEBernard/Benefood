<?php

namespace App\Http\Controllers\Api;

use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use App\Models\Category;
use App\Models\Product;
use App\Support\Api;
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
            ->orderable()
            ->whereHas('vendor', fn ($vendor) => $vendor->where('status', VendorStatus::Active->value));

        $q = trim((string) $request->query('q'));
        if ($q !== '') {
            $query->where(function ($builder) use ($q) {
                $builder->where('products.name', 'like', "%{$q}%")
                    ->orWhere('products.description', 'like', "%{$q}%")
                    ->orWhereHas('vendor', fn ($vendor) => $vendor->where('business_name', 'like', "%{$q}%"));
            });
        }

        if ($request->filled('category_id')) {
            $ids = $this->categoryIdsRecursively((string) $request->query('category_id'));
            $query->whereIn('products.category_id', $ids);
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

        $query->orderByRaw(...$this->orderByForSort((string) $request->query('sort', '-created_at')));

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

        $product->load(['vendor', 'category', 'images']);

        return Api::ok(new ProductResource($product));
    }

    /**
     * @param  Collection<int, Category>  $categories
     * @return array<int, array{id: string, name: string, slug: string, icon_path: ?string, children: array<mixed>}>
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
                    'sort_order' => $category->sort_order,
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
