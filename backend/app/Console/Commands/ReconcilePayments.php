<?php

namespace App\Console\Commands;

use App\Enums\PaymentStatus;
use App\Models\Payment;
use App\Services\Payments\KkiapayConnector;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class ReconcilePayments extends Command
{
    protected $signature = 'payments:reconcile';

    protected $description = 'Rapproche les paiements en attente avec Kkiapay (J95).';

    public function handle(): int
    {
        $pending = Payment::query()
            ->where('gateway', 'kkiapay')
            ->whereIn('status', [PaymentStatus::Initiated, PaymentStatus::Pending])
            ->whereNotNull('gateway_txn_id')
            ->where('created_at', '<', now()->subMinutes(5))
            ->get();

        $reconciled = 0;

        $connector = new KkiapayConnector;

        foreach ($pending as $payment) {
            try {
                $result = $connector->verifyTransaction($payment->gateway_txn_id);

                if ($result['ok'] && in_array($result['status'] ?? '', ['successful', 'completed', 'paid'])) {
                    $payment->update([
                        'status' => PaymentStatus::Confirmed,
                        'paid_at' => now(),
                    ]);

                    if ($payment->order) {
                        $payment->order->update([
                            'payment_status' => PaymentStatus::Confirmed->value,
                        ]);
                    }

                    $reconciled++;
                    Log::info('Payment reconciled', ['payment_id' => $payment->id, 'gateway_txn_id' => $payment->gateway_txn_id]);
                }
            } catch (\Exception $e) {
                Log::warning('Payment reconciliation failed', ['payment_id' => $payment->id, 'error' => $e->getMessage()]);
            }
        }

        $this->info("{$reconciled} paiement(s) rapproché(s) sur {$pending->count()} en attente.");

        return Command::SUCCESS;
    }
}
