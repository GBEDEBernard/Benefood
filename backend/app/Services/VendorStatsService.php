<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderFinancial;
use App\Models\Review;
use App\Models\Vendor;
use App\Support\StatsPeriod;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Statistiques d'activité du vendeur (tableau de bord analytique).
 */
class VendorStatsService
{
    /**
     * @return array<string, mixed>
     */
    public function forVendor(Vendor $vendor, ?string $period = '30d'): array
    {
        $period = StatsPeriod::resolve($period);
        $from = $period->from;
        $to = $period->to;
        [$previousFrom, $previousTo] = $period->previous();

        $delivered = OrderStatus::Delivered->value;
        $cancelled = OrderStatus::Cancelled->value;

        $deliveredQuery = fn (Carbon $start, Carbon $end) => Order::query()
            ->where('vendor_id', $vendor->id)
            ->where('status', $delivered)
            ->whereBetween('delivered_at', [$start, $end]);

        $revenue = (int) $deliveredQuery($from, $to)->sum('subtotal');
        $ordersDelivered = (int) $deliveredQuery($from, $to)->count();
        $previousRevenue = (int) $deliveredQuery($previousFrom, $previousTo)->sum('subtotal');
        $previousOrdersDelivered = (int) $deliveredQuery($previousFrom, $previousTo)->count();

        $financialsQuery = fn (Carbon $start, Carbon $end) => OrderFinancial::query()
            ->whereIn('order_id', $deliveredQuery($start, $end)->select('id'));

        $netRevenue = (int) $financialsQuery($from, $to)->sum('vendor_amount');
        $commission = (int) $financialsQuery($from, $to)->sum('commission_amount');

        $ordersTotal = (int) Order::query()
            ->where('vendor_id', $vendor->id)
            ->whereBetween('created_at', [$from, $to])
            ->count();
        $ordersCancelled = (int) Order::query()
            ->where('vendor_id', $vendor->id)
            ->whereBetween('created_at', [$from, $to])
            ->where('status', $cancelled)
            ->count();

        $itemsSold = (int) DB::table('order_items')
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->where('orders.vendor_id', $vendor->id)
            ->where('orders.status', $delivered)
            ->whereBetween('orders.delivered_at', [$from, $to])
            ->sum('order_items.quantity');

        $uniqueClients = (int) $deliveredQuery($from, $to)
            ->distinct()
            ->count('user_id');

        return [
            'period' => $period->toArray(),
            'currency' => 'XOF',
            'kpis' => [
                'revenue' => $revenue,
                'net_revenue' => $netRevenue,
                'commission' => $commission,
                'orders_total' => $ordersTotal,
                'orders_delivered' => $ordersDelivered,
                'orders_cancelled' => $ordersCancelled,
                'average_basket' => $ordersDelivered > 0 ? intdiv($revenue, $ordersDelivered) : 0,
                'items_sold' => $itemsSold,
                'unique_clients' => $uniqueClients,
                'pending_orders' => $this->pendingOrders($vendor),
                'cancellation_rate' => $ordersTotal > 0 ? round($ordersCancelled / $ordersTotal * 100, 1) : 0.0,
                'rating' => $this->rating($vendor, $from, $to),
            ],
            'comparison' => [
                'revenue_pct' => $this->change($revenue, $previousRevenue),
                'orders_pct' => $this->change($ordersDelivered, $previousOrdersDelivered),
            ],
            'series' => $this->series($deliveredQuery($from, $to), $period),
            'status_breakdown' => $this->statusBreakdown($vendor, $from, $to),
            'top_products' => $this->topProducts($vendor, $from, $to),
        ];
    }

    private function series($query, StatsPeriod $period): array
    {
        $buckets = [];

        foreach ($period->buckets() as $key) {
            $buckets[$key] = ['label' => $key, 'revenue' => 0, 'orders' => 0];
        }

        foreach ($query->get(['delivered_at', 'subtotal']) as $order) {
            $date = $order->delivered_at;
            if ($date === null) {
                continue;
            }

            $key = $period->bucketKey($date);
            if (! isset($buckets[$key])) {
                continue;
            }

            $buckets[$key]['revenue'] += (int) $order->subtotal;
            $buckets[$key]['orders']++;
        }

        return array_values($buckets);
    }

    private function statusBreakdown(Vendor $vendor, Carbon $from, Carbon $to): array
    {
        return Order::query()
            ->where('vendor_id', $vendor->id)
            ->whereBetween('created_at', [$from, $to])
            ->selectRaw('status as order_status, COUNT(*) as total')
            ->groupBy('status')
            ->orderByDesc('total')
            ->get()
            ->map(fn ($row) => ['status' => (string) $row->order_status, 'count' => (int) $row->total])
            ->all();
    }

    private function topProducts(Vendor $vendor, Carbon $from, Carbon $to): array
    {
        $delivered = OrderStatus::Delivered->value;

        return DB::table('order_items')
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->leftJoin('products', 'products.id', '=', 'order_items.product_id')
            ->where('orders.vendor_id', $vendor->id)
            ->where('orders.status', $delivered)
            ->whereBetween('orders.delivered_at', [$from, $to])
            // Regroupement sur l'identité du produit : un produit renommé reste
            // une seule ligne. Les produits supprimés (product_id nul) sont
            // regroupés par le libellé figé au moment de la commande.
            ->groupByRaw(
                'CASE WHEN order_items.product_id IS NULL THEN order_items.name_snapshot ELSE order_items.product_id END, products.name'
            )
            ->selectRaw(
                'MAX(order_items.product_id) as id,'
                .' COALESCE(products.name, MAX(order_items.name_snapshot)) as name,'
                .' SUM(order_items.quantity) as quantity,'
                .' SUM(order_items.subtotal) as revenue'
            )
            ->orderByDesc('quantity')
            ->limit(5)
            ->get()
            ->map(fn ($row) => [
                'id' => $row->id !== null ? (string) $row->id : null,
                'name' => (string) $row->name,
                'quantity' => (int) $row->quantity,
                'revenue' => (int) $row->revenue,
            ])
            ->all();
    }

    private function rating(Vendor $vendor, Carbon $from, Carbon $to): array
    {
        $base = Review::query()->whereIn(
            'order_id',
            Order::query()->where('vendor_id', $vendor->id)->select('id'),
        )->whereBetween('created_at', [$from, $to]);

        $count = (int) (clone $base)->count();
        $average = (clone $base)->avg('rating');

        return [
            'average' => $average !== null ? round((float) $average, 1) : null,
            'count' => $count,
        ];
    }

    /**
     * Commandes en attente de traitement (badges du footer vendeur).
     */
    private function pendingOrders(Vendor $vendor): int
    {
        return Order::query()
            ->where('vendor_id', $vendor->id)
            ->whereIn('status', [
                OrderStatus::AwaitingPayment->value,
                OrderStatus::Paid->value,
                OrderStatus::Accepted->value,
            ])
            ->count();
    }

    private function change(int|float $current, int|float $previous): ?float
    {
        if ($previous <= 0) {
            return $current > 0 ? 100.0 : null;
        }

        return round((($current - $previous) / $previous) * 100, 1);
    }
}
