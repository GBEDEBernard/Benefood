<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\FinanceService;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * Back-office — wallet interne Béninfood (commissions et frais plateforme).
 */
class AdminPlatformWalletController extends Controller
{
    public function __construct(private readonly FinanceService $finance) {}

    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        if (! $request->user()->hasPermission('payments.refund')) {
            abort(403, 'Vous n\'avez pas le droit de consulter le wallet plateforme.');
        }

        $wallet = $this->finance->platformWallet();

        $transactions = $wallet->transactions()
            ->orderByDesc('created_at')
            ->paginate(30)
            ->withQueryString();

        $totalCredited = (int) $wallet->transactions()
            ->where('type', 'credit')
            ->sum('amount');

        $monthCredited = (int) $wallet->transactions()
            ->where('type', 'credit')
            ->where('created_at', '>=', now()->startOfMonth())
            ->sum('amount');

        return view('admin.platform-wallet.index', compact(
            'wallet',
            'transactions',
            'totalCredited',
            'monthCredited',
        ));
    }
}
