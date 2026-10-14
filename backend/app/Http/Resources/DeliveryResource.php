<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class DeliveryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $loaded = $this->resource->relationLoaded('order');
        $order = $loaded ? $this->order : null;

        // La part livreur est figée à la préparation de la commande ; on retombe
        // sur la ventilation financière de la commande, puis sur un calcul
        // (frais − commission) pour les courses historiques (partner_amount à 0).
        $partnerAmount = (int) $this->partner_amount;

        if ($partnerAmount === 0 && $order !== null && $order->relationLoaded('financials')) {
            $partnerAmount = (int) ($order->financials?->delivery_partner_amount ?? 0);
        }

        if ($partnerAmount === 0 && (int) $this->fee > 0) {
            $rate = (int) config('beninfood.delivery_commission.rate', 20);
            $commission = (int) round((int) $this->fee * $rate / 100);
            $partnerAmount = (int) $this->fee - $commission;
        }

        return [
            'id' => $this->id,
            'status' => $this->status?->value,
            'fee' => $this->fee,
            'partner_amount' => $partnerAmount,
            'targeted_driver_id' => $this->targeted_driver_profile_id,
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
                'items' => $order->relationLoaded('items')
                    ? $order->items->map(fn ($item) => [
                        'id' => $item->id,
                        'product_id' => $item->product_id,
                        'name' => $item->name_snapshot,
                        'quantity' => $item->quantity,
                        'unit_price' => $item->unit_price_snapshot,
                        'subtotal' => $item->subtotal,
                        'currency' => 'XOF',
                        'image_url' => $item->product?->image_main !== null
                            ? Storage::disk('public')->url($item->product->image_main)
                            : null,
                    ])->values()
                    : [],
            ]),
            'vendor' => $this->whenLoaded('vendor', fn () => [
                'id' => $this->vendor->id,
                'business_name' => $this->vendor->business_name,
                'address' => $this->vendor->address,
                'city' => $this->vendor->city,
                'phone' => $this->vendor->phone,
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
