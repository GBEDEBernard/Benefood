<?php

namespace App\Services\Payments;

use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\Payment;
use App\Models\Payout;
use App\Models\User;
use App\Support\Phone;
use FedaPay\Customer;
use FedaPay\FedaPay;
use FedaPay\Payout as FedaPayPayout;
use FedaPay\Transaction;
use FedaPay\WebhookSignature;
use Illuminate\Support\Facades\Log;

/**
 * Passerelle de paiement FedaPay (encaissement client + retraits).
 *
 * Encaissement : une transaction FedaPay est créée côté serveur puis un jeton
 * donne une URL de paiement hébergée (Checkout FedaPay) ouverte par le client.
 * Le montant est toujours recalculé côté serveur, jamais fourni par le client.
 *
 * Sans clé secrète configurée, le connecteur bascule en mode « sandbox » et
 * n'appelle aucune API : le paiement reste en attente (démo / tests).
 */
class FedaPayConnector implements PaymentGateway
{
    public const PROVIDER = 'fedapay';

    public function __construct()
    {
        if ($this->configured()) {
            FedaPay::setApiKey((string) config('fedapay.secret_key'));
            FedaPay::setEnvironment(config('fedapay.sandbox', true) ? 'sandbox' : 'live');

            if ($base = config('fedapay.api_base')) {
                FedaPay::setApiBase($base);
            }
        }
    }

    public function configured(): bool
    {
        return (bool) config('fedapay.enabled', true) && (bool) config('fedapay.secret_key');
    }

    /** @return array<string, mixed> */
    public function createPayment(Order $order): array
    {
        $order->loadMissing('user', 'payment');

        return $this->collect(
            amount: (int) round($order->total),
            description: 'Commande '.$order->reference,
            customer: $order->user,
            metadata: array_filter([
                'type' => 'order',
                'order_id' => $order->id,
                'payment_id' => $order->payment?->id,
            ]),
        );
    }

    /** @return array<string, mixed> */
    public function createPaymentForParcel(Parcel $parcel): array
    {
        $parcel->loadMissing('user', 'payment');

        return $this->collect(
            amount: (int) round($parcel->payment?->amount ?? $parcel->delivery_fee),
            description: 'Colis '.$parcel->reference,
            customer: $parcel->user,
            metadata: array_filter([
                'type' => 'parcel',
                'parcel_id' => $parcel->id,
                'payment_id' => $parcel->payment?->id,
            ]),
        );
    }

    /**
     * Crée un encaissement FedaPay pour la recharge du flottant d'un livreur.
     *
     * @return array<string, mixed>
     */
    public function createFloatTopUp(DriverProfile $driver, Payment $payment): array
    {
        $driver->loadMissing('user');

        return $this->collect(
            amount: (int) $payment->amount,
            description: 'Recharge flottant livreur',
            customer: $driver->user,
            metadata: array_filter([
                'type' => 'float_topup',
                'driver_id' => $driver->id,
                'payment_id' => $payment->id,
            ]),
        );
    }

