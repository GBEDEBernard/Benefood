<?php

namespace App\Http\Controllers\Admin;

use App\Enums\PayoutStatus;
use App\Http\Controllers\Controller;
use App\Models\Payout;
use App\Models\User;
use App\Services\PayoutService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

/**
 * Back-office — Wallets & retraits (cahier de conception v1.0).
 *
 * Suivi des demandes de retrait des vendeurs/livreurs et exécution manuelle
 * du virement vers Mobile Money (permission `payments.refund`, comme les
 * remboursements).
 */
class AdminPayoutsController extends Controller
{
    public function __construct(private readonly PayoutService $payouts) {}

    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = Payout::query()->with('wallet');

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        $payouts = $query->orderByDesc('created_at')->paginate(20)->withQueryString();

        return view('admin.payouts.index', [
            'payouts' => $payouts,
            'counts' => [
                'all' => Payout::count(),
                'pending' => Payout::where('status', PayoutStatus::Pending->value)->count(),
                'executed' => Payout::where('status', PayoutStatus::Executed->value)->count(),
                'failed' => Payout::where('status', PayoutStatus::Failed->value)->count(),
            ],
            'totals' => [
                'pending' => (int) Payout::where('status', PayoutStatus::Pending->value)->sum('amount'),
                'executed' => (int) Payout::where('status', PayoutStatus::Executed->value)->sum('amount'),
            ],
            'filters' => ['status' => $status],
        ]);
    }

    public function execute(Request $request, Payout $payout): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $request->user()->hasPermission('payments.refund')) {
            abort(403, 'Vous n\'avez pas le droit d\'exécuter des retraits.');
        }

        if ($payout->status === PayoutStatus::Executed) {
            return back()->with('error', 'Ce retrait est déjà exécuté.');
        }

        $this->payouts->execute($payout, (string) Auth::id());

        return back()->with('success', 'Le retrait a été marqué comme versé.');
    }

    public function fail(Request $request, Payout $payout): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $request->user()->hasPermission('payments.refund')) {
            abort(403, 'Vous n\'avez pas le droit de gérer les retraits.');
        }

        if ($payout->status === PayoutStatus::Failed) {
            return back()->with('error', 'Ce retrait est déjà en échec.');
        }

        $this->payouts->fail($payout);

        return back()->with('success', 'Retrait marqué en échec : le montant a été re-crédité au wallet.');
    }
}
