<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ReviewResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'rating' => $this->rating,
            'driver_rating' => $this->driver_rating,
            'comment' => $this->comment,
            'status' => $this->status,
            'customer_name' => $this->whenLoaded('user', fn () => $this->user?->name),
            'order_reference' => $this->whenLoaded('order', fn () => $this->order?->reference),
            'products' => $this->whenLoaded('items', fn () => $this->items->map(fn ($item) => [
                'product_id' => $item->product_id,
                'name' => $item->product?->name,
                'image_url' => $item->product?->image_main,
            ])->values()),
            'vendor_reply' => $this->vendor_reply,
            'vendor_replied_at' => $this->vendor_replied_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
