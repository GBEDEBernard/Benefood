<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AdminPaymentsController extends Controller
{
    public function index(Request $request): View
    {
        // Back-office manage permission is evaluated on the User/admin policy
        $this->authorize('manage', \App\Models\User::class);

        $query = Payment::query()->with('order');

        if ($q = $request->query('q')) {
            $query->where('provider_transaction_id', 'like', "%{$q}%");
        }

        $payments = $query->orderByDesc('created_at')->paginate(20)->withQueryString();

        return view('admin.payments.index', ['payments' => $payments]);
    }

    public function show(Payment $payment): View
    {
        $this->authorize('manage', \App\Models\User::class);

        $payment->load('order');

        return view('admin.payments.show', ['payment' => $payment]);
    }
}
