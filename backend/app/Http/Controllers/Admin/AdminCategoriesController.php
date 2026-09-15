<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\View\View;

/**
 * Phase 08 — Gestion des catégories et sous-catégories (J61).
 *
 * Les catégories sont pilotées par la porteuse ; une catégorie peut être
 * désactivée sans suppression (l'arbre et l'historique sont préservés).
 */
class AdminCategoriesController extends Controller
{
    public function index(): View
    {
        $this->authorize('manage', User::class);

        $categories = Category::withCount(['products', 'children'])
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        return view('admin.categories.index', ['categories' => $categories]);
    }

    public function create(): View
    {
        $this->authorize('manage', User::class);

        return view('admin.categories.form', [
            'category' => null,
            'parents' => Category::whereNull('parent_id')->orderBy('name')->get(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $this->validated($request);
        $data['slug'] = $this->uniqueSlug($data['name']);

        Category::create($data);

        return redirect()->route('admin.categories.index')->with('success', 'La catégorie « '.$data['name'].' » a été créée.');
    }

    public function edit(Category $category): View
    {
        $this->authorize('manage', User::class);

        return view('admin.categories.form', [
            'category' => $category,
            'parents' => Category::whereNull('parent_id')->whereKeyNot($category->id)->orderBy('name')->get(),
        ]);
    }

    public function update(Request $request, Category $category): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $category->update($this->validated($request));

        return redirect()->route('admin.categories.index')->with('success', 'La catégorie « '.$category->name.' » a été mise à jour.');
    }

    public function toggleActive(Category $category): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $category->update(['is_active' => ! $category->is_active]);

        return back()->with('success', 'La catégorie « '.$category->name.' » est '.($category->is_active ? 'active' : 'inactive').'.');
    }

    public function destroy(Category $category): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $category->is_active) {
            return redirect()->route('admin.categories.index')->with('error', 'Cette catégorie est déjà inactive.');
        }

        $category->update(['is_active' => false]);

        return redirect()->route('admin.categories.index')->with('success', 'La catégorie « '.$category->name.' » a été désactivée.');
    }

    private function validated(Request $request): array
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'parent_id' => ['nullable', 'uuid', 'exists:categories,id'],
            'icon_path' => ['nullable', 'string', 'max:255'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $data['is_active'] = $request->boolean('is_active', true);

        return $data;
    }

    private function uniqueSlug(string $name): string
    {
        $base = Str::slug($name) ?: 'categorie';
        $slug = $base;
        $i = 0;

        while (Category::where('slug', $slug)->exists()) {
            $slug = $base.'-'.++$i;
        }

        return $slug;
    }
}
