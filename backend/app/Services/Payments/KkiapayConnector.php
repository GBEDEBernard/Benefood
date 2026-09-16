<?php

namespace App\Services\Payments;

use App\Models\Order;
use Illuminate\Support\Facades\Http;

/**
 * Minimal Kkiapay connector for sandbox flows.
 */
class KkiapayConnector implements PaymentGateway
{
    protected string $key;

    protected bool $sandbox;

    public function __construct()
    {
        $this->key = config('kkiapay.key');
        $this->sandbox = (bool) config('kkiapay.sandbox', true);
    }

    public function createPayment(Order $order): array
    {
        // Recalculate amount server-side (do NOT trust client amount)
        $amount = (int) round($order->total * 100); // amount in cents if needed

        // Kkiapay JS widget uses amount in basic unit; the API differs per provider.
        // For sandbox demo we return the widget payload.
        return [
            'provider' => 'kkiapay',
            'widget' => [
                'key' => $this->key,
                'amount' => $amount,
                'order_id' => $order->id,
                'callback' => route('api.v1.payments.callback'),
            ],
        ];
    }

    public function verifyTransaction(string $transactionId): array
    {
        // Example verification with Kkiapay public API (sandbox)
        $url = 'https://kkiapay.me/api/v1/transactions/'.$transactionId;

        $res = Http::withHeaders(['Accept' => 'application/json'])
            ->withToken($this->key)
            ->get($url);

        if (! $res->successful()) {
            return ['ok' => false, 'status' => 'error', 'raw' => $res->body()];
        }

        $data = $res->json();

        return ['ok' => true, 'status' => $data['status'] ?? 'unknown', 'data' => $data];
    }

    public function handleWebhook(array $payload): array
    {
        // Basic mapping of webhook payload to internal event
        $event = $payload['event'] ?? 'unknown';
        $transaction = $payload['data']['transaction'] ?? $payload['data'] ?? $payload;

        // attempt to extract order id from metadata
        $orderId = $transaction['metadata']['order_id'] ?? $transaction['metadata']['order'] ?? null;

        return [
            'event' => $event,
            'transaction_id' => $transaction['id'] ?? null,
            'status' => $transaction['status'] ?? $payload['status'] ?? null,
            'amount' => $transaction['amount'] ?? null,
            'order_id' => $orderId,
            'raw' => $payload,
        ];
    }
}
