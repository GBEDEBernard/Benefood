<?php

namespace App\Http\Controllers\Admin;

use App\Enums\RefundStatus;
use App\Http\Controllers\Controller;
use App\Models\Refund;
use App\Models\User;
use App\Services\RefundService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

/**
 * Phase 16 — Remboursements au back-office porteuse (J140).
 *
 * Suivi des remboursements en attente et exécution manuelle par la porteuse
 * (permission `payments.refund`). Le rapprochement est assuré par la commande
 * artisan `ReconcilePayments`.
 */
class AdminRefundsController extends Controller
{
    public function __construct(private readonly RefundService $refunds) {}

    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = Refund::query()->with(['order.vendor', 'order.user', 'payment']);

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($search = trim((string) $request->query('q'))) {
            $query->where(function ($q) use ($search) {
                $q->whereHas('order', fn ($o) => $o->where('reference', 'like', "%{$search}%"))
                    ->orWhereHas('order.user', fn ($u) => $u->where('name', 'like', "%{$search}%"));
            });
        }

        $refunds = $query->orderByDesc('created_at')->paginate(20)->withQueryString();

        return view('admin.refunds.index', [
            'refunds' => $refunds,
            'counts' => [
                'all' => Refund::count(),
                'pending' => Refund::where('status', RefundStatus::Pending->value)->count(),
                'executed' => Refund::where('status', RefundStatus::Executed->value)->count(),
                'failed' => Refund::where('status', RefundStatus::Failed->value)->count(),
            ],
            'filters' => [
                'q' => $request->query('q'),
                'status' => $status,
            ],
        ]);
    }

    public function show(Request $request, Refund $refund): View
    {
        $this->authorize('manage', User::class);

        $refund->load(['order.vendor', 'order.user', 'order.items', 'payment', 'executor']);

        return view('admin.refunds.show', [
            'refund' => $refund,
            'canExecute' => $request->user()->hasPermission('payments.refund'),
        ]);
    }

    public function execute(Request $request, Refund $refund): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $request->user()->hasPermission('payments.refund')) {
            abort(403, 'Vous n\'avez pas le droit d\'exécuter des remboursements.');
        }

        if ($refund->status === RefundStatus::Executed) {
            return back()->with('error', 'Ce remboursement est déjà exécuté.');
        }

        $this->refunds->executeRefund($refund, (string) Auth::id());

        return back()->with('success', 'Le remboursement a été exécuté.');
    }
}
