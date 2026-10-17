<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $imagePath = $this->image_main;
        if ($this->resource->relationLoaded('images')) {
            $primaryImage = $this->resource->getRelation('images')->firstWhere('is_main', true)
                ?? $this->resource->getRelation('images')->first();
            $imagePath = $primaryImage?->path ?? $imagePath;
        }

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
            'image_url' => $this->mediaUrl($imagePath),
            'video_url' => $this->mediaUrl($this->video_path),
            'images' => $this->whenLoaded('images', fn () => $this->images->map(fn ($image) => [
                'id' => $image->id,
                'url' => $this->mediaUrl($image->path),
                'thumb_url' => $this->mediaUrl($image->thumb_path),
                'is_main' => (bool) $image->is_main,
                'sort_order' => $image->sort_order,
            ])->values()),
            'is_active' => (bool) $this->is_active,
            'is_available' => (bool) $this->is_available,
            'is_orderable' => $this->isOrderable(),
            'status' => $this->status,
            'rating' => $this->reviews_avg_rating !== null
                ? round((float) $this->reviews_avg_rating, 1)
                : null,
            'reviews_count' => $this->reviews_count ?? 0,
            'likes_count' => $this->favorites_count ?? 0,
            'distance_km' => $this->distance_km !== null ? round((float) $this->distance_km, 1) : null,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
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

        $path = ltrim($path, '/');
        if (str_starts_with($path, 'storage/')) {
            $path = substr($path, strlen('storage/'));
        }

        return Storage::disk('public')->url($path);
    }
}
