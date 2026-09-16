<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Http\Controllers\Controller;
use App\Models\FinancialTransaction;
use App\Models\Order;
use App\Models\Payment;
use App\Models\PaymentEvent;
use App\Services\Payments\KkiapayConnector;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class PaymentController extends Controller
{
    public function create(Request $request): JsonResponse
    {
        $data = $request->validate([
            'order_id' => ['required', 'uuid', 'exists:orders,id'],
        ]);

        $order = Order::findOrFail($data['order_id']);

        if ($order->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        if (! $order->isAwaitingPayment()) {
            return Api::error('Cette commande ne peut plus être payée.', 'payment.invalid_state', 422);
        }

        if ($order->payment_deadline_at && $order->payment_deadline_at->isPast()) {
            return Api::error('Le délai de paiement pour cette commande est expiré.', 'payment.expired', 422);
        }

        $connector = new KkiapayConnector;

        $payload = $connector->createPayment($order);

        return Api::ok($payload);
    }

    public function retry(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        if (! $order->isAwaitingPayment()) {
            return Api::error('Cette commande ne peut plus être payée.', 'payment.invalid_state', 422);
        }

        $payment = $order->payment;

        if ($payment && ! in_array($payment->status, [PaymentStatus::Initiated, PaymentStatus::Failed, PaymentStatus::Expired])) {
            return Api::error('Ce paiement ne peut pas être relancé.', 'payment.cannot_retry', 422);
        }

        if ($order->payment_deadline_at && $order->payment_deadline_at->isPast()) {
            $newDeadline = now()->addMinutes((int) config('beninfood.orders.payment_deadline_minutes', 15));
            $order->update(['payment_deadline_at' => $newDeadline]);

            if ($payment) {
                $payment->update(['expires_at' => $newDeadline, 'status' => PaymentStatus::Initiated]);
            }
        }

        $connector = new KkiapayConnector;

        $payload = $connector->createPayment($order);

        return Api::ok($payload);
    }

    public function verify(Request $request): JsonResponse
    {
        $data = $request->validate([
            'transaction_id' => ['required', 'string'],
        ]);

        $connector = new KkiapayConnector;

        $result = $connector->verifyTransaction($data['transaction_id']);

        return Api::ok($result);
    }

    public function callback(Request $request): JsonResponse
    {
        $transactionId = $request->input('transaction_id') ?? $request->input('id');

        if (! $transactionId) {
            return Api::error('Identifiant de transaction manquant.', 'payment.missing_transaction', 422);
        }

        $connector = new KkiapayConnector;
        $result = $connector->verifyTransaction($transactionId);

        return Api::ok($result);
    }

    public function webhook(Request $request): JsonResponse
    {
        $payload = $request->all();

        Log::info('Payment webhook received', $payload);

        $secret = config('kkiapay.webhook_secret');
        if ($secret) {
            $signature = $request->header('X-Kkiapay-Signature') ?: $request->header('x-kkiapay-signature');
            if (! $signature) {
                Log::warning('Missing Kkiapay signature');

                return response()->json(['ok' => false], 400);
            }

            $computed = hash_hmac('sha256', json_encode($payload), $secret);
            if (! hash_equals($computed, $signature)) {
                Log::warning('Invalid Kkiapay signature');

                return response()->json(['ok' => false], 403);
            }
        }

        $connector = new KkiapayConnector;
        $event = $connector->handleWebhook($payload);

        $provider = 'kkiapay';
        $providerTx = $event['transaction_id'];

        if (! $providerTx) {
            Log::warning('Webhook without transaction id', $event);

            return response()->json(['ok' => false], 400);
        }

        try {
            $created = DB::transaction(function () use ($provider, $providerTx, $payload, $event) {
                $exists = PaymentEvent::query()
                    ->where('provider', $provider)
                    ->where('provider_transaction_id', $providerTx)
                    ->exists();

                if ($exists) {
                    return false;
                }

                $orderId = $event['order_id'] ?? null;
                $order = $orderId ? Order::find($orderId) : null;

                $payment = null;
                if ($order) {
                    $payment = $order->payment;
                }

                if (! $payment && $orderId) {
                    $payment = Payment::where('order_id', $orderId)->first();
                }

                if ($payment) {
                    $payment->update([
                        'gateway_txn_id' => $providerTx,
                        'payload' => $payload,
                    ]);
                }

                PaymentEvent::create([
                    'payment_id' => $payment?->id,
                    'event_type' => $event['event'] ?? 'unknown',
                    'provider' => $provider,
                    'provider_transaction_id' => $providerTx,
                    'payload' => $payload,
                    'processed_at' => now(),
                ]);

                $status = $event['status'] ?? 'unknown';

                if (in_array($status, ['success', 'successful', 'paid', 'completed', 'confirmed'])) {
                    if ($payment) {
                        $payment->update([
                            'status' => PaymentStatus::Confirmed,
                            'paid_at' => now(),
                        ]);
                    }

                    if ($order && ! $order->isPaid()) {
                        $order->update([
                            'payment_status' => PaymentStatus::Confirmed->value,
                        ]);

                        if ($order->isAwaitingPayment()) {
                            $order->update([
                                'status' => OrderStatus::Paid->value,
                            ]);

                            $order->statusHistory()->create([
                                'from_status' => OrderStatus::AwaitingPayment->value,
                                'to_status' => OrderStatus::Paid->value,
                                'actor_type' => 'system',
                                'reason' => 'Paiement confirmé via '.$provider,
                                'created_at' => now(),
                            ]);
                        }

                        $amount = $payment?->amount ?? ($event['amount'] ?? 0);
                        $currency = $payment?->currency ?? ($event['raw']['data']['transaction']['currency'] ?? 'XOF');

                        if ($amount) {
                            FinancialTransaction::create([
                                'payment_id' => $payment?->id,
                                'order_id' => $order->id,
                                'type' => 'payment',
                                'amount' => $amount,
                                'currency' => $currency,
                                'description' => 'Paiement reçu via '.$provider,
                                'meta' => $event['raw'],
                            ]);
                        }
                    }
                } elseif (in_array($status, ['failed', 'cancelled', 'expired'])) {
                    if ($payment) {
                        $paymentStatus = match ($status) {
                            'failed' => PaymentStatus::Failed,
                            'cancelled' => PaymentStatus::Cancelled,
                            'expired' => PaymentStatus::Expired,
                            default => PaymentStatus::Failed,
                        };
                        $payment->update(['status' => $paymentStatus]);
                    }

                    if ($order) {
                        $order->update(['payment_status' => match ($status) {
                            'failed' => PaymentStatus::Failed->value,
                            'cancelled' => PaymentStatus::Cancelled->value,
                            'expired' => PaymentStatus::Expired->value,
                            default => PaymentStatus::Failed->value,
                        }]);
                    }
                }

                return true;
            });
        } catch (\Exception $e) {
            Log::error('Error processing payment webhook: '.$e->getMessage(), ['exception' => $e]);

            return response()->json(['ok' => false], 500);
        }

        if (! $created) {
            Log::info('Duplicate webhook ignored', ['provider' => $provider, 'tx' => $providerTx]);

            return response()->json(['ok' => true]);
        }

        Log::info('Payment webhook processed', ['provider' => $provider, 'tx' => $providerTx]);

        return response()->json(['ok' => true]);
    }
}
