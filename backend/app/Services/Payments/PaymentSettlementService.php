<?php

namespace App\Services\Payments;

use App\Enums\PaymentStatus;
use App\Models\DriverProfile;
use App\Models\FinancialTransaction;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\Payment;
use App\Models\PaymentEvent;
use App\Services\CashService;
use App\Services\OrderService;
use App\Services\ParcelService;
use Illuminate\Support\Facades\DB;

/**
 * Applique un événement de paiement (webhook, redirection ou vérification) à la
 * commande, au colis ou au flottant concerné.
 *
 * Le traitement est idempotent : la clé `payment_events` (provider +
 * provider_transaction_id) garantit qu'un même paiement n'est réglé qu'une fois,
 * quel que soit le chemin qui le déclare (webhook FedaPay ou vérification côté
 * application lorsque le webhook n'est pas joignable).
 */
class PaymentSettlementService
{
    public function __construct(
        private readonly OrderService $orders,
        private readonly ParcelService $parcels,
    ) {}

    /**
     * @param  array<string, mixed>  $event  Événement normalisé (voir FedaPayConnector::handleWebhook()).
     * @return bool True si l'événement vient d'être traité, false s'il était déjà connu.
     */
    public function settle(array $event, string $provider = 'fedapay', ?Payment $payment = null): bool
    {
        $providerTx = (string) ($event['transaction_id'] ?? $payment?->gateway_txn_id ?? '');

        if ($providerTx === '') {
            return false;
        }

        $status = (string) ($event['status'] ?? 'unknown');
        $raw = $event['raw'] ?? $event;
        $rawArray = is_array($raw) ? $raw : ['raw' => $raw];

        return DB::transaction(function () use ($event, $provider, $providerTx, $status, $rawArray, $payment): bool {
            $exists = PaymentEvent::query()
                ->where('provider', $provider)
                ->where('provider_transaction_id', $providerTx)
                ->exists();

            if ($exists) {
                return false;
            }

            $order = ($event['order_id'] ?? null) ? Order::find($event['order_id']) : $payment?->order;
            $parcel = ($event['parcel_id'] ?? null) ? Parcel::find($event['parcel_id']) : $payment?->parcel;

            $payment = $payment
                ?? $order?->payment
                ?? $parcel?->payment
                ?? (($event['payment_id'] ?? null) ? Payment::find($event['payment_id']) : null);

            $alreadySettled = $payment?->paid_at !== null;

            PaymentEvent::create([
                'payment_id' => $payment?->id,
                'event_type' => $event['event'] ?? 'transaction',
                'provider' => $provider,
                'provider_transaction_id' => $providerTx,
                'payload' => $rawArray,
                'processed_at' => now(),
            ]);

            if ($payment && $payment->gateway_txn_id === null) {
                $payment->update(['gateway_txn_id' => $providerTx]);
            }

            if ($status === 'success') {
                $payment?->update([
                    'status' => PaymentStatus::Confirmed,
                    'paid_at' => now(),
                ]);

                if (($event['type'] ?? null) === 'float_topup') {
                    $driver = ($event['driver_id'] ?? null) ? DriverProfile::find($event['driver_id']) : null;

                    if ($driver && $payment && ! $alreadySettled) {
                        app(CashService::class)->topUp(
                            $driver,
                            (int) $payment->amount,
                            null,
                            'float_topup',
                            $payment->id,
                        );
                    }
                }

                if ($order && ! $order->isPaid()) {
                    $amount = (int) ($payment?->amount ?? $event['amount'] ?? 0);
                    $currency = $payment?->currency ?? 'XOF';

                    if ($order->isAwaitingPayment()) {
                        // Flux standard : répartition interne (part vendeur en
                        // attente) et notification vendeur.
                        $this->orders->confirmPayment($order, $amount);
                    } else {
                        $order->update(['payment_status' => PaymentStatus::Confirmed->value]);
                    }

                    if ($amount) {
                        FinancialTransaction::create([
                            'payment_id' => $payment?->id,
                            'order_id' => $order->id,
                            'type' => 'payment',
                            'amount' => $amount,
                            'currency' => $currency,
                            'description' => 'Paiement reçu via '.$provider,
                            'meta' => $rawArray,
                        ]);
                    }
                }

                if ($parcel && $parcel->status->isAwaitingPayment()) {
                    $this->parcels->confirmPayment($parcel, (int) ($payment?->amount ?? $parcel->delivery_fee));
                }
            } elseif (in_array($status, ['failed', 'cancelled'], true)) {
                $failureStatus = $status === 'cancelled' ? PaymentStatus::Cancelled : PaymentStatus::Failed;

                $payment?->update(['status' => $failureStatus]);

                $order?->update(['payment_status' => $failureStatus->value]);
                $parcel?->update(['payment_status' => $failureStatus->value]);
            }

            return true;
        });
    }
}
