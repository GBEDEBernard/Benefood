<?php

namespace App\Http\Resources;

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
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
