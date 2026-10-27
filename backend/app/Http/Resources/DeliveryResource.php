<?php

namespace App\Http\Resources;

use App\Models\DeliveryAssignment;
use App\Services\PlatformPricingSettings;
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
            $rate = app(PlatformPricingSettings::class)->get('delivery_commission_rate');
            $commission = (int) round((int) $this->fee * $rate / 100);
            $partnerAmount = (int) $this->fee - $commission;
        }

        return [
            'id' => $this->id,
            'status' => $this->status?->value,
            'fee' => $this->fee,
            'client_delivery_fee' => (int) $this->fee,
            'partner_amount' => $partnerAmount,
            'driver_earnings' => $partnerAmount,
            'targeted_driver_id' => $this->targeted_driver_profile_id,
            'pickup' => $this->pickupPayload($order),
            'dropoff' => $this->dropoffPayload($order),
            'currency' => $order !== null ? ($order->currency ?? 'XOF') : 'XOF',
            'order' => $this->whenLoaded('order', fn () => [
                'id' => $order->id,
                'reference' => $order->reference,
                'status' => $order->status?->value,
                'total' => $order->total,
                'subtotal' => $order->subtotal,
                'delivery_fee' => $order->delivery_fee,
                'address' => $order->address_snapshot,
                'client' => $order !== null && $order->relationLoaded('user') ? [
                    'id' => $order->user->id,
                    'name' => $order->user->name,
                    'phone' => $order->user->phone,
                    'avatar_url' => $this->mediaUrl($order->user->avatar_path),
                ] : null,
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
                'type' => $this->vendor->type?->value,
                'logo_url' => $this->mediaUrl($this->vendor->logo_url),
                'cover_url' => $this->mediaUrl($this->vendor->cover_url),
                'address' => $this->vendor->address,
                'city' => $this->vendor->city,
                'phone' => $this->vendor->phone,
                'latitude' => $this->vendor->latitude,
                'longitude' => $this->vendor->longitude,
                'pickup_latitude' => $this->vendor->pickup_latitude,
                'pickup_longitude' => $this->vendor->pickup_longitude,
                'pickup_landmark' => $this->vendor->pickup_landmark,
            ]),
            'pending_handover' => $this->whenLoaded('assignments', function () {
                $assignment = $this->assignments
                    ->first(fn ($item) => $item->status === DeliveryAssignment::STATUS_PENDING_HANDOVER);

                return $assignment === null ? null : [
                    'id' => $assignment->id,
                    'sequence' => $assignment->sequence,
                    'base_fee' => $assignment->base_fee,
                    'approach_fee' => $assignment->approach_fee,
                    'partner_amount' => $assignment->partner_amount,
                ];
            }),
            'driver' => $this->whenLoaded('driverProfile', fn () => [
                'id' => $this->driverProfile->id,
                'user_id' => $this->driverProfile->user_id,
                'name' => $this->driverProfile->user?->name,
                'avatar_url' => $this->mediaUrl($this->driverProfile->user?->avatar_path),
                'vehicle' => $this->driverProfile->vehicle,
                'rating' => $this->driverProfile->rating,
            ]),
            'created_at' => $this->created_at?->toIso8601String(),
            'assigned_at' => $this->assigned_at?->toIso8601String(),
            'picked_up_at' => $this->picked_up_at?->toIso8601String(),
            'delivered_at' => $this->delivered_at?->toIso8601String(),
        ];
    }

    /**
     * Point de collecte figé sur la course, avec repli sur la boutique et son
     * adresse de retrait pour les livraisons antérieures à la migration.
     *
     * @return array<string, mixed>
     */
    private function pickupPayload($order): array
    {
        $vendor = $this->relationLoaded('vendor') ? $this->vendor : null;

        return [
            'latitude' => $this->pickup_latitude ?? $vendor?->pickup_latitude ?? $vendor?->latitude,
            'longitude' => $this->pickup_longitude ?? $vendor?->pickup_longitude ?? $vendor?->longitude,
            'address' => $vendor?->pickup_address ?? $vendor?->address,
            'landmark' => $vendor?->pickup_landmark,
            'phone' => $vendor?->phone,
        ];
    }

    /**
     * Point de livraison figé sur la course, avec repli sur le snapshot de
     * commande pour les courses existantes.
     *
     * @return array<string, mixed>
     */
    private function dropoffPayload($order): array
    {
        $address = $order?->address_snapshot ?? [];

        return [
            'latitude' => $this->dropoff_latitude ?? $address['latitude'] ?? null,
            'longitude' => $this->dropoff_longitude ?? $address['longitude'] ?? null,
            'address' => $address['full_address'] ?? null,
            'landmark' => $this->dropoff_landmark ?? $address['landmark'] ?? null,
            'phone' => $this->dropoff_phone ?? $address['contact_phone'] ?? null,
        ];
    }

    private function mediaUrl(?string $path): ?string
    {
        if ($path === null || $path === '') {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        return Storage::disk('public')->url($path);
    }
}
