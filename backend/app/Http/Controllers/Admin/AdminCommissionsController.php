<?php

namespace App\Http\Controllers\Admin;

use App\Enums\ParcelStatus;
use App\Enums\PaymentStatus;
use App\Http\Controllers\Controller;
use App\Models\CommissionRate;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\User;
use App\Models\Vendor;
use App\Services\PlatformPricingSettings;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

/**
 * Phase 16 — Taux de commission porteuse (J138).
 *
 * Historique des taux appliqués (validation, clôture) + revenu de commission
 * mensuel issu des order_financials.
 */
class AdminCommissionsController extends Controller
{
    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = CommissionRate::query()->with('creator');

        if ($scope = $request->query('scope')) {
            $query->where('is_active', $scope === 'active');
        }

        $rates = $query->orderByDesc('effective_from')->paginate(20)->withQueryString();

        $orderRevenue = Order::query()
            ->whereHas('financials')
            ->join('order_financials', 'order_financials.order_id', '=', 'orders.id')
            ->where('orders.status', 'not like', 'cancelled')
            ->where('orders.status', 'not like', 'refunded')
            ->selectRaw('DATE_FORMAT(orders.created_at, "%Y-%m") as month, SUM(order_financials.platform_amount) as total')
            ->groupBy('month')
            ->pluck('total', 'month');

        // Colis : commission livreur + frais fixes de création payés par l'expéditeur.
        $parcelRevenue = Parcel::query()
            ->where('payment_status', PaymentStatus::Confirmed->value)
            ->where('status', '!=', ParcelStatus::Cancelled->value)
            ->selectRaw('DATE_FORMAT(created_at, "%Y-%m") as month, SUM(platform_amount + creation_fee) as total')
            ->groupBy('month')
            ->pluck('total', 'month');

        $monthlyRevenue = $orderRevenue->keys()
            ->merge($parcelRevenue->keys())
            ->unique()
            ->sortDesc()
            ->take(12)
            ->map(fn (string $month): object => (object) [
                'month' => $month,
                'total' => (int) ($orderRevenue[$month] ?? 0) + (int) ($parcelRevenue[$month] ?? 0),
            ])
            ->values();

        $platformSettings = app(PlatformPricingSettings::class)->all();

        $activeVendorRate = CommissionRate::query()
            ->where('is_active', true)
            ->where('effective_from', '<=', now())
            ->where(fn ($q) => $q->whereNull('effective_to')->orWhere('effective_to', '>=', now()))
            ->orderByDesc('effective_from')
            ->value('rate');

        return view('admin.commissions.index', [
            'rates' => $rates,
            'vendors' => Vendor::query()->with('settings')->orderBy('business_name')->get(),
            'platformSettings' => $platformSettings,
            'activeVendorRate' => $activeVendorRate !== null ? (int) $activeVendorRate : $platformSettings['vendor_commission_rate'],
            'monthlyRevenue' => $monthlyRevenue,
            'filters' => [
                'scope' => $request->query('scope'),
            ],
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'rate' => ['required', 'integer', 'min:0', 'max:100'],
            'effective_from' => ['nullable', 'date'],
            'effective_to' => ['nullable', 'date', 'after_or_equal:effective_from'],
            'notes' => ['nullable', 'string', 'max:500'],
        ]);

        $effectiveFrom = Carbon::parse($data['effective_from'] ?? now());

        DB::transaction(function () use ($data, $effectiveFrom): void {
            if (! $effectiveFrom->isFuture()) {
                CommissionRate::query()
                    ->where('is_active', true)
                    ->where('effective_from', '<=', now())
                    ->where(fn ($q) => $q->whereNull('effective_to')->orWhere('effective_to', '>=', now()))
                    ->update(['is_active' => false, 'effective_to' => $effectiveFrom]);
            }

            CommissionRate::create([
                'rate' => $data['rate'],
                'effective_from' => $effectiveFrom,
                'effective_to' => $data['effective_to'] ?? null,
                'is_active' => true,
                'notes' => $data['notes'] ?? null,
                'created_by' => Auth::id(),
            ]);

            if (! $effectiveFrom->isFuture()) {
                app(PlatformPricingSettings::class)->update(
                    ['vendor_commission_rate' => $data['rate']],
                    Auth::id(),
                );
            }
        });

        return redirect()->route('admin.commissions.index')
            ->with('success', $effectiveFrom->isFuture()
                ? 'Le nouveau taux vendeur est programmé.'
                : 'Le nouveau taux vendeur est appliqué aux nouvelles commandes.');
    }

    public function destroy(CommissionRate $rate): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if ($rate->is_active) {
            $rate->update(['is_active' => false, 'effective_to' => now()]);
        }

        return back()->with('success', 'Le taux a été clôturé. Les nouvelles commandes utilisent désormais le taux en vigueur ou le taux vendeur par défaut.');
    }

    public function updatePlatformSettings(Request $request, PlatformPricingSettings $settings): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'service_fee_rate' => ['required', 'integer', 'min:0', 'max:100'],
            'delivery_commission_rate' => ['required', 'integer', 'min:0', 'max:100'],
            'parcel_commission_rate' => ['required', 'integer', 'min:0', 'max:100'],
            'parcel_creation_fee' => ['sometimes', 'integer', 'min:0'],
            'gateway_fee_basis_points' => ['required', 'integer', 'min:0', 'max:10000'],
            'minimum_payout' => ['required', 'integer', 'min:0'],
        ]);

        $settings->update($data, $request->user()->id);

        return back()->with('success', 'Les commissions et frais ont été mis à jour. Ils s\'appliquent immédiatement aux nouvelles commandes et aux nouveaux colis.');
    }

    public function updateVendorRate(Request $request, Vendor $vendor): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'commission_exception_rate' => ['nullable', 'integer', 'min:0', 'max:100'],
        ]);

        $vendor->settings()->updateOrCreate(
            ['vendor_id' => $vendor->id],
            ['commission_exception_rate' => $data['commission_exception_rate'] ?? null],
        );

        return back()->with('success', 'La commission spécifique de la boutique a été mise à jour et s\'applique dès la prochaine vente.');
    }
}
