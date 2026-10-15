<?php

namespace Tests\Fakes;

use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\Payment;
use App\Models\Payout;
use App\Services\Payments\PaymentGateway;

/**
 * Passerelle de paiement factice : renvoie des charges utiles prédéfinies sans
 * aucun appel réseau, afin de tester les branches « FedaPay configuré ».
 */
final class PaymentGatewayFake implements PaymentGateway
{
    public bool $configured = true;

    /** @var array<string, mixed>|null */
    public ?array $floatTopUp = null;

    /** @var array<string, mixed>|null  Charge utile de collecte forcée (tests d'échec). */
    public ?array $collectResult = null;

    /** @var array<string, mixed> */
    public array $verifyResult = [
        'ok' => true,
        'status' => 'approved',
        'paid' => false,
    ];

    /** @var array<string, mixed> */
    public array $payoutResult = [
        'ok' => true,
        'status' => 'sent',
        'payout_id' => 'PO-123',
        'reference' => 'REF-123',
    ];

    /** @var array<string, mixed> */
    public array $webhookEvent = [];

    /** @var list<array{0: Payout, 1: string, 2: string}> */
    public array $payoutCalls = [];

    public function __construct(
        private readonly string $transactionId = 'TX-123',
        private readonly string $checkoutUrl = 'https://checkout.fedapay.test/TX-123',
    ) {}

    public function configured(): bool
    {
        return $this->configured;
    }

    /** @return array<string, mixed> */
    public function createPayment(Order $order): array
    {
        return $this->collectResult ?? $this->collectPayload((int) $order->total);
    }

    /** @return array<string, mixed> */
    public function createPaymentForParcel(Parcel $parcel): array
    {
        return $this->collectResult ?? $this->collectPayload((int) ($parcel->payment?->amount ?? $parcel->delivery_fee));
    }

    /** @return array<string, mixed> */
    public function createFloatTopUp(DriverProfile $driver, Payment $payment): array
    {
        return $this->floatTopUp ?? $this->collectPayload((int) $payment->amount);
    }

    /** @return array<string, mixed> */
    public function sendPayout(Payout $payout, string $destination, string $mode): array
    {
        $this->payoutCalls[] = [$payout, $destination, $mode];

        return $this->payoutResult;
    }

    /** @return array<string, mixed> */
    public function verifyTransaction(string $transactionId): array
    {
        return $this->verifyResult + ['transaction_id' => $transactionId];
    }

    public function verifyWebhookSignature(string $payload, ?string $signature): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function handleWebhook(array $payload): array
    {
        return $this->webhookEvent;
    }

    /** @return array<string, mixed> */
    public function refund(Payment $payment, int $amount, ?string $reason = null): array
    {
        return ['ok' => true];
    }

    /** @return array<string, mixed> */
    private function collectPayload(int $amount): array
    {
        return [
            'provider' => 'fedapay',
            'mode' => 'live',
            'status' => 'pending',
            'amount' => $amount,
            'currency' => 'XOF',
            'transaction_id' => $this->transactionId,
            'reference' => 'REF-'.$this->transactionId,
            'checkout_url' => $this->checkoutUrl,
            'token' => 'tok-'.$this->transactionId,
        ];
    }
}
