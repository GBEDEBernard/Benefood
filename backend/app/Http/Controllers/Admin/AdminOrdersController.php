<?php

namespace App\Http\Controllers\Admin;

use App\Enums\OrderStatus;
use App\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\User;
use App\Models\Vendor;
use App\Services\OrderService;
use Illuminate\Database\Eloquent\Builder;
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
    private const PER_PAGE_OPTIONS = [10, 20, 50];

    private const STATUS_FILTERS = ['awaiting_payment', 'in_progress', 'delivered', 'cancelled'];

    public function __construct(private readonly OrderService $orders) {}

    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $status = $this->statusFilter($request->query('status'));
        $search = trim((string) $request->query('q'));
        $vendorId = $this->filterValue($request->query('vendor_id'));
        $from = $this->dateFilter($request->query('from'));
        $to = $this->dateFilter($request->query('to'));
        $perPage = $this->perPage($request->integer('per_page', 20));

        $query = Order::query()->with([
            'user:id,name,phone,avatar_path',
            'vendor:id,business_name,logo_url',
            'payment:id,order_id,status',
        ]);
        $this->applyFilters($query, $search, $vendorId, $from, $to);
        $this->applyStatusFilter($query, $status);

        $countQuery = Order::query();
        $this->applyFilters($countQuery, $search, $vendorId, $from, $to);

        $orders = $query->latest('created_at')->latest('id')->paginate($perPage)->withQueryString();

        return view('admin.orders.index', [
            'orders' => $orders,
            'vendors' => Vendor::orderBy('business_name')->get(['id', 'business_name']),
            'counts' => $this->statusCounts($countQuery),
            'filters' => [
                'q' => $search !== '' ? $search : null,
                'status' => $status,
                'vendor_id' => $vendorId,
                'from' => $from,
                'to' => $to,
                'per_page' => $perPage,
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
            'items.product.images',
            'statusHistory',
            'payment',
            'financials',
            'delivery.driverProfile.user',
            'refunds.executor',
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

    private function applyFilters(
        Builder $query,
        string $search,
        ?string $vendorId,
        ?string $from,
        ?string $to,
    ): void {
        if ($search !== '') {
            $query->where(function (Builder $query) use ($search): void {
                $query->where('reference', 'like', "%{$search}%")
                    ->orWhereHas('user', fn (Builder $user) => $user->where('name', 'like', "%{$search}%"))
                    ->orWhereHas('vendor', fn (Builder $vendor) => $vendor->where('business_name', 'like', "%{$search}%"));
            });
        }

        if ($vendorId !== null) {
            $query->where('vendor_id', $vendorId);
        }

        if ($from !== null) {
            $query->whereDate('created_at', '>=', $from);
        }

        if ($to !== null) {
            $query->whereDate('created_at', '<=', $to);
        }
    }

    private function applyStatusFilter(Builder $query, ?string $status): void
    {
        if ($status === null) {
            return;
        }

        $statuses = match ($status) {
            'in_progress' => $this->inProgressStatuses(),
            'cancelled' => $this->cancelledStatuses(),
            default => [$status],
        };

        $query->whereIn('status', $statuses);
    }

    /** @return array<string, int> */
    private function statusCounts(Builder $query): array
    {
        $countsByStatus = $query->clone()
            ->selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        return [
            'all' => (int) $countsByStatus->sum(),
            'awaiting_payment' => (int) $countsByStatus->get(OrderStatus::AwaitingPayment->value, 0),
            'in_progress' => collect($this->inProgressStatuses())
                ->sum(fn (string $status): int => (int) $countsByStatus->get($status, 0)),
            'delivered' => (int) $countsByStatus->get(OrderStatus::Delivered->value, 0),
            'cancelled' => collect($this->cancelledStatuses())
                ->sum(fn (string $status): int => (int) $countsByStatus->get($status, 0)),
        ];
    }

    /** @return array<int, string> */
    private function inProgressStatuses(): array
    {
        return [
            OrderStatus::Paid->value,
            OrderStatus::Accepted->value,
            OrderStatus::Preparing->value,
            OrderStatus::Ready->value,
            OrderStatus::Assigned->value,
            OrderStatus::PickedUp->value,
            OrderStatus::InDelivery->value,
        ];
    }

    /** @return array<int, string> */
    private function cancelledStatuses(): array
    {
        return [
            OrderStatus::Cancelled->value,
            OrderStatus::Refunded->value,
        ];
    }

    private function statusFilter(mixed $status): ?string
    {
        if (! is_string($status) || ! in_array($status, self::STATUS_FILTERS, true)) {
            return null;
        }

        return $status;
    }

    private function perPage(int $perPage): int
    {
        return in_array($perPage, self::PER_PAGE_OPTIONS, true) ? $perPage : 20;
    }

    private function filterValue(mixed $value): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $value = trim($value);

        return $value !== '' ? $value : null;
    }

    private function dateFilter(mixed $value): ?string
    {
        if (! is_string($value) || ! preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $value, $matches)) {
            return null;
        }

        return checkdate((int) $matches[2], (int) $matches[3], (int) $matches[1]) ? $value : null;
    }
}
