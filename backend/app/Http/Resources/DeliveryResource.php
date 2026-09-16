<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DeliveryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $loaded = $this->resource->relationLoaded('order');
        $order = $loaded ? $this->order : null;

        return [
            'id' => $this->id,
            'status' => $this->status?->value,
            'fee' => $this->fee,
            'partner_amount' => $this->partner_amount,
            'currency' => $order !== null ? ($order->currency ?? 'XOF') : 'XOF',
            'order' => $this->whenLoaded('order', fn () => [
                'id' => $order->id,
                'reference' => $order->reference,
                'status' => $order->status?->value,
                'total' => $order->total,
                'subtotal' => $order->subtotal,
                'delivery_fee' => $order->delivery_fee,
                'address' => $order->address_snapshot,
                'client' => $this->whenLoaded('order.user', fn () => [
                    'id' => $order->user->id,
                    'name' => $order->user->name,
                    'phone' => $order->user->phone,
                ]),
            ]),
            'vendor' => $this->whenLoaded('vendor', fn () => [
                'id' => $this->vendor->id,
                'business_name' => $this->vendor->business_name,
                'address' => $this->vendor->address,
                'city' => $this->vendor->city,
                'latitude' => $this->vendor->latitude,
                'longitude' => $this->vendor->longitude,
            ]),
            'driver' => $this->whenLoaded('driverProfile', fn () => [
                'id' => $this->driverProfile->id,
                'user_id' => $this->driverProfile->user_id,
                'vehicle' => $this->driverProfile->vehicle,
                'rating' => $this->driverProfile->rating,
            ]),
            'proof_code' => $this->proof_code,
            'created_at' => $this->created_at?->toIso8601String(),
            'assigned_at' => $this->assigned_at?->toIso8601String(),
            'picked_up_at' => $this->picked_up_at?->toIso8601String(),
            'delivered_at' => $this->delivered_at?->toIso8601String(),
        ];
    }
}
