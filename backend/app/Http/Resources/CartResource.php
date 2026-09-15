<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CartResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $subtotal = $this->items->sum(fn ($item) => (int) ($item->product?->price ?? $item->unit_price) * $item->quantity);

        return [
            'id' => $this->id,
            'vendor' => $this->whenLoaded('vendor', fn () => [
                'id' => $this->vendor->id,
                'business_name' => $this->vendor->business_name,
                'logo_url' => $this->vendor->logo_url,
            ]),
            'items' => CartItemResource::collection($this->whenLoaded('items')),
            'subtotal' => $subtotal,
            'currency' => 'XOF',
            'items_count' => $this->whenLoaded('items', fn () => $this->items->count()),
            'status' => $this->status?->value,
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
