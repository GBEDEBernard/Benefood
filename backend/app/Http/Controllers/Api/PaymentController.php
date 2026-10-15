<?php

namespace App\Http\Controllers\Api;

use App\Enums\PaymentStatus;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\Payment;
use App\Models\PaymentEvent;
use App\Models\Payout;
use App\Services\Payments\PaymentGateway;
use App\Services\Payments\PaymentSettlementService;
use App\Services\PayoutService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class PaymentController extends Controller
{
    public function __construct(
        private readonly PaymentGateway $gateway,
        private readonly PaymentSettlementService $settlements,
    ) {}

    public function create(Request $request): JsonResponse
    {
        $data = $request->validate([
            'order_id' => ['required_without:parcel_id', 'uuid', 'exists:orders,id'],
            'parcel_id' => ['required_without:order_id', 'uuid', 'exists:parcels,id'],
        ]);

        if (isset($data['order_id'])) {
            return $this->createOrderPayment($request, Order::findOrFail($data['order_id']));
        }

        return $this->createParcelPayment($request, Parcel::findOrFail($data['parcel_id']));
    }

    private function createOrderPayment(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        if ($order->payment_method?->isCash()) {
            return Api::error('Cette commande est payée en espèces à la livraison.', 'payment.cash_not_online', 422);
        }

        if (! $order->isAwaitingPayment()) {
            return Api::error('Cette commande ne peut plus être payée.', 'payment.invalid_state', 422);
        }

        if ($order->payment_deadline_at && $order->payment_deadline_at->isPast()) {
            return Api::error('Le délai de paiement pour cette commande est expiré.', 'payment.expired', 422);
        }

        $payload = $this->gateway->createPayment($order);

        $this->rememberIntent($order->payment, $payload);

        return $this->checkoutResponse($payload);
    }

    private function createParcelPayment(Request $request, Parcel $parcel): JsonResponse
    {
        if ($parcel->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        if ($parcel->isCash()) {
            return Api::error('Ce colis est payé en espèces à la livraison.', 'payment.cash_not_online', 422);
        }

        if (! $parcel->status->isAwaitingPayment()) {
            return Api::error('Ce colis ne peut plus être payé.', 'payment.invalid_state', 422);
        }

        if ($parcel->payment_deadline_at && $parcel->payment_deadline_at->isPast()) {
            return Api::error('Le délai de paiement pour ce colis est expiré.', 'payment.expired', 422);
        }

        $payload = $this->gateway->createPaymentForParcel($parcel);

        $this->rememberIntent($parcel->payment, $payload);

        return $this->checkoutResponse($payload);
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

        if ($payment && ! in_array($payment->status, [PaymentStatus::Initiated, PaymentStatus::Failed, PaymentStatus::Expired], true)) {
            return Api::error('Cette commande ne peut plus être payée.', 'payment.cannot_retry', 422);
        }

        if ($order->payment_deadline_at && $order->payment_deadline_at->isPast()) {
            $order->update([
                'payment_deadline_at' => now()->addMinutes((int) config('beninfood.orders.payment_deadline_minutes', 15)),
            ]);

            $payment?->update(['status' => PaymentStatus::Initiated]);
        }

        $payload = $this->gateway->createPayment($order);

        $this->rememberIntent($order->payment, $payload);

        return $this->checkoutResponse($payload);
    }

    public function verify(Request $request): JsonResponse
    {
        $data = $request->validate([
            'transaction_id' => ['required', 'string'],
        ]);

        $result = $this->gateway->verifyTransaction($data['transaction_id']);

        $payment = Payment::query()->where('gateway_txn_id', $data['transaction_id'])->first();

        if ($payment && $this->ownsPayment($payment, $request->user())) {
            $this->applyVerifiedResult($payment, $result);
        }

        return Api::ok($result);
    }

    public function callback(Request $request): JsonResponse
    {
        $transactionId = $request->input('transaction_id') ?? $request->input('id');

        if (! $transactionId) {
            return Api::error('Identifiant de transaction manquant.', 'payment.missing_transaction', 422);
        }

        $result = $this->gateway->verifyTransaction((string) $transactionId);

        $payment = Payment::query()->where('gateway_txn_id', (string) $transactionId)->first();

        if (! $payment && $request->filled('payment_id')) {
            $payment = Payment::find($request->input('payment_id'));
        }

        if ($payment) {
            $this->applyVerifiedResult($payment, $result);
        }

        return Api::ok($result);
    }

    public function webhook(Request $request): JsonResponse
    {
        $raw = $request->getContent();
        $payload = json_decode($raw, true);

        if (! is_array($payload)) {
            $payload = $request->all();
        }

        if (! $this->gateway->verifyWebhookSignature($raw, $request->header('X-FEDAPAY-SIGNATURE'))) {
            Log::warning('Webhook signature rejected', ['provider' => 'fedapay']);

            return response()->json(['ok' => false], 400);
        }

        $event = $this->gateway->handleWebhook($payload);
        $provider = 'fedapay';
        $providerTx = $event['transaction_id'];

        if (! $providerTx) {
            Log::warning('Webhook without transaction id', $event);

            return response()->json(['ok' => false], 400);
        }

        if (str_starts_with((string) $event['event'], 'payout')) {
            return $this->handlePayoutWebhook($event, 'payout:'.$providerTx, $payload);
        }

        try {
            $created = $this->settlements->settle($event, $provider);
        } catch (\Throwable $e) {
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

    /**
     * Persiste l'intention de paiement (identifiant FedaPay + charge utile) afin
     * qu'une vérification ultérieure puisse relier la transaction à la commande.
     *
     * @param  array<string, mixed>  $payload
     */
    private function rememberIntent(?Payment $payment, array $payload): void
    {
        if ($payment === null) {
            return;
        }

        $payment->update([
            'gateway' => 'fedapay',
            'gateway_txn_id' => $payload['transaction_id'] ?? $payment->gateway_txn_id,
            'payload' => $payload,
        ]);
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    private function checkoutResponse(array $payload): JsonResponse
    {
        if (($payload['status'] ?? null) === 'failed') {
            return Api::error(
                (string) ($payload['message'] ?? 'Le paiement n\'a pas pu être préparé. Réessayez.'),
                'payment.gateway_error',
                422,
            );
        }

        return Api::ok($payload);
    }

    /**
     * Règle un paiement confirmé côté FedaPay lorsque le webhook n'est pas
     * joignable (développement local, réseau) : le client revient d'une
     * transaction approuvée et on applique le même règlement, de façon
     * idempotente.
     *
     * @param  array<string, mixed>  $result
     */
    private function applyVerifiedResult(Payment $payment, array $result): void
    {
        $event = $this->verifiedEvent($payment, $result);

        if ($event !== null) {
            $this->settlements->settle($event, 'fedapay', $payment);
        }
    }

    /**
     * @param  array<string, mixed>  $result
     * @return array<string, mixed>|null
     */
    private function verifiedEvent(Payment $payment, array $result): ?array
    {
        $providerStatus = (string) ($result['status'] ?? 'unknown');

        if (! ($result['ok'] ?? false)) {
            return null;
        }

        if ($result['paid'] ?? false) {
            $status = 'success';
        } elseif ($providerStatus === 'declined') {
            $status = 'failed';
        } elseif (in_array($providerStatus, ['canceled', 'cancelled'], true)) {
            $status = 'cancelled';
        } else {
            return null;
        }

        $payload = is_array($payment->payload) ? $payment->payload : [];
        $meta = is_array($payload['meta'] ?? null) ? $payload['meta'] : [];

        return [
            'event' => 'transaction.'.$providerStatus,
            'status' => $status,
            'provider_status' => $providerStatus,
            'transaction_id' => $payment->gateway_txn_id,
            'amount' => $result['amount'] ?? $payment->amount,
            'type' => $meta['type'] ?? null,
            'order_id' => $meta['order_id'] ?? $payment->order_id,
            'parcel_id' => $meta['parcel_id'] ?? $payment->parcel_id,
            'driver_id' => $meta['driver_id'] ?? null,
            'payment_id' => $payment->id,
            'raw' => $result['data'] ?? $result,
        ];
    }

    private function ownsPayment(Payment $payment, $user): bool
    {
        if ($payment->order) {
            return $payment->order->user_id === $user->id;
        }

        if ($payment->parcel) {
            return $payment->parcel->user_id === $user->id;
        }

        $payload = is_array($payment->payload) ? $payment->payload : [];
        $meta = is_array($payload['meta'] ?? null) ? $payload['meta'] : [];

        if (($meta['type'] ?? null) === 'float_topup') {
            return (string) ($meta['driver_id'] ?? '') === (string) ($user->driverProfile?->id);
        }

        return false;
    }

    /**
     * Traite un événement de reversement FedaPay (`payout.sent`/`payout.failed`).
     *
     * @param  array<string, mixed>  $event
     * @param  array<string, mixed>  $payload
     */
    private function handlePayoutWebhook(array $event, string $eventKey, array $payload): JsonResponse
    {
        try {
            DB::transaction(function () use ($event, $eventKey, $payload): void {
                $exists = PaymentEvent::query()
                    ->where('provider', 'fedapay')
                    ->where('provider_transaction_id', $eventKey)
                    ->exists();

                if ($exists) {
                    return;
                }

                PaymentEvent::create([
                    'payment_id' => null,
                    'event_type' => $event['event'] ?? 'payout',
                    'provider' => 'fedapay',
                    'provider_transaction_id' => $eventKey,
                    'payload' => $payload,
                    'processed_at' => now(),
                ]);

                $payout = Payout::query()
                    ->where(function ($query) use ($event): void {
                        $query->where('gateway_ref', $event['transaction_id']);

                        if (! empty($event['reference'])) {
                            $query->orWhere('gateway_ref', $event['reference']);
                        }
                    })
                    ->first();

                if ($payout === null) {
                    return;
                }

                $status = $event['status'] ?? 'unknown';

                if ($status === 'success') {
                    app(PayoutService::class)->execute($payout, null, $event['transaction_id']);
                } elseif ($status === 'failed') {
                    app(PayoutService::class)->fail($payout, 'Échec signalé par FedaPay.');
                }
            });
        } catch (\Throwable $e) {
            Log::error('Payout webhook processing failed', ['error' => $e->getMessage()]);

            return response()->json(['ok' => false], 500);
        }

        return response()->json(['ok' => true]);
    }
}
