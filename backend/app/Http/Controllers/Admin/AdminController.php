<?php

namespace App\Http\Controllers\Admin;

use App\Enums\ComplaintStatus;
use App\Enums\DriverStatus;
use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Enums\RefundStatus;
use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Models\Complaint;
use App\Models\DeliveryZone;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Product;
use App\Models\Refund;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\View\View;

class AdminController extends Controller
{
    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $now = Carbon::now();
        $todayStart = $now->copy()->startOfDay();
        $monthStart = $now->copy()->startOfMonth();
        $weekStart = $now->copy()->subDays(7)->startOfDay();
        $prevWeekStart = $now->copy()->subDays(14)->startOfDay();

        // Commandes "réussies" : payées et non annulées (base CA + commissions).
        $paid = fn ($query) => $query
            ->whereNotIn('status', [
                OrderStatus::Draft->value,
                OrderStatus::AwaitingPayment->value,
                OrderStatus::Cancelled->value,
                OrderStatus::Refunded->value,
            ])
            ->where('payment_status', PaymentStatus::Confirmed->value);

        $ordersToday = Order::where('created_at', '>=', $todayStart)->count();
        $ordersMonth = Order::where('created_at', '>=', $monthStart)->count();
        $ordersWeek = Order::where('created_at', '>=', $weekStart)->count();
        $ordersPrevWeek = Order::whereBetween('created_at', [$prevWeekStart, $weekStart])->count();

        $caToday = Order::where('created_at', '>=', $todayStart)->where($paid)->sum('total');
        $caMonth = Order::where('created_at', '>=', $monthStart)->where($paid)->sum('total');
        $caWeek = Order::where('created_at', '>=', $weekStart)->where($paid)->sum('total');
        $caPrevWeek = Order::whereBetween('created_at', [$prevWeekStart, $weekStart])->where($paid)->sum('total');

        $commissionsMonth = Order::where('created_at', '>=', $monthStart)
            ->where($paid)
            ->whereHas('financials')
            ->withSum('financials as commission_amount', 'commission_amount')
            ->get()
            ->sum('commission_amount');

        // KPIs structurés pour la vue.
        $kpis = [
            'orders_today' => ['value' => $ordersToday, 'label' => 'Commandes aujourd’hui'],
            'orders_month' => ['value' => $ordersMonth, 'label' => 'Commandes ce mois'],
            'orders_week' => ['value' => $ordersWeek, 'previous' => $ordersPrevWeek],
            'orders_trend' => $this->trend($ordersWeek, $ordersPrevWeek),
            'ca_today' => ['value' => $caToday, 'label' => 'CA aujourd’hui'],
            'ca_month' => ['value' => $caMonth, 'label' => 'CA ce mois'],
            'ca_week' => ['value' => $caWeek, 'previous' => $caPrevWeek],
            'ca_trend' => $this->trend($caWeek, $caPrevWeek),
            'commissions_month' => $commissionsMonth,
            'active_vendors' => Vendor::where('status', VendorStatus::Active->value)->count(),
            'online_drivers' => DriverProfile::where('status', DriverStatus::Active->value)
                ->where('available', true)
                ->count(),
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
            ->orderByDesc('created_at')
            ->limit(8)
            ->get();

        return view('admin.dashboard', [
            'vendors' => Vendor::count(),
            'products' => Product::count(),
            'users' => User::count(),
            'zones' => DeliveryZone::count(),
            'kpis' => $kpis,
            'alerts' => $alerts,
            'latestOrders' => $latestOrders,
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
