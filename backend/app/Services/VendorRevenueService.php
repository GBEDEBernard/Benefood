<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Enums\PayoutStatus;
use App\Models\Order;
use App\Models\OrderFinancial;
use App\Models\Vendor;
use App\Models\Wallet;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;

/**
 * Revenus et reversements du vendeur (J21 §8) : chiffre d'affaires,
 * commissions, solde disponible et historique des paiements.
 */
class VendorRevenueService
{
    /**
     * @return array<string, mixed>
     */
    public function forVendor(Vendor $vendor, ?string $from = null, ?string $to = null): array
    {
        $delivered = OrderStatus::Delivered->value;
        $pendingStatuses = [
            OrderStatus::Paid->value,
            OrderStatus::Accepted->value,
            OrderStatus::Preparing->value,
            OrderStatus::Ready->value,
            OrderStatus::Assigned->value,
            OrderStatus::PickedUp->value,
            OrderStatus::InDelivery->value,
        ];

        $deliveredOrders = $this->ordersQuery($vendor, $from, $to)->where('status', $delivered);

        $financials = OrderFinancial::query()
            ->whereIn('order_id', (clone $deliveredOrders)->select('id'));

        $grossSales = (int) (clone $deliveredOrders)->sum('subtotal');
        $commission = (int) (clone $financials)->sum('commission_amount');
        $netSales = (int) (clone $financials)->sum('vendor_amount');

        $pendingAmount = (int) OrderFinancial::query()
            ->whereIn('order_id', Order::query()
                ->where('vendor_id', $vendor->id)
                ->whereIn('status', $pendingStatuses)
                ->select('id'))
            ->sum('vendor_amount');

        $wallet = Wallet::query()
            ->where('owner_id', $vendor->id)
            ->whereIn('owner_type', ['vendor', Vendor::class])
            ->first();

        $executedPayouts = (int) ($wallet
            ? $wallet->payouts()->where('status', PayoutStatus::Executed->value)->sum('amount')
            : 0);

        return [
            'period' => ['from' => $from, 'to' => $to],
            'currency' => 'XOF',
            'orders_count' => (clone $deliveredOrders)->count(),
            'gross_sales' => $grossSales,
            'net_sales' => $netSales,
            'commission' => $commission,
            'pending_amount' => $pendingAmount,
            'available_balance' => $wallet ? (int) $wallet->available_balance : max($netSales - $executedPayouts, 0),
            'pending_balance' => $wallet ? (int) $wallet->pending_balance : $pendingAmount,
            'min_payout' => (int) config('beninfood.wallet.min_payout', 1000),
            'transactions' => $this->transactions($vendor, $from, $to),
            'payouts' => $this->payouts($wallet),
        ];
    }

    /**
     * @return Collection<int, array<string, mixed>>
     */
    private function transactions(Vendor $vendor, ?string $from, ?string $to): Collection
    {
        return OrderFinancial::query()
            ->whereIn('order_id', $this->ordersQuery($vendor, $from, $to)->select('id'))
            ->with('order')
            ->get()
            ->sortByDesc(fn (OrderFinancial $financial) => $financial->order?->delivered_at ?? $financial->order?->created_at)
            ->map(fn (OrderFinancial $financial) => [
                'id' => $financial->id,
                'reference' => $financial->order?->reference,
                'status' => $financial->order?->status,
                'date' => ($financial->order?->delivered_at ?? $financial->order?->created_at)?->toIso8601String(),
                'gross' => (int) $financial->subtotal,
                'commission' => (int) $financial->commission_amount,
                'net' => (int) $financial->vendor_amount,
            ])
            ->values();
    }

    /**
     * @return Collection<int, array<string, mixed>>
     */
    private function payouts(?Wallet $wallet): Collection
    {
        if ($wallet === null) {
            return collect();
        }

        return $wallet->payouts()
            ->orderByDesc('created_at')
            ->get()
            ->map(fn ($payout) => [
                'id' => $payout->id,
                'amount' => (int) $payout->amount,
                'method' => $payout->method,
                'status' => $payout->status->value,
                'executed_at' => $payout->executed_at?->toIso8601String(),
                'created_at' => $payout->created_at?->toIso8601String(),
            ]);
    }

    /**
     * @return Builder<Order>
     */
    private function ordersQuery(Vendor $vendor, ?string $from, ?string $to): Builder
    {
        return Order::query()
            ->where('vendor_id', $vendor->id)
            ->when($from !== null, fn (Builder $query) => $query->whereDate('delivered_at', '>=', $from))
            ->when($to !== null, fn (Builder $query) => $query->whereDate('delivered_at', '<=', $to));
    }
}
