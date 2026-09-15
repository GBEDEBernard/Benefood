<?php

namespace App\Http\Controllers\Admin;

use App\Enums\ZoneIdentificationMode;
use App\Http\Controllers\Controller;
use App\Models\DeliveryZone;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * M5 — Gestion des zones tarifaires de livraison (J69/J70/J74).
 *
 * La porteuse crée et maintient les zones sans déployer de code. Les zones
 * sont désactivées, jamais supprimées, pour préserver l'historique.
 */
class AdminZonesController extends Controller
{
    public function index(): View
    {
        $this->authorize('manage', User::class);

        $zones = DeliveryZone::withCount(['rates', 'vendors'])
            ->orderBy('city')
            ->orderBy('sort_order')
            ->get();

        return view('admin.zones.index', ['zones' => $zones]);
    }

    public function create(): View
    {
        $this->authorize('manage', User::class);

        return view('admin.zones.form', ['zone' => null, 'modes' => ZoneIdentificationMode::cases()]);
    }

    public function store(Request $request): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'city' => ['required', 'string', 'max:255'],
            'identification_mode' => ['required', 'string', 'in:'.implode(',', array_column(ZoneIdentificationMode::cases(), 'value'))],
            'terms' => ['nullable', 'string'],
            'center_latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'center_longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'radius_km' => ['nullable', 'numeric', 'min:0', 'max:2000'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $data['terms'] = $this->parseTerms($request->input('terms'));
        $data['is_active'] = $request->boolean('is_active', true);

        DeliveryZone::create($data);

        return redirect()->route('admin.zones.index')->with('success', 'La zone « '.$data['name'].' » a été créée.');
    }

    public function edit(DeliveryZone $zone): View
    {
        $this->authorize('manage', User::class);

        return view('admin.zones.form', ['zone' => $zone, 'modes' => ZoneIdentificationMode::cases()]);
    }

    public function update(Request $request, DeliveryZone $zone): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'city' => ['sometimes', 'required', 'string', 'max:255'],
            'identification_mode' => ['sometimes', 'required', 'string', 'in:'.implode(',', array_column(ZoneIdentificationMode::cases(), 'value'))],
            'terms' => ['nullable', 'string'],
            'center_latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'center_longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'radius_km' => ['nullable', 'numeric', 'min:0', 'max:2000'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $data['terms'] = $request->has('terms') ? $this->parseTerms($request->input('terms')) : $zone->terms;
        $data['is_active'] = $request->boolean('is_active', $zone->is_active);

        $zone->update($data);

        return redirect()->route('admin.zones.index')->with('success', 'La zone « '.$zone->name.' » a été mise à jour.');
    }

    public function toggleActive(DeliveryZone $zone): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $zone->update(['is_active' => ! $zone->is_active]);

        return back()->with('success', 'La zone « '.$zone->name.' » est '.($zone->is_active ? 'active' : 'inactive').'.');
    }

    public function destroy(DeliveryZone $zone): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $zone->is_active) {
            return redirect()->route('admin.zones.index')->with('error', 'Cette zone est déjà inactive.');
        }

        $zone->update(['is_active' => false]);

        return redirect()->route('admin.zones.index')->with('success', 'La zone « '.$zone->name.' » a été désactivée.');
    }

    /**
     * Transforme la saisie texte (un terme par ligne) en liste normalisée.
     *
     * @return array<int, string>|null
     */
    private function parseTerms(mixed $terms): ?array
    {
        if (is_array($terms)) {
            $items = $terms;
        } else {
            $items = preg_split('/\r\n|\r|\n/', (string) $terms) ?: [];
        }

        $items = array_values(array_filter(array_map(fn ($t) => trim((string) $t), $items), fn ($t) => $t !== ''));

        return $items === [] ? null : $items;
    }
}
