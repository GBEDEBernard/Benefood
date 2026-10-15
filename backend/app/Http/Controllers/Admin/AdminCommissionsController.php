<?php

namespace App\Http\Controllers\Admin;

use App\Enums\ParcelStatus;
use App\Enums\PaymentStatus;
use App\Http\Controllers\Controller;
use App\Models\CommissionRate;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
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
            ->selectRaw('DATE_FORMAT(orders.created_at, "%Y-%m") as month, SUM(order_financials.commission_amount) as total')
            ->groupBy('month')
            ->pluck('total', 'month');

        // Colis : la commission porteuse est la part plateforme (20 % des frais).
        $parcelRevenue = Parcel::query()
            ->where('payment_status', PaymentStatus::Confirmed->value)
            ->where('status', '!=', ParcelStatus::Cancelled->value)
            ->selectRaw('DATE_FORMAT(created_at, "%Y-%m") as month, SUM(platform_amount) as total')
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

        return view('admin.commissions.index', [
            'rates' => $rates,
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

        DB::transaction(function () use ($data): void {
            CommissionRate::where('is_active', true)->update(['is_active' => false]);
            CommissionRate::create([
                'rate' => $data['rate'],
                'effective_from' => $data['effective_from'] ?? now(),
                'effective_to' => $data['effective_to'] ?? null,
                'is_active' => true,
                'notes' => $data['notes'] ?? null,
                'created_by' => Auth::id(),
            ]);
        });

        return redirect()->route('admin.commissions.index')->with('success', 'Nouveau taux de commission enregistré.');
    }

    public function destroy(CommissionRate $rate): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if ($rate->is_active) {
            $rate->update(['is_active' => false, 'effective_to' => now()]);
        }

        return back()->with('success', 'Le taux a été clôturé.');
    }
}
