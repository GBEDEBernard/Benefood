<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * M5 — Tarifs de livraison (J71/J74).
 *
 * Un tarif par zone (vendor_id null) ; un tarif spécifique vendeur peut être
 * configuré pour surcharger le tarif par défaut.
 */
class AdminRatesController extends Controller
{
    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = DeliveryRate::with(['zone', 'vendor']);

        if ($request->filled('zone_id')) {
            $query->where('zone_id', $request->query('zone_id'));
        }

        if ($request->filled('vendor_id')) {
            $query->where('vendor_id', $request->query('vendor_id'));
        }

        if ($request->filled('scope')) {
            $query->where('vendor_id', $request->query('scope') === 'vendor' ? '!=' : '=', null);
        }

        $rates = $query->orderBy('created_at', 'desc')->paginate(20)->withQueryString();

        return view('admin.rates.index', [
            'rates' => $rates,
            'zones' => DeliveryZone::orderBy('name')->get(),
            'vendors' => Vendor::orderBy('business_name')->get(['id', 'business_name']),
            'filters' => [
                'zone_id' => $request->query('zone_id'),
                'vendor_id' => $request->query('vendor_id'),
                'scope' => $request->query('scope'),
            ],
        ]);
    }

    public function create(): View
    {
        $this->authorize('manage', User::class);

        return view('admin.rates.form', [
            'rate' => null,
            'zones' => DeliveryZone::orderBy('name')->get(),
            'vendors' => Vendor::orderBy('business_name')->get(['id', 'business_name']),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $this->validated($request);

        DeliveryRate::create($data);

        return redirect()->route('admin.rates.index')->with('success', 'Le tarif a été créé.');
    }

    public function edit(DeliveryRate $rate): View
    {
        $this->authorize('manage', User::class);

        return view('admin.rates.form', [
            'rate' => $rate,
            'zones' => DeliveryZone::orderBy('name')->get(),
            'vendors' => Vendor::orderBy('business_name')->get(['id', 'business_name']),
        ]);
    }

    public function update(Request $request, DeliveryRate $rate): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $rate->update($this->validated($request));

        return redirect()->route('admin.rates.index')->with('success', 'Le tarif a été mis à jour.');
    }

    public function toggleActive(DeliveryRate $rate): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $rate->update(['is_active' => ! $rate->is_active]);

        return back()->with('success', 'Le tarif est '.($rate->is_active ? 'actif' : 'inactif').'.');
    }

    public function destroy(DeliveryRate $rate): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $rate->is_active) {
            return redirect()->route('admin.rates.index')->with('error', 'Ce tarif est déjà désactivé.');
        }

        $rate->update(['is_active' => false]);

        return redirect()->route('admin.rates.index')->with('success', 'Le tarif a été désactivé.');
    }

    private function validated(Request $request): array
    {
        $data = $request->validate([
            'zone_id' => ['required', 'uuid', 'exists:delivery_zones,id'],
            'vendor_id' => ['nullable', 'uuid', 'exists:vendors,id'],
            'price' => ['required', 'integer', 'min:0'],
            'effective_from' => ['nullable', 'date'],
            'effective_to' => ['nullable', 'date', 'after_or_equal:effective_from'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $data['is_active'] = $request->boolean('is_active', true);

        return $data;
    }
}
