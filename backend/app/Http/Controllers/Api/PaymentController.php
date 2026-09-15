<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Services\Payments\KkiapayConnector;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;
use App\Models\FinancialTransaction;
use App\Models\Payment as PaymentModel;

class PaymentController extends Controller
{
    public function create(Request $request): JsonResponse
    {
        $request->validate(['order_id' => ['required', 'uuid']]);

        $order = Order::findOrFail($request->input('order_id'));

        // Recalculate and protect: ensure order belongs to user etc.
        // TODO: add ownership and state checks

        $connector = new KkiapayConnector();

        $payload = $connector->createPayment($order);

        return response()->json($payload);
    }

    public function verify(Request $request): JsonResponse
    {
        $request->validate(['transaction_id' => ['required', 'string']]);

        $connector = new KkiapayConnector();

        $result = $connector->verifyTransaction($request->input('transaction_id'));

        return response()->json($result);
    }

    // Webhook endpoint (public)
    public function webhook(Request $request): JsonResponse
    {
        $payload = $request->all();

        Log::info('Payment webhook received', $payload);

        // signature verification (if secret configured)
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

        $connector = new KkiapayConnector();

        $event = $connector->handleWebhook($payload);

        // idempotency: use payment_events unique key
        $provider = $event['raw']['provider'] ?? 'kkiapay';
        $providerTx = $event['transaction_id'];

        if (! $providerTx) {
            Log::warning('Webhook without transaction id', $event);
            return response()->json(['ok' => false], 400);
        }

        // Attempt to create a payment_event record; if exists, ignore (idempotent)
        try {
            $created = \DB::transaction(function () use ($provider, $providerTx, $payload, $event) {
                $now = now();
                $exists = \DB::table('payment_events')
                    ->where('provider', $provider)
                    ->where('provider_transaction_id', $providerTx)
                    ->exists();

                if ($exists) {
                    return false;
                }

                \DB::table('payment_events')->insert([
                    'provider' => $provider,
                    'provider_transaction_id' => $providerTx,
                    'payload' => json_encode($payload),
                    'processed_at' => $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                // Link or create Payment and update Order within a DB transaction
                $status = $event['status'] ?? 'unknown';
                $orderId = $event['order_id'] ?? null;

                // prefer to find order by provided order id; fallback to metadata
                $order = null;
                if ($orderId) {
                    $order = \App\Models\Order::find($orderId);
                }

                // create or update payment record
                $payment = \App\Models\Payment::firstOrCreate(
                    ['provider' => $provider, 'provider_transaction_id' => $providerTx],
                    [
                        'order_id' => $order?->id,
                        'amount' => $event['amount'] ?? 0,
                        'currency' => $event['raw']['data']['transaction']['currency'] ?? 'XOF',
                        'status' => $status,
                        'metadata' => $event['raw'],
                    ]
                );

                // If payment successful, mark order paid and create ledger entry (atomic)
                if (in_array($status, ['success', 'paid', 'completed', 'confirmed'])) {
                    if ($order && $order->payment_status !== 'paid') {
                        $order->payment_status = 'paid';
                        $order->save();

                        // Create or update a FinancialTransaction record linked to this payment/order
                        $amount = $payment->amount ?? ($event['amount'] ?? 0);
                        $currency = $payment->currency ?? ($event['raw']['data']['transaction']['currency'] ?? 'XOF');

                        if ($amount) {
                            FinancialTransaction::create([
                                'payment_id' => $payment->id,
                                'order_id' => $order->id,
                                'type' => 'payment',
                                'amount' => $amount,
                                'currency' => $currency,
                                'description' => 'Payment received via '.$provider,
                                'meta' => $event['raw'],
                            ]);
                        }
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
