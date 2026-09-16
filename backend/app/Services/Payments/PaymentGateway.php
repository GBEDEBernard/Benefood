<?php

namespace App\Services\Payments;

use App\Models\Order;

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
}
