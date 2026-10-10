<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ParcelResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'reference' => $this->reference,
            'status' => $this->status?->value,
            'payment_status' => $this->payment_status?->value,
            'description' => $this->description,
            'currency' => $this->currency,
            'pickup' => $this->pickup_snapshot,
            'dropoff' => $this->dropoff_snapshot,
            'distance_km' => $this->distance_km !== null ? (float) $this->distance_km : null,
            'delivery_fee' => (int) $this->delivery_fee,
            'commission_rate' => (int) $this->commission_rate,
            'commission_amount' => (int) $this->commission_amount,
            'partner_amount' => (int) $this->partner_amount,
            'platform_amount' => (int) $this->platform_amount,
            'proof_code' => $this->proof_code,
            'driver' => $this->whenLoaded('driverProfile', fn () => $this->driverProfile === null ? null : [
                'id' => $this->driverProfile->id,
                'name' => $this->driverProfile->user?->name,
                'phone' => $this->driverProfile->user?->phone,
                'vehicle' => $this->driverProfile->vehicle,
                'rating' => $this->driverProfile->rating,
            ]),
            'payment' => $this->whenLoaded('payment', fn () => $this->payment === null ? null : [
                'id' => $this->payment->id,
                'reference' => $this->payment->reference,
                'status' => $this->payment->status?->value,
                'amount' => (int) $this->payment->amount,
            ]),
            'status_history' => $this->whenLoaded('statusHistory', fn () => $this->statusHistory->map(fn ($history) => [
                'from_status' => $history->from_status,
                'to_status' => $history->to_status,
                'actor_type' => $history->actor_type,
                'reason' => $history->reason,
                'created_at' => $history->created_at?->toIso8601String(),
            ])->values()),
            'payment_deadline_at' => $this->payment_deadline_at?->toIso8601String(),
            'assigned_at' => $this->assigned_at?->toIso8601String(),
            'picked_up_at' => $this->picked_up_at?->toIso8601String(),
            'delivered_at' => $this->delivered_at?->toIso8601String(),
            'cancelled_at' => $this->cancelled_at?->toIso8601String(),
            'cancellation_reason' => $this->cancellation_reason,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
