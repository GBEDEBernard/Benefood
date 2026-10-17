<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\DeliveryZone;
use App\Models\Neighborhood;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

/**
 * Gestion du référentiel de quartiers (villes + quartiers).
 *
 * Une ville n'est pas une entité à part : elle apparaît dès qu'un quartier lui
 * est rattaché. Les quartiers alimentent la recherche par localité, les
 * sélecteurs d'adresse/colis et le calcul de distance. Comme les zones, ils
 * sont désactivés, jamais supprimés, pour préserver l'historique.
 */
class AdminLocationsController extends Controller
{
    public function index(): View
    {
        $this->authorize('manage', User::class);

        $neighborhoods = Neighborhood::with('deliveryZone')
            ->orderBy('city')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        return view('admin.locations.index', [
            'neighborhoods' => $neighborhoods,
            'cities' => $neighborhoods->groupBy('city'),
        ]);
    }

    public function create(): View
    {
        $this->authorize('manage', User::class);

        return view('admin.locations.form', [
            'neighborhood' => null,
            'zones' => DeliveryZone::orderBy('city')->orderBy('sort_order')->get(),
            'cities' => $this->existingCities(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $this->validated($request);

        Neighborhood::create($data);

        return redirect()->route('admin.locations.index')->with('success', 'Le quartier « '.$data['name'].' » a été créé.');
    }

    public function edit(Neighborhood $location): View
    {
        $this->authorize('manage', User::class);

        return view('admin.locations.form', [
            'neighborhood' => $location,
            'zones' => DeliveryZone::orderBy('city')->orderBy('sort_order')->get(),
            'cities' => $this->existingCities(),
        ]);
    }

    public function update(Request $request, Neighborhood $location): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $this->validated($request, $location);

        $location->update($data);

        return redirect()->route('admin.locations.index')->with('success', 'Le quartier « '.$location->name.' » a été mis à jour.');
    }

    public function toggleActive(Neighborhood $location): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $location->update(['is_active' => ! $location->is_active]);

        return back()->with('success', 'Le quartier « '.$location->name.' » est '.($location->is_active ? 'actif' : 'inactif').'.');
    }

    public function destroy(Neighborhood $location): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $location->is_active) {
            return redirect()->route('admin.locations.index')->with('error', 'Ce quartier est déjà inactif.');
        }

        $location->update(['is_active' => false]);

        return redirect()->route('admin.locations.index')->with('success', 'Le quartier « '.$location->name.' » a été désactivé.');
    }

    /**
     * Valide les champs d'un quartier (création ou mise à jour).
     *
     * @return array<string, mixed>
     */
    private function validated(Request $request, ?Neighborhood $neighborhood = null): array
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120', Rule::unique('neighborhoods', 'name')
                ->where(fn ($query) => $query->where('city', $request->input('city')))
                ->ignore($neighborhood?->id)],
            'city' => ['required', 'string', 'max:120'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'delivery_zone_id' => ['nullable', 'exists:delivery_zones,id'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $data['city'] = trim((string) $data['city']);
        $data['is_active'] = $request->boolean('is_active', $neighborhood?->is_active ?? true);

        return $data;
    }

    /**
     * Villes déjà présentes dans le référentiel (proposées à la création).
     *
     * @return list<string>
     */
    private function existingCities(): array
    {
        return Neighborhood::query()
            ->distinct()
            ->orderBy('city')
            ->pluck('city')
            ->all();
    }
}
