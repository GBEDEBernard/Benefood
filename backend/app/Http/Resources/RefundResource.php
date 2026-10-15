<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RefundResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'order_id' => $this->order_id,
            'order' => $this->when($this->order_id !== null && $this->relationLoaded('order'), fn () => [
                'id' => $this->order->id,
                'reference' => $this->order->reference,
                'status' => $this->order->status?->value,
            ]),
            'parcel_id' => $this->parcel_id,
            'parcel' => $this->when($this->parcel_id !== null && $this->relationLoaded('parcel'), fn () => [
                'id' => $this->parcel->id,
                'reference' => $this->parcel->reference,
                'status' => $this->parcel->status?->value,
            ]),
            'payment_id' => $this->payment_id,
            'amount' => $this->amount,
            'reason' => $this->reason,
            'status' => $this->status?->value,
            'gateway_refund_id' => $this->gateway_refund_id,
            'executed_at' => $this->executed_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
