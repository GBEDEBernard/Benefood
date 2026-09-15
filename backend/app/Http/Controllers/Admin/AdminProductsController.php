<?php

namespace App\Http\Controllers\Admin;

use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\User;
use App\Models\Vendor;
use App\Services\CatalogService;
use App\Services\MediaService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

/**
 * Phase 08 — Gestion du catalogue produits depuis le back-office (J61-J65).
 *
 * La porteuse consulte, crée et pilote les produits et leurs médias. La
 * désactivation est privilégiée à la suppression pour préserver l'historique.
 */
class AdminProductsController extends Controller
{
    public function __construct(
        private readonly CatalogService $catalog,
        private readonly MediaService $media,
    ) {}

    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = Product::query()->with(['vendor', 'category', 'images']);

        $q = trim((string) $request->query('q'));
        if ($q !== '') {
            $query->where(function ($builder) use ($q) {
                $builder->where('products.name', 'like', "%{$q}%")
                    ->orWhere('products.description', 'like', "%{$q}%")
                    ->orWhereHas('vendor', fn ($vendor) => $vendor->where('business_name', 'like', "%{$q}%"));
            });
        }

        if ($request->filled('category_id')) {
            $query->where('products.category_id', $request->query('category_id'));
        }

        if ($request->filled('vendor_id')) {
            $query->where('products.vendor_id', $request->query('vendor_id'));
        }

        if ($request->filled('status')) {
            $query->where('products.is_active', $request->query('status') === 'active');
        }

        if ($request->filled('availability')) {
            $available = $request->query('availability') === 'available';
            $query->where(function ($builder) use ($available) {
                if ($available) {
                    $builder->whereNull('products.stock_qty')->orWhere('products.stock_qty', '>', 0);
                } else {
                    $builder->whereNotNull('products.stock_qty')->where('products.stock_qty', '<=', 0);
                }
            });
        }

        $products = $query->orderByDesc('products.created_at')->paginate(20)->withQueryString();

        $counts = [
            'all' => Product::count(),
            'active' => Product::where('is_active', true)->count(),
            'inactive' => Product::where('is_active', false)->count(),
            'out_of_stock' => Product::where('is_active', true)
                ->where(fn ($builder) => $builder->whereNotNull('stock_qty')->where('stock_qty', '<=', 0))
                ->count(),
        ];

        return view('admin.products.index', [
            'products' => $products,
            'counts' => $counts,
            'categories' => Category::withCount('products')->orderBy('name')->get(),
            'vendors' => Vendor::orderBy('business_name')->get(['id', 'business_name']),
            'filters' => [
                'q' => $request->query('q'),
                'category_id' => $request->query('category_id'),
                'vendor_id' => $request->query('vendor_id'),
                'status' => $request->query('status'),
                'availability' => $request->query('availability'),
            ],
        ]);
    }

    public function create(): View
    {
        $this->authorize('manage', User::class);

        return view('admin.products.form', [
            'product' => null,
            'categories' => Category::where('is_active', true)->orderBy('name')->get(),
            'vendors' => Vendor::where('status', VendorStatus::Active->value)->orderBy('business_name')->get(['id', 'business_name']),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'vendor_id' => ['required', 'uuid', 'exists:vendors,id'],
            'category_id' => ['required', 'uuid', 'exists:categories,id'],
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'unit' => ['sometimes', 'string', 'max:20'],
            'price' => ['required', 'integer', 'min:0'],
            'stock_qty' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
            'image' => ['sometimes', 'file', 'image', 'mimes:jpeg,png,webp', 'max:5120'],
        ]);

        $vendor = Vendor::findOrFail($data['vendor_id']);

        $product = $this->catalog->storeProduct($vendor, array_filter([
            'category_id' => $data['category_id'],
            'name' => $data['name'],
            'description' => $data['description'] ?? null,
            'unit' => $data['unit'] ?? 'unit',
            'price' => $data['price'],
            'stock_qty' => $data['stock_qty'] ?? null,
            'is_active' => $request->boolean('is_active', true),
        ], fn ($value) => $value !== null), Auth::id());

        if ($request->hasFile('image')) {
            $this->addImage($request, $product);
        }

        return redirect()->route('admin.products.show', $product)->with('success', 'Le produit « '.$product->name.' » a été créé.');
    }

    public function show(Product $product): View
    {
        $this->authorize('manage', User::class);

        $product->load(['vendor.user', 'category', 'images', 'priceHistory.changedBy', 'stockLogs']);

        return view('admin.products.show', [
            'product' => $product,
            'categories' => Category::where('is_active', true)->orderBy('name')->get(),
        ]);
    }

    public function edit(Product $product): View
    {
        $this->authorize('manage', User::class);

        return view('admin.products.form', [
            'product' => $product->load(['vendor', 'images']),
            'categories' => Category::orderBy('name')->get(),
            'vendors' => Vendor::orderBy('business_name')->get(['id', 'business_name']),
        ]);
    }

    public function update(Request $request, Product $product): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'vendor_id' => ['sometimes', 'uuid', 'exists:vendors,id'],
            'category_id' => ['sometimes', 'uuid', 'exists:categories,id'],
            'name' => ['sometimes', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'unit' => ['sometimes', 'string', 'max:20'],
            'price' => ['sometimes', 'integer', 'min:0'],
            'stock_qty' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
            'is_available' => ['sometimes', 'boolean'],
            'image' => ['sometimes', 'file', 'image', 'mimes:jpeg,png,webp', 'max:5120'],
        ]);

        unset($data['image']);

        if (array_key_exists('vendor_id', $data) && $data['vendor_id'] !== $product->vendor_id) {
            $product->update(['vendor_id' => $data['vendor_id']]);
        }

        $this->catalog->updateProduct($product, array_filter(
            $data,
            fn ($value) => $value !== null && $value !== [],
        ), Auth::id());

        if ($request->hasFile('image')) {
            $this->addImage($request, $product->fresh());
        }

        return redirect()->route('admin.products.show', $product)->with('success', 'Le produit « '.$product->name.' » a été mis à jour.');
    }

    /**
     * Désactivation sans suppression (J65).
     */
    public function destroy(Product $product): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $product->is_active) {
            return redirect()->route('admin.products.index')->with('error', 'Ce produit est déjà désactivé.');
        }

        $this->catalog->deactivate($product);

        return redirect()->route('admin.products.index')->with('success', 'Le produit « '.$product->name.' » a été désactivé.');
    }

    public function toggleActive(Product $product): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $active = ! (bool) $product->is_active;
        $this->catalog->toggleActive($product, $active);

        return back()->with('success', 'Le produit « '.$product->name.' » est '.($active ? 'activé' : 'désactivé').'.');
    }

    public function setAvailability(Request $request, Product $product): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'is_available' => ['required', 'boolean'],
            'stock_qty' => ['nullable', 'integer', 'min:0'],
        ]);

        $this->catalog->setAvailability($product, (bool) $data['is_available'], $data['stock_qty'] ?? null);

        return back()->with('success', 'La disponibilité de « '.$product->name.' » a été mise à jour.');
    }

    public function addImage(Request $request, Product $product)
    {
        $this->authorize('manage', User::class);

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

        return $image;
    }

    public function removeImage(Product $product, ProductImage $image): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if ($image->product_id !== $product->id) {
            abort(404);
        }

        $this->media->deleteProductImage($image->path);
        $wasMain = $image->is_main;
        $image->delete();

        if ($wasMain) {
            $next = $product->images()->first();
            $product->update(['image_main' => $next?->path]);
            $next?->update(['is_main' => true]);
        }

        return back()->with('success', 'L\'image a été supprimée.');
    }
}
