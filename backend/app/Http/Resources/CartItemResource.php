<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class CartItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $product = $this->product;
        $originalPrice = (int) ($product?->price ?? $this->unit_price);
        $unitPrice = $product?->effectivePrice() ?? (int) $this->unit_price;
        $promotion = $product?->activePromotion;
        $discountPercent = $originalPrice > 0 && $unitPrice < $originalPrice
            ? (int) round((($originalPrice - $unitPrice) / $originalPrice) * 100)
            : 0;

        return [
            'id' => $this->id,
            'product' => [
                'id' => $this->product_id,
                'name' => $product?->name,
                'unit' => $product?->unit,
                'unit_price' => $unitPrice,
                'original_price' => $originalPrice,
                'discount_percent' => $discountPercent,
                'image_url' => $product?->image_main
                    ? Storage::disk('public')->url($product->image_main)
                    : null,
            ],
            'quantity' => $this->quantity,
            'subtotal' => $unitPrice * $this->quantity,
            'savings' => ($originalPrice - $unitPrice) * $this->quantity,
            'currency' => 'XOF',
            'promotion' => $promotion !== null ? [
                'id' => $promotion->id,
                'title' => $promotion->title,
                'promo_price' => (int) $promotion->promo_price,
                'ends_at' => $promotion->ends_at?->toIso8601String(),
            ] : null,
        ];
    }
}
