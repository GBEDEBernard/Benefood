<?php

namespace Database\Factories;

use App\Enums\PaymentStatus;
use App\Models\Order;
use App\Models\Payment;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Payment>
 */
class PaymentFactory extends Factory
{
    protected $model = Payment::class;

    public function definition(): array
    {
        return [
            'order_id' => Order::factory(),
            'reference' => 'PAY-'.strtoupper(fake()->bothLetters(12)),
            'gateway' => 'kkiapay',
            'gateway_txn_id' => null,
            'amount' => fake()->numberBetween(500, 50000),
            'currency' => 'XOF',
            'status' => PaymentStatus::Initiated,
            'payload' => null,
            'paid_at' => null,
            'expires_at' => now()->addMinutes(15),
        ];
    }

    public function initiated(): static
    {
        return $this->state(['status' => PaymentStatus::Initiated]);
    }

    public function pending(): static
    {
        return $this->state(['status' => PaymentStatus::Pending]);
    }

    public function confirmed(): static
    {
        return $this->state([
            'status' => PaymentStatus::Confirmed,
            'paid_at' => now(),
            'gateway_txn_id' => fake()->uuid(),
        ]);
    }

    public function failed(): static
    {
        return $this->state(['status' => PaymentStatus::Failed]);
    }

    public function expired(): static
    {
        return $this->state(['status' => PaymentStatus::Expired]);
    }

    public function cancelled(): static
    {
        return $this->state(['status' => PaymentStatus::Cancelled]);
    }

    public function withTransaction(string $txnId): static
    {
        return $this->state(['gateway_txn_id' => $txnId]);
    }
}
