<?php

namespace App\Http\Controllers\Admin;

use App\Enums\PayoutBatchStatus;
use App\Enums\PayoutStatus;
use App\Http\Controllers\Controller;
use App\Models\Payout;
use App\Models\PayoutBatch;
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

        $this->payouts->sendToGateway($payout, (string) Auth::id());

        return back()->with('success', 'Retrait traité (virement FedaPay envoyé ou validé manuellement).');
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

    // ---------------- Retraits groupés (Mode B) ----------------

    public function batches(Request $request): View
    {
        $this->authorize('manage', User::class);

        $batches = PayoutBatch::query()
            ->with('creator')
            ->withCount('payouts')
            ->orderByDesc('created_at')
            ->paginate(20)
            ->withQueryString();

        return view('admin.payouts.batches.index', [
            'batches' => $batches,
            'counts' => [
                'all' => PayoutBatch::count(),
                'processing' => PayoutBatch::where('status', PayoutBatchStatus::Processing->value)->count(),
                'executed' => PayoutBatch::where('status', PayoutBatchStatus::Executed->value)->count(),
                'partially_failed' => PayoutBatch::where('status', PayoutBatchStatus::PartiallyFailed->value)->count(),
                'failed' => PayoutBatch::where('status', PayoutBatchStatus::Failed->value)->count(),
            ],
            'totals' => [
                'executed' => (int) PayoutBatch::where('status', PayoutBatchStatus::Executed->value)->sum('total_amount'),
            ],
        ]);
    }

    public function showBatch(Request $request, PayoutBatch $batch): View
    {
        $this->authorize('manage', User::class);

        $payouts = $batch->payouts()->with('wallet')->orderByDesc('created_at')->paginate(20)->withQueryString();

        return view('admin.payouts.batches.show', compact('batch', 'payouts'));
    }

    public function createBatch(Request $request): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $request->user()->hasPermission('payments.refund')) {
            abort(403, 'Vous n\'avez pas le droit de créer des lots de retraits.');
        }

        $data = $request->validate([
            'payout_ids' => ['required', 'array', 'min:1'],
            'payout_ids.*' => ['string', 'uuid', 'exists:payouts,id'],
            'label' => ['nullable', 'string', 'max:120'],
        ]);

        $batch = $this->payouts->createBatch($data['payout_ids'], (string) Auth::id(), $data['label'] ?? null);

        return redirect()
            ->route('admin.payouts.batches.show', $batch)
            ->with('success', 'Lot n°'.$batch->reference.' créé : '.$batch->payouts_count.' retrait(s) à exécuter.');
    }

    public function executeBatch(Request $request, PayoutBatch $batch): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $request->user()->hasPermission('payments.refund')) {
            abort(403, 'Vous n\'avez pas le droit d\'exécuter des retraits.');
        }

        $this->payouts->executeBatch($batch, (string) Auth::id());

        return back()->with('success', 'Lot exécuté : tous les retraits en attente ont été marqués versés.');
    }

    public function failBatchPayout(Request $request, PayoutBatch $batch, Payout $payout): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $request->user()->hasPermission('payments.refund')) {
            abort(403, 'Vous n\'avez pas le droit de gérer les retraits.');
        }

        $reason = $request->validate(['reason' => ['nullable', 'string', 'max:255']])['reason'] ?? null;

        $this->payouts->failBatchPayout($batch, $payout, $reason, (string) Auth::id());

        return back()->with('success', 'Retrait marqué en échec : le montant a été re-crédité au wallet.');
    }
}
