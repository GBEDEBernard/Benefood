<?php

namespace App\Http\Controllers\Admin;

use App\Enums\ComplaintStatus;
use App\Enums\DriverStatus;
use App\Enums\OrderStatus;
use App\Enums\ParcelStatus;
use App\Enums\PaymentStatus;
use App\Enums\RefundStatus;
use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Models\Complaint;
use App\Models\DeliveryZone;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\OrderFinancial;
use App\Models\Parcel;
use App\Models\Product;
use App\Models\Refund;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

class AdminController extends Controller
{
    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $validated = $request->validate([
            'from' => ['nullable', 'date'],
            'to' => [
                'nullable',
                'date',
                'after_or_equal:from',
                function (string $attribute, mixed $value, \Closure $fail) use ($request): void {
                    $from = $request->input('from');

                    if ($value !== null && $from !== null && Carbon::parse($from)->diffInDays(Carbon::parse($value)) > 365) {
                        $fail('La période ne peut pas dépasser 366 jours.');
                    }
                },
            ],
        ]);

        $now = Carbon::now();
        $from = isset($validated['from']) ? Carbon::parse($validated['from'])->startOfDay() : $now->copy()->startOfMonth();
        $to = isset($validated['to']) ? Carbon::parse($validated['to'])->endOfDay() : $now->copy()->endOfMonth();

        $excludedStatuses = [OrderStatus::Draft->value, OrderStatus::AwaitingPayment->value, OrderStatus::Cancelled->value, OrderStatus::Refunded->value];
        $rangeOrders = Order::query()->whereBetween('orders.created_at', [$from, $to]);
        $successfulOrders = (clone $rangeOrders)
            ->whereNotIn('orders.status', $excludedStatuses)
            ->where('orders.payment_status', PaymentStatus::Confirmed->value);
        $ordersTotal = (clone $rangeOrders)->count();
        $revenueTotal = (int) (clone $successfulOrders)->sum('total');
        $orderCommissionTotal = (int) OrderFinancial::query()
            ->whereHas('order', fn (Builder $query) => $query->whereBetween('orders.created_at', [$from, $to])
                ->whereNotIn('orders.status', $excludedStatuses)
                ->where('orders.payment_status', PaymentStatus::Confirmed->value))
            ->sum('commission_amount');
        $parcelBase = Parcel::query()
            ->whereBetween('created_at', [$from, $to])
            ->where('payment_status', PaymentStatus::Confirmed->value)
            ->where('status', '!=', ParcelStatus::Cancelled->value);
        $parcelCommissionTotal = (int) (clone $parcelBase)->sum('platform_amount') + (int) (clone $parcelBase)->sum('creation_fee');

        $dailyRevenueRows = (clone $successfulOrders)
            ->selectRaw('DATE(orders.created_at) as day, SUM(orders.total) as amount')
            ->groupBy('day')
            ->orderBy('day')
            ->get()
            ->keyBy(fn ($row) => Carbon::parse($row->day)->format('Y-m-d'));
        $dailyCommissionRows = OrderFinancial::query()
            ->join('orders', 'orders.id', '=', 'order_financials.order_id')
            ->whereBetween('orders.created_at', [$from, $to])
            ->whereNotIn('orders.status', $excludedStatuses)
            ->where('orders.payment_status', PaymentStatus::Confirmed->value)
            ->selectRaw('DATE(orders.created_at) as day, SUM(order_financials.commission_amount) as amount')
            ->groupBy('day')
            ->get()
            ->keyBy(fn ($row) => Carbon::parse($row->day)->format('Y-m-d'));
        $dailyParcelCommissionRows = (clone $parcelBase)
            ->selectRaw('DATE(created_at) as day, SUM(platform_amount + creation_fee) as amount')
            ->groupBy('day')
            ->get()
            ->keyBy(fn ($row) => Carbon::parse($row->day)->format('Y-m-d'));

