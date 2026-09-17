<?php

namespace App\Http\Controllers\Admin;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Refund;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Phase 16 — Rapports & export (J142).
 *
 * Exports CSV lisibles par tableur : commandes, commissions et remboursements
 * sur une période donnée. Lecture seule, réservée aux rôles autorisés.
 */
class AdminReportsController extends Controller
{
    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        return view('admin.reports.index', [
            'filters' => [
                'from' => $request->query('from', now()->startOfMonth()->format('Y-m-d')),
                'to' => $request->query('to', now()->format('Y-m-d')),
            ],
        ]);
    }

    public function exportOrders(Request $request): StreamedResponse
    {
        $this->authorize('manage', User::class);

        $orders = $this->period(Order::query()->with(['user', 'vendor']), $request)
            ->whereNotIn('status', [OrderStatus::Draft->value])
            ->orderBy('created_at')
            ->get();

        return $this->csv('commandes-', function ($handle) use ($orders): void {
            fputcsv($handle, ['Référence', 'Date', 'Client', 'Téléphone', 'Boutique', 'Sous-total', 'Livraison', 'Total', 'Statut']);
            foreach ($orders as $order) {
                fputcsv($handle, [
                    $order->reference,
                    $order->created_at?->format('Y-m-d H:i:s'),
                    $order->user?->name ?? '',
                    $order->user?->phone ?? '',
                    $order->vendor?->business_name ?? '',
                    $order->subtotal,
                    $order->delivery_fee,
                    $order->total,
                    $order->status->value,
                ]);
            }
        });
    }

    public function exportCommissions(Request $request): StreamedResponse
    {
        $this->authorize('manage', User::class);

        $orders = $this->period(Order::query()->with('financials'), $request)
            ->whereHas('financials')
            ->whereIn('status', $this->paidStatuses())
            ->orderBy('created_at')
            ->get();

        return $this->csv('commissions-', function ($handle) use ($orders): void {
            fputcsv($handle, ['Référence', 'Date', 'Base commission', 'Taux (%)', 'Commission', 'Montant vendeur', 'Part livreur']);
            foreach ($orders as $order) {
                if ($order->financials === null) {
                    continue;
                }
                fputcsv($handle, [
                    $order->reference,
                    $order->created_at?->format('Y-m-d H:i:s'),
                    $order->financials->commission_base,
                    $order->financials->commission_rate,
                    $order->financials->commission_amount,
                    $order->financials->vendor_amount,
                    $order->financials->delivery_partner_amount,
                ]);
            }
        });
    }

    public function exportRefunds(Request $request): StreamedResponse
    {
        $this->authorize('manage', User::class);

        $refunds = $this->period(Refund::query()->with(['order', 'payment']), $request)
            ->orderBy('created_at')
            ->get();

        return $this->csv('remboursements-', function ($handle) use ($refunds): void {
            fputcsv($handle, ['Commande', 'Date', 'Montant', 'Motif', 'Statut', 'Exécuté le', 'Réf. passerelle']);
            foreach ($refunds as $refund) {
                fputcsv($handle, [
                    $refund->order?->reference ?? '',
                    $refund->created_at?->format('Y-m-d H:i:s'),
                    $refund->amount,
                    $refund->reason ?? '',
                    $refund->status->value,
                    $refund->executed_at?->format('Y-m-d H:i:s'),
                    $refund->gateway_refund_id ?? '',
                ]);
            }
        });
    }

    private function period($query, Request $request)
    {
        return $query
            ->when($request->query('from'), fn ($q, $from) => $q->whereDate('created_at', '>=', $from))
            ->when($request->query('to'), fn ($q, $to) => $q->whereDate('created_at', '<=', $to));
    }

    /** @return array<int, string> */
    private function paidStatuses(): array
    {
        return [
            OrderStatus::Paid->value,
            OrderStatus::Accepted->value,
            OrderStatus::Preparing->value,
            OrderStatus::Ready->value,
            OrderStatus::Assigned->value,
            OrderStatus::PickedUp->value,
            OrderStatus::InDelivery->value,
            OrderStatus::Delivered->value,
        ];
    }

    private function csv(string $prefix, callable $writer): StreamedResponse
    {
        return response()->streamDownload(function () use ($writer): void {
            $handle = fopen('php://output', 'w');
            $writer($handle);
            fclose($handle);
        }, $prefix.now()->format('Y-m-d-Hi').'.csv', ['Content-Type' => 'text/csv']);
    }
}