    /**
     * Exécute un reversement Mobile Money via FedaPay.
     *
     * FedaPay attend un client (créé à la volée depuis le numéro cible) puis un
     * payout démarré immédiatement. Une panne réseau ne doit jamais marquer le
     * retrait exécuté : on renvoie un échec explicite que l'appelant pourra
     * re-créditer.
     *
     * @return array<string, mixed>
     */
    public function sendPayout(Payout $payout, string $destination, string $mode): array
    {
        if (! $this->configured()) {
            return [
                'ok' => false,
                'status' => 'unconfigured',
                'message' => 'FedaPay non configuré : le retrait reste à traiter manuellement.',
            ];
        }

        $currency = (string) config('fedapay.currency', 'XOF');

        try {
            $customer = Customer::create($this->payoutCustomerPayload($destination));

            $remote = FedaPayPayout::create([
                'customer' => ['id' => $customer->id],
                'currency' => ['iso' => $currency],
                'amount' => (int) $payout->amount,
                'mode' => $this->normalizePayoutMode($mode),
            ]);

            $remote->sendNow();

            return [
                'ok' => true,
                'status' => (string) $remote->status,
                'payout_id' => (string) $remote->id,
                'reference' => $remote->reference,
            ];
        } catch (\Throwable $e) {
            Log::warning('FedaPay payout failed', [
                'payout_id' => $payout->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'ok' => false,
                'status' => 'failed',
                'message' => 'Le virement n\'a pas pu être envoyé.',
            ];
        }
    }

    /**
     * Crée la transaction FedaPay puis génère le lien de paiement hébergé.
     *
     * Sans clés, renvoie un paiement simulé (aucun appel réseau) afin de laisser
     * le flux fonctionner en développement et en test.
     *
     * @param  array<string, mixed>  $metadata
     * @return array<string, mixed>
     */
    private function collect(int $amount, string $description, ?User $customer, array $metadata): array
    {
        $currency = (string) config('fedapay.currency', 'XOF');

        if (! $this->configured()) {
            return [
                'provider' => 'fedapay',
                'mode' => 'sandbox',
                'status' => 'pending',
                'amount' => $amount,
                'currency' => $currency,
                'transaction_id' => null,
                'reference' => null,
                'checkout_url' => null,
                'message' => 'Paiement enregistré — la confirmation interviendra une fois FedaPay configuré.',
                'meta' => $metadata,
            ];
        }

        try {
            $params = [
                'description' => $description,
                'amount' => $amount,
                'currency' => ['iso' => $currency],
                'callback_url' => $this->callbackUrl($metadata),
                'custom_metadata' => $metadata,
            ];

            $customerPayload = $this->customerPayload($customer);

            if ($customerPayload !== []) {
                $params['customer'] = $customerPayload;
            }

            $transaction = Transaction::create($params);

            $token = $transaction->generateToken();

            return [
                'provider' => 'fedapay',
                'mode' => 'live',
                'status' => 'pending',
                'amount' => $amount,
                'currency' => $currency,
                'transaction_id' => (string) $transaction->id,
                'reference' => $transaction->reference,
                'checkout_url' => $token->url,
                'token' => $token->token,
                'meta' => $metadata,
            ];
        } catch (\Throwable $e) {
            Log::warning('FedaPay transaction creation failed', ['error' => $e->getMessage()]);

            return [
                'provider' => 'fedapay',
                'mode' => 'live',
                'status' => 'failed',
                'amount' => $amount,
                'currency' => $currency,
                'transaction_id' => null,
                'reference' => null,
                'checkout_url' => null,
                'message' => 'Le paiement n\'a pas pu être préparé. Réessayez.',
            ];
        }
    }

    /** @return array<string, mixed> */
    public function verifyTransaction(string $transactionId): array
    {
        if (! $this->configured()) {
            return ['ok' => false, 'status' => 'unconfigured', 'message' => 'FedaPay non configuré.'];
        }

        if (! ctype_digit($transactionId)) {
            return ['ok' => false, 'status' => 'invalid', 'message' => 'Identifiant de transaction invalide.'];
        }

        try {
            /** @var Transaction $transaction */
            $transaction = Transaction::retrieve((int) $transactionId);

            return [
                'ok' => true,
                'status' => (string) $transaction->status,
                'paid' => $transaction->wasPaid(),
                'amount' => (int) $transaction->amount,
                'reference' => $transaction->reference,
                'data' => $transaction->__toArray(true),
            ];
        } catch (\Throwable $e) {
            Log::warning('FedaPay transaction verification failed', [
                'transaction_id' => $transactionId,
                'error' => $e->getMessage(),
            ]);

            return ['ok' => false, 'status' => 'error', 'message' => $e->getMessage()];
        }
    }

    public function verifyWebhookSignature(string $payload, ?string $signature): bool
    {
        $secret = config('fedapay.webhook_secret');

        if (! $secret) {
            return true;
        }

        if (! $signature) {
            return false;
        }

        try {
            WebhookSignature::verifyHeader($payload, $signature, (string) $secret);

            return true;
        } catch (\Throwable) {
            return false;
        }
    }

    /**
     * Normalise un événement FedaPay en une décision interne.
     *
     * @return array<string, mixed>
     */
    public function handleWebhook(array $payload): array
    {
        $name = (string) ($payload['name'] ?? $payload['event'] ?? $payload['type'] ?? 'unknown');

        $data = $payload['data']['transaction']
            ?? $payload['data']['payout']
            ?? $payload['data']['object']
            ?? $payload['data']
            ?? [];

        if (isset($data['object']) && is_array($data['object'])) {
            $data = $data['object'];
        }

        $metadata = $data['custom_metadata'] ?? $data['metadata'] ?? $payload['custom_metadata'] ?? $payload['metadata'] ?? [];
        if (is_string($metadata)) {
            $metadata = json_decode($metadata, true) ?: [];
        }

        return [
            'event' => $name,
            'status' => $this->normalizeStatus($name, (string) ($data['status'] ?? 'unknown')),
            'provider_status' => (string) ($data['status'] ?? 'unknown'),
            'transaction_id' => isset($data['id']) ? (string) $data['id'] : null,
            'reference' => isset($data['reference']) ? (string) $data['reference'] : null,
            'amount' => isset($data['amount']) ? (int) $data['amount'] : null,
            'type' => $metadata['type'] ?? null,
            'driver_id' => $metadata['driver_id'] ?? null,
            'order_id' => $metadata['order_id'] ?? null,
            'parcel_id' => $metadata['parcel_id'] ?? null,
            'payment_id' => $metadata['payment_id'] ?? null,
            'metadata' => $metadata,
            'raw' => $payload,
        ];
    }

    public function refund(Payment $payment, int $amount, ?string $reason = null): array
    {
        // FedaPay n'expose pas d'API de remboursement : l'opération se fait
        // depuis le tableau de bord marchand. Le flux reste donc manuel/tracé.
        return [
            'ok' => false,
            'status' => 'manual_required',
            'message' => 'Les remboursements FedaPay s\'effectuent depuis le tableau de bord marchand.',
        ];
    }

    private function normalizeStatus(string $event, string $status): string
    {
        $event = strtolower($event);
        $value = strtolower($status);

        if (str_contains($event, 'approved') || in_array($value, ['approved', 'transferred', 'success', 'successful', 'paid', 'completed', 'confirmed', 'sent'], true)) {
            return 'success';
        }

        if (str_contains($event, 'canceled') || in_array($value, ['canceled', 'cancelled'], true)) {
            return 'cancelled';
        }

        if (str_contains($event, 'declined') || in_array($value, ['declined', 'failed'], true)) {
            return 'failed';
        }

        return 'pending';
    }

    /**
     * @param  array<string, mixed>  $metadata
     */
    private function callbackUrl(array $metadata): string
    {
        $query = array_filter([
            'order_id' => $metadata['order_id'] ?? null,
            'parcel_id' => $metadata['parcel_id'] ?? null,
            'payment_id' => $metadata['payment_id'] ?? null,
        ]);

        $base = route('api.v1.payments.callback');

        return $query === [] ? $base : $base.'?'.http_build_query($query);
    }

    /** @return array<string, mixed> */
    private function customerPayload(?User $customer): array
    {
        if ($customer === null) {
            return [];
        }

        $parts = preg_split('/\s+/', trim((string) $customer->name)) ?: [];
        $firstname = $parts[0] ?? 'Client';
        $lastname = $parts[1] ?? 'Beninfood';

        $payload = [
            'firstname' => $firstname,
            'lastname' => $lastname,
        ];

        if ($customer->email && filter_var($customer->email, FILTER_VALIDATE_EMAIL)) {
            $payload['email'] = $customer->email;
        }

        $local = $customer->phone ? Phone::local($customer->phone) : null;

        if ($local !== null) {
            $payload['phone_number'] = [
                'number' => $local,
                'country' => (string) config('fedapay.merchant_country', 'bj'),
            ];
        }

        if (! isset($payload['email']) && ! isset($payload['phone_number'])) {
            // Sans coordonnée valide, on laisse FedaPay collecter l'email et le
            // numéro sur sa page de paiement plutôt que d'envoyer une donnée
            // invalide qui ferait échouer toute la transaction.
            return [];
        }

        return $payload;
    }

    /**
     * Client FedaPay minimal créé pour un reversement (numéro bénéficiaire).
     *
     * @return array<string, mixed>
     */
    private function payoutCustomerPayload(string $destination): array
    {
        $local = Phone::local($destination);

        $payload = [
            'firstname' => 'Beneficiaire',
            'lastname' => 'Beninfood',
            'email' => ($local ?? 'beneficiaire').'@payout.beninfood.bj',
        ];

        if ($local !== null) {
            $payload['phone'] = '+229'.$local;
        }

        return $payload;
    }

    /**
     * Normalise le réseau de retrait vers un mode FedaPay valide.
     */
    private function normalizePayoutMode(?string $mode): string
    {
        $mode = strtolower((string) $mode);

        return in_array($mode, ['mtn_open', 'moov', 'sbin'], true)
            ? $mode
            : (string) config('fedapay.default_payout_mode', 'mtn_open');
    }
}
