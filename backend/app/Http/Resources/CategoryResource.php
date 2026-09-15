<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CategoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'parent_id' => $this->parent_id,
            'name' => $this->name,
            'slug' => $this->slug,
            'icon_path' => $this->icon_path,
            'sort_order' => $this->sort_order,
            'is_active' => (bool) $this->is_active,
            'children' => CategoryResource::collection($this->whenLoaded('children')?->where('is_active', true)->values()),
            'products_count' => $this->whenCounted('products'),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
