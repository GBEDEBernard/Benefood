<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class CartItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'product' => [
                'id' => $this->product_id,
                'name' => $this->product?->name,
                'unit' => $this->product?->unit,
                'unit_price' => (int) $this->unit_price,
                'image_url' => $this->product?->image_main
                    ? Storage::disk('public')->url($this->product->image_main)
                    : null,
            ],
            'quantity' => $this->quantity,
            'subtotal' => $this->subtotal,
            'currency' => 'XOF',
        ];
    }
}