        $days = [];
        $dailyRevenue = [];
        $dailyCommissions = [];
        $cursor = $from->copy()->startOfDay();
        while ($cursor <= $to) {
            $key = $cursor->format('Y-m-d');
            $days[] = $cursor->translatedFormat($from->diffInDays($to) <= 45 ? 'd M' : 'd/m');
            $dailyRevenue[] = (int) ($dailyRevenueRows[$key]->amount ?? 0);
            $dailyCommissions[] = (int) ($dailyCommissionRows[$key]->amount ?? 0) + (int) ($dailyParcelCommissionRows[$key]->amount ?? 0);
            $cursor->addDay();
        }

        $vendorSummary = (clone $successfulOrders)
            ->join('vendors', 'vendors.id', '=', 'orders.vendor_id')
            ->select('vendors.id', 'vendors.business_name', 'vendors.logo_url')
            ->selectRaw('COUNT(orders.id) as orders_count, SUM(orders.total) as revenue')
            ->groupBy('vendors.id', 'vendors.business_name', 'vendors.logo_url')
            ->orderByDesc('revenue')
            ->limit(5)
            ->get();
        $clientSummary = (clone $successfulOrders)
            ->join('users', 'users.id', '=', 'orders.user_id')
            ->select('users.id', 'users.name', 'users.avatar_path')
            ->selectRaw('COUNT(orders.id) as orders_count, SUM(orders.total) as revenue')
            ->groupBy('users.id', 'users.name', 'users.avatar_path')
            ->orderByDesc('revenue')
            ->limit(5)
            ->get();
        $driverSummary = DB::table('deliveries')
            ->join('orders', 'orders.id', '=', 'deliveries.order_id')
            ->join('driver_profiles', 'driver_profiles.id', '=', 'deliveries.driver_profile_id')
            ->join('users', 'users.id', '=', 'driver_profiles.user_id')
            ->whereBetween('orders.created_at', [$from, $to])
            ->whereNotIn('orders.status', $excludedStatuses)
            ->where('orders.payment_status', PaymentStatus::Confirmed->value)
            ->select('users.id', 'users.name', 'users.avatar_path')
            ->selectRaw('COUNT(deliveries.id) as deliveries_count, SUM(deliveries.partner_amount) as revenue')
            ->groupBy('users.id', 'users.name', 'users.avatar_path')
            ->orderByDesc('revenue')
            ->limit(5)
            ->get();

        $statusRows = (clone $rangeOrders)->select('orders.status')->selectRaw('COUNT(*) as amount')->groupBy('orders.status')->pluck('amount', 'status');
        $paymentRows = (clone $successfulOrders)
            ->select('orders.payment_method')
            ->selectRaw('COUNT(orders.id) as orders_count, SUM(orders.total) as amount')
            ->groupBy('orders.payment_method')
            ->get()
            ->keyBy('payment_method');

        $kpis = [
            'orders_today' => ['value' => (clone $rangeOrders)->whereDate('orders.created_at', $now->toDateString())->count()],
            'orders_month' => ['value' => $ordersTotal],
            'orders_week' => ['value' => $ordersTotal, 'previous' => 0],
            'orders_trend' => null,
            'ca_today' => ['value' => (int) (clone $successfulOrders)->whereDate('orders.created_at', $now->toDateString())->sum('orders.total')],
            'ca_month' => ['value' => $revenueTotal],
            'ca_week' => ['value' => $revenueTotal, 'previous' => 0],
            'ca_trend' => null,
            'commissions_month' => $orderCommissionTotal + $parcelCommissionTotal,
            'active_vendors' => Vendor::where('status', VendorStatus::Active->value)->count(),
            'online_drivers' => DriverProfile::where('status', DriverStatus::Active->value)->where('available', true)->count(),
            'pending_refunds' => Refund::where('status', RefundStatus::Pending->value)->count(),
        ];

        // Alertes (J23 §4).
        $alerts = [];
        $alerts['pending_vendors'] = Vendor::whereIn('status', [
            VendorStatus::Registered->value,
            VendorStatus::PendingVerification->value,
        ])->count();
        $alerts['open_complaints'] = Complaint::whereIn('status', [
            ComplaintStatus::Open->value,
            ComplaintStatus::InProgress->value,
        ])->count();
        $alerts['awaiting_payment_orders'] = Order::where('status', OrderStatus::AwaitingPayment->value)
            ->where('payment_deadline_at', '>=', $now)
            ->count();
        $alerts['pending_refunds'] = $kpis['pending_refunds'];

