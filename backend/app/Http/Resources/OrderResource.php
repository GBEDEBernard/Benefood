<?php

namespace App\Http\Resources;

use App\Enums\DeliveryStatus;
use App\Models\DriverProfile;
use App\Services\DeliveryPricingService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $items = $this->whenLoaded('items', fn () => $this->items->map(fn ($item) => [
            'id' => $item->id,
            'product_id' => $item->product_id,
            'name' => $item->name_snapshot,
            'quantity' => $item->quantity,
            'unit_price' => $item->unit_price_snapshot,
            'subtotal' => $item->subtotal,
            'currency' => 'XOF',
        ])->values());

        return [
            'id' => $this->id,
            'reference' => $this->reference,
            'status' => $this->status?->value,
            'payment_status' => $this->payment_status?->value,
            'vendor' => $this->whenLoaded('vendor', fn () => [
                'id' => $this->vendor->id,
                'business_name' => $this->vendor->business_name,
                'logo_url' => $this->vendor->logo_url,
            ]),
            'currency' => $this->currency,
            'subtotal' => $this->subtotal,
            'discount' => $this->discount,
            'delivery_fee' => $this->delivery_fee,
            'total' => $this->total,
            'delivery_address' => $this->address_snapshot,
            'delivery' => $this->whenLoaded('delivery', fn () => $this->deliveryPayload()),
            'payment' => $this->whenLoaded('payment', fn () => [
                'id' => $this->payment->id,
                'reference' => $this->payment->reference,
                'gateway' => $this->payment->gateway,
                'amount' => $this->payment->amount,
                'status' => $this->payment->status?->value,
                'currency' => $this->payment->currency,
            ]),
            'financials' => $this->whenLoaded('financials', fn () => [
                'commission_rate' => $this->financials->commission_rate,
                'commission_amount' => $this->financials->commission_amount,
                'vendor_amount' => $this->financials->vendor_amount,
                'platform_amount' => $this->financials->platform_amount,
                'delivery_partner_amount' => $this->financials->delivery_partner_amount,
                'total_client' => $this->financials->total_client,
            ]),
            'items' => $items,
            'status_history' => $this->whenLoaded('statusHistory', fn () => $this->statusHistory->map(fn ($history) => [
                'from_status' => $history->from_status,
                'to_status' => $history->to_status,
                'actor_type' => $history->actor_type,
                'reason' => $history->reason,
                'created_at' => $history->created_at?->toIso8601String(),
            ])->values()),
            'payment_deadline_at' => $this->payment_deadline_at?->toIso8601String(),
            'vendor_acceptance_deadline_at' => $this->vendor_acceptance_deadline_at?->toIso8601String(),
            'accepted_at' => $this->accepted_at?->toIso8601String(),
            'cancellation_reason' => $this->cancellation_reason,
            'cancelled_by' => $this->cancelled_by,
            'cancelled_at' => $this->cancelled_at?->toIso8601String(),
            'refunds' => $this->whenLoaded('refunds', fn () => $this->refunds->map(fn ($refund) => [
                'id' => $refund->id,
                'amount' => $refund->amount,
                'reason' => $refund->reason,
                'status' => $refund->status?->value,
                'created_at' => $refund->created_at?->toIso8601String(),
            ])->values()),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }

    /**
     * Détail de la livraison côté client (J177) : livreur assigné et, pendant
     * la course active uniquement, sa position approximative (protection des
     * données de localisation — J178).
     *
     * @return array<string, mixed>
     */
    private function deliveryPayload(): array
    {
        $delivery = $this->delivery;
        $driver = $delivery->driverProfile;

        $active = in_array(
            $delivery->status,
            [DeliveryStatus::Assigned, DeliveryStatus::PickedUp, DeliveryStatus::InDelivery],
            true,
        );

        $payload = [
            'id' => $delivery->id,
            'status' => $delivery->status?->value,
            'assigned_at' => $delivery->assigned_at?->toIso8601String(),
            'picked_up_at' => $delivery->picked_up_at?->toIso8601String(),
            'delivered_at' => $delivery->delivered_at?->toIso8601String(),
            'driver' => $driver === null ? null : [
                'id' => $driver->id,
                'name' => $driver->user?->name,
                'vehicle' => $driver->vehicle,
                'rating' => $driver->rating,
            ],
            'position' => null,
        ];

        if (! $active || $driver === null || $driver->last_latitude === null || $driver->last_longitude === null) {
            return $payload;
        }

        $payload['position'] = [
            'latitude' => round((float) $driver->last_latitude, 3),
            'longitude' => round((float) $driver->last_longitude, 3),
            'last_location_at' => $driver->last_location_at?->toIso8601String(),
            'distance_km' => $this->distanceToClient($driver),
        ];

        return $payload;
    }

    /** Distance entre le livreur et l'adresse de livraison (ha versine). */
    private function distanceToClient(DriverProfile $driver): ?float
    {
        $address = $this->address_snapshot;
        $lat = $address['latitude'] ?? null;
        $lng = $address['longitude'] ?? null;

        if ($lat === null || $lng === null) {
            return null;
        }

        return app(DeliveryPricingService::class)->distanceKm(
            $driver->last_latitude,
            $driver->last_longitude,
            $lat,
            $lng,
        );
    }
}
