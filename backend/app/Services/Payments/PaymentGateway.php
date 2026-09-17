<?php

namespace App\Services\Payments;

use App\Models\Order;
use App\Models\Payment;

interface PaymentGateway
{
    /**
     * Create a payment session/link for an order and return provider payload.
     */
    public function createPayment(Order $order): array;

    /**
     * Verify a transaction with the provider and return verification result.
     */
    public function verifyTransaction(string $transactionId): array;

    /**
     * Handle incoming webhook payload and return standardized result.
     */
    public function handleWebhook(array $payload): array;

    /**
     * Request a refund from the provider. Return provider result payload.
     *
     * @return array<string, mixed>
     */
    public function refund(Payment $payment, int $amount, ?string $reason = null): array;
}
