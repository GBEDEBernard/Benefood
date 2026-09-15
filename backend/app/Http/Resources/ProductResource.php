<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'vendor_id' => $this->vendor_id,
            'vendor_name' => $this->whenLoaded('vendor', fn () => $this->vendor->business_name),
            'category_id' => $this->category_id,
            'category' => $this->whenLoaded('category', fn () => [
                'id' => $this->category->id,
                'name' => $this->category->name,
                'slug' => $this->category->slug,
            ]),
            'name' => $this->name,
            'description' => $this->description,
            'unit' => $this->unit,
            'price' => $this->price,
            'currency' => 'XOF',
            'stock_qty' => $this->stock_qty,
            'image_main' => $this->image_main,
            'image_url' => $this->image_main ? Storage::disk('public')->url($this->image_main) : null,
            'images' => $this->whenLoaded('images', fn () => $this->images->map(fn ($image) => [
                'id' => $image->id,
                'url' => Storage::disk('public')->url($image->path),
                'thumb_url' => Storage::disk('public')->url($image->thumb_path),
                'is_main' => (bool) $image->is_main,
                'sort_order' => $image->sort_order,
            ])->values()),
            'is_active' => (bool) $this->is_active,
            'is_available' => (bool) $this->is_available,
            'is_orderable' => $this->isOrderable(),
            'status' => $this->status,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
