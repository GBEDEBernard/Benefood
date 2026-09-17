<?php

namespace App\Http\Controllers\Admin;

use App\Enums\OrderStatus;
use App\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\User;
use App\Models\Vendor;
use App\Services\OrderService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

/**
 * Phase 16 — Gestion des commandes au back-office porteuse (J137).
 *
 * Liste filtrable, détail complet et seule action autorisée : annulation
 * (motif obligatoire, remboursement décidé) — permission `admin.orders.cancel`.
 */
class AdminOrdersController extends Controller
{
    public function __construct(private readonly OrderService $orders) {}

    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = Order::query()->with(['user', 'vendor', 'payment']);

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($search = trim((string) $request->query('q'))) {
            $query->where(function ($q) use ($search) {
                $q->where('reference', 'like', "%{$search}%")
                    ->orWhereHas('user', fn ($u) => $u->where('name', 'like', "%{$search}%"))
                    ->orWhereHas('vendor', fn ($v) => $v->where('business_name', 'like', "%{$search}%"));
            });
        }

        if ($vendorId = $request->query('vendor_id')) {
            $query->where('vendor_id', $vendorId);
        }

        if ($from = $request->query('from')) {
            $query->whereDate('created_at', '>=', $from);
        }

        if ($to = $request->query('to')) {
            $query->whereDate('created_at', '<=', $to);
        }

        $orders = $query->orderByDesc('created_at')->paginate(20)->withQueryString();

        return view('admin.orders.index', [
            'orders' => $orders,
            'vendors' => Vendor::orderBy('business_name')->get(['id', 'business_name']),
            'statuses' => OrderStatus::cases(),
            'counts' => [
                'all' => Order::count(),
                'awaiting_payment' => Order::where('status', OrderStatus::AwaitingPayment->value)->count(),
                'in_progress' => Order::whereIn('status', [
                    OrderStatus::Paid->value,
                    OrderStatus::Accepted->value,
                    OrderStatus::Preparing->value,
                    OrderStatus::Ready->value,
                    OrderStatus::Assigned->value,
                    OrderStatus::PickedUp->value,
                    OrderStatus::InDelivery->value,
                ])->count(),
                'delivered' => Order::where('status', OrderStatus::Delivered->value)->count(),
                'cancelled' => Order::whereIn('status', [OrderStatus::Cancelled->value, OrderStatus::Refunded->value])->count(),
            ],
            'filters' => [
                'q' => $request->query('q'),
                'status' => $status,
                'vendor_id' => $vendorId,
                'from' => $request->query('from'),
                'to' => $request->query('to'),
            ],
        ]);
    }

    public function show(Request $request, Order $order): View
    {
        $this->authorize('manage', User::class);

        $order->load([
            'user',
            'vendor',
            'zone',
            'items',
            'statusHistory',
            'payment',
            'financials',
            'delivery',
            'refunds',
            'complaints',
        ]);

        return view('admin.orders.show', [
            'order' => $order,
            'canCancel' => $request->user()->hasPermission('admin.orders.cancel'),
        ]);
    }

    public function cancel(Request $request, Order $order): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $request->user()->hasPermission('admin.orders.cancel')) {
            abort(403, 'Vous n\'avez pas le droit d\'annuler des commandes.');
        }

        $data = $request->validate([
            'reason' => ['required', 'string', 'min:3', 'max:500'],
            'refund_amount' => ['nullable', 'integer', 'min:0'],
        ]);

        try {
            $this->orders->cancelByPorteuse(
                $order,
                (string) Auth::id(),
                $data['reason'],
                $data['refund_amount'] ?? null,
            );
        } catch (DomainException $e) {
            return back()->with('error', $e->getMessage())->withInput();
        }

        return back()->with('success', "La commande « {$order->reference} » a été annulée.");
    }
}