        $latestOrders = Order::with(['vendor', 'user'])
            ->whereBetween('created_at', [$from, $to])
            ->orderByDesc('created_at')
            ->limit(7)
            ->get();

        $largestCommission = max($dailyCommissions ?: [0]);
        $largestRevenue = max($dailyRevenue ?: [0]);
        $orderCommissionShare = max($orderCommissionTotal, 0);
        $parcelCommissionShare = max($parcelCommissionTotal, 0);

        $statusGroups = [
            'Livrées' => [OrderStatus::Delivered->value],
            'En cours' => [OrderStatus::Paid->value, OrderStatus::Accepted->value, OrderStatus::Preparing->value, OrderStatus::Ready->value, OrderStatus::Assigned->value, OrderStatus::PickedUp->value, OrderStatus::InDelivery->value],
            'En attente' => [OrderStatus::Draft->value, OrderStatus::AwaitingPayment->value],
            'Litiges' => [OrderStatus::Disputed->value],
            'Annulées' => [OrderStatus::Cancelled->value],
            'Remboursées' => [OrderStatus::Refunded->value],
        ];
        $statusChart = collect($statusGroups)->map(fn (array $statuses, string $label) => [
            'label' => $label,
            'value' => (int) collect($statuses)->sum(fn (string $status) => (int) ($statusRows[$status] ?? 0)),
        ])->values();
        $paymentChart = collect([
            ['key' => 'cash', 'label' => 'Espèces'],
            ['key' => 'online', 'label' => 'Mobile Money'],
        ])->map(fn ($item) => [
            'label' => $item['label'],
            'value' => (int) ($paymentRows[$item['key']]->amount ?? 0),
        ]);

        return view('admin.dashboard', [
            'vendors' => Vendor::count(),
            'products' => Product::count(),
            'users' => User::count(),
            'zones' => DeliveryZone::count(),
            'kpis' => $kpis,
            'alerts' => $alerts,
            'latestOrders' => $latestOrders,
            'period' => ['from' => $from->toDateString(), 'to' => $to->toDateString()],
            'chartData' => [
                'labels' => $days,
                'revenue' => $dailyRevenue,
                'commissions' => $dailyCommissions,
                'max_revenue' => $largestRevenue,
                'max_commission' => $largestCommission,
                'commission_split' => [$orderCommissionShare, $parcelCommissionShare],
                'revenue_split' => [
                    (int) OrderFinancial::query()->whereHas('order', fn (Builder $query) => $query->whereBetween('orders.created_at', [$from, $to])->whereNotIn('orders.status', $excludedStatuses)->where('orders.payment_status', PaymentStatus::Confirmed->value))->sum('vendor_amount'),
                    (int) OrderFinancial::query()->whereHas('order', fn (Builder $query) => $query->whereBetween('orders.created_at', [$from, $to])->whereNotIn('orders.status', $excludedStatuses)->where('orders.payment_status', PaymentStatus::Confirmed->value))->sum('delivery_partner_amount') + (int) (clone $parcelBase)->sum('partner_amount'),
                    (int) OrderFinancial::query()->whereHas('order', fn (Builder $query) => $query->whereBetween('orders.created_at', [$from, $to])->whereNotIn('orders.status', $excludedStatuses)->where('orders.payment_status', PaymentStatus::Confirmed->value))->sum('platform_amount') + $parcelCommissionTotal,
                ],
                'order_statuses' => $statusChart->all(),
                'payment_methods' => $paymentChart->all(),
                'payment_orders' => [(int) ($paymentRows['cash']->orders_count ?? 0), (int) ($paymentRows['online']->orders_count ?? 0)],
            ],
            'leaderboards' => ['vendors' => $vendorSummary, 'clients' => $clientSummary, 'drivers' => $driverSummary],
        ]);
    }

    /** Variation en % entre deux périodes (null si aucune base). */
    private function trend(int $current, int $previous): ?int
    {
        if ($previous <= 0) {
            return $current > 0 ? 100 : null;
        }

        return (int) round((($current - $previous) / $previous) * 100);
    }
}
