<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\DistancePricingRule;
use App\Models\User;
use App\Services\PlatformPricingSettings;
use Database\Seeders\DistancePricingRulesSeeder;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

class AdminPricingController extends Controller
{
    public function index(PlatformPricingSettings $settings): View
    {
        $this->authorize('manage', User::class);

        app(DistancePricingRulesSeeder::class)->run();

        return view('admin.pricing.index', [
            'settings' => $settings->all(),
            'orderRules' => $this->rules(DistancePricingRule::ORDER_DELIVERY),
            'parcelRules' => $this->rules(DistancePricingRule::PARCEL_DELIVERY),
        ]);
    }

    public function updateSettings(Request $request, PlatformPricingSettings $settings): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'order_minimum_fee' => ['required', 'integer', 'min:0'],
            'order_default_fee' => ['required', 'integer', 'min:0'],
            'parcel_minimum_fee' => ['required', 'integer', 'min:0'],
            'parcel_default_fee' => ['required', 'integer', 'min:0'],
            'parcel_creation_fee' => ['sometimes', 'integer', 'min:0'],
        ]);

        $settings->update($data, $request->user()->id);

        return back()->with('success', 'Les frais minimums et tarifs de repli ont été enregistrés.');
    }

    public function storeRule(Request $request): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $this->validatedRule($request);
        $this->assertValidThresholds($data['service_type'], $data['max_km']);

        $data['sort_order'] = ((int) DistancePricingRule::query()
            ->where('service_type', $data['service_type'])
            ->max('sort_order')) + 1;
        $data['is_active'] = true;
        DistancePricingRule::create($data);

        return back()->with('success', 'Le palier de distance a été créé.');
    }

    public function updateRule(Request $request, DistancePricingRule $rule): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $this->validatedRule($request, $rule->service_type);
        $this->assertValidThresholds($rule->service_type, $data['max_km'], $rule->id);
        $rule->update($data);

        return back()->with('success', 'Le palier de distance a été mis à jour.');
    }

    public function destroyRule(DistancePricingRule $rule): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $remainingRules = DistancePricingRule::query()
            ->where('service_type', $rule->service_type)
            ->where('id', '!=', $rule->id)
            ->get();

        if ($remainingRules->isEmpty() || ! $remainingRules->contains(fn (DistancePricingRule $item) => $item->max_km === null)) {
            return back()->with('error', 'Conservez au moins un palier final sans limite de distance.');
        }

        $rule->delete();

        return back()->with('success', 'Le palier de distance a été supprimé.');
    }

    /** @return array<string, mixed> */
    private function validatedRule(Request $request, ?string $forcedServiceType = null): array
    {
        $data = $request->validate([
            'service_type' => [$forcedServiceType === null ? 'required' : 'sometimes', 'in:order,parcel'],
            'max_km' => ['nullable', 'numeric', 'gt:0', 'max:10000'],
            'base_fee' => ['required', 'integer', 'min:0'],
            'per_km' => ['required', 'integer', 'min:0'],
            'discount_percentage' => ['required', 'integer', 'min:0', 'max:100'],
        ]);

        $data['service_type'] = $forcedServiceType ?? $data['service_type'];
        $data['max_km'] = ($data['max_km'] ?? '') === '' ? null : (float) $data['max_km'];

        return $data;
    }

    private function assertValidThresholds(string $serviceType, ?float $maxKm, ?string $exceptId = null): void
    {
        $rules = DistancePricingRule::query()
            ->where('service_type', $serviceType)
            ->when($exceptId !== null, fn ($query) => $query->where('id', '!=', $exceptId))
            ->get();

        if ($maxKm === null && $rules->contains(fn (DistancePricingRule $rule) => $rule->max_km === null)) {
            throw ValidationException::withMessages(['max_km' => 'Un seul palier final sans limite est autorisé.']);
        }

        if ($maxKm !== null && $rules->contains(fn (DistancePricingRule $rule) => $rule->max_km !== null && (float) $rule->max_km === $maxKm)) {
            throw ValidationException::withMessages(['max_km' => 'Un palier existe déjà pour cette distance maximale.']);
        }

        if ($maxKm !== null && ! $rules->contains(fn (DistancePricingRule $rule) => $rule->max_km === null)) {
            throw ValidationException::withMessages(['max_km' => 'Conservez ou créez un palier final sans limite de distance.']);
        }
    }

    private function rules(string $serviceType)
    {
        return DistancePricingRule::query()
            ->where('service_type', $serviceType)
            ->orderByRaw('max_km IS NULL')
            ->orderBy('max_km')
            ->get();
    }
}
