<?php

namespace Tests\Unit;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\Order;
use App\Services\RefundService;
use Tests\TestCase;

class RefundDeterminationTest extends TestCase
{
    private RefundService $service;

    protected function setUp(): void
    {
        parent::setUp();

        config()->set('beninfood.cancel.preparation_fee', 1000);
        config()->set('beninfood.cancel.assignment_fee', 500);

        $this->service = app(RefundService::class);
    }

    private function order(int $total, OrderStatus $status, PaymentStatus $payment = PaymentStatus::Confirmed): Order
    {
        return new Order([
            'total' => $total,
            'status' => $status,
            'payment_status' => $payment,
        ]);
    }

    public function test_unconfirmed_payment_never_refunds(): void
    {
        $order = $this->order(5000, OrderStatus::Paid, PaymentStatus::Initiated);

        $decision = $this->service->determineRefund($order, 'client');

        $this->assertSame('none', $decision['type']);
        $this->assertSame(0, $decision['amount']);
    }

    public function test_vendor_actor_always_gets_total_refund(): void
    {
        $order = $this->order(5000, OrderStatus::Preparing, PaymentStatus::Confirmed);

        $decision = $this->service->determineRefund($order, 'vendor');

        $this->assertSame('total', $decision['type']);
        $this->assertSame(5000, $decision['amount']);
    }

    public function test_client_cancel_early_statuses_refund_total(): void
    {
        foreach ([OrderStatus::AwaitingPayment, OrderStatus::Paid, OrderStatus::Accepted] as $status) {
            $decision = $this->service->determineRefund($this->order(5000, $status), 'client');

            $this->assertSame('total', $decision['type']);
            $this->assertSame(5000, $decision['amount']);
            $this->assertSame(0, $decision['fees']);
        }
    }

    public function test_client_cancel_preparing_applies_preparation_fee(): void
    {
        foreach ([OrderStatus::Preparing, OrderStatus::Ready] as $status) {
            $decision = $this->service->determineRefund($this->order(5000, $status), 'client');

            $this->assertSame('partial', $decision['type']);
            $this->assertSame(4000, $decision['amount']);
            $this->assertSame(1000, $decision['fees']);
        }
    }

    public function test_client_cancel_assigned_applies_assignment_fee(): void
    {
        $decision = $this->service->determineRefund($this->order(5000, OrderStatus::Assigned), 'client');

        $this->assertSame('partial', $decision['type']);
        $this->assertSame(4500, $decision['amount']);
        $this->assertSame(500, $decision['fees']);
    }

    public function test_client_cancel_once_delivered_refunds_nothing(): void
    {
        $decision = $this->service->determineRefund($this->order(5000, OrderStatus::Delivered), 'client');

        $this->assertSame('none', $decision['type']);
        $this->assertSame(0, $decision['amount']);
    }

    public function test_porteuse_override_is_capped_to_total(): void
    {
        $decision = $this->service->determineRefund($this->order(3000, OrderStatus::Paid), 'porteuse', overrideAmount: 4000);

        $this->assertSame('total', $decision['type']);
        $this->assertSame(3000, $decision['amount']);
        $this->assertSame(0, $decision['fees']);
    }

    public function test_porteuse_partial_override_keeps_fees(): void
    {
        $decision = $this->service->determineRefund($this->order(5000, OrderStatus::Paid), 'porteuse', overrideAmount: 2000);

        $this->assertSame('partial', $decision['type']);
        $this->assertSame(2000, $decision['amount']);
        $this->assertSame(3000, $decision['fees']);
    }

    public function test_porteuse_override_zero_is_none(): void
    {
        $decision = $this->service->determineRefund($this->order(5000, OrderStatus::Paid), 'porteuse', overrideAmount: 0);

        $this->assertSame('none', $decision['type']);
        $this->assertSame(0, $decision['amount']);
    }

    public function test_status_at_cancellation_is_used_when_order_already_cancelled(): void
    {
        $order = $this->order(5000, OrderStatus::Cancelled, PaymentStatus::Confirmed);

        $decision = $this->service->determineRefund($order, 'client', statusAtCancellation: OrderStatus::Preparing);

        $this->assertSame(4000, $decision['amount']);
    }
}
