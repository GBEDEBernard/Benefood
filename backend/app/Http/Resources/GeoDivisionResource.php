<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class GeoDivisionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'country_id' => $this->country_id,
            'parent_id' => $this->parent_id,
            'level' => $this->level,
            'code' => $this->code,
            'name' => $this->name,
            'path' => $this->path(),
            'label' => $this->displayPath(),
            'center' => [
                'latitude' => $this->center_latitude,
                'longitude' => $this->center_longitude,
            ],
            'bbox' => [
                'min_latitude' => $this->bbox_min_latitude,
                'max_latitude' => $this->bbox_max_latitude,
                'min_longitude' => $this->bbox_min_longitude,
                'max_longitude' => $this->bbox_max_longitude,
            ],
            'source' => $this->source,
            'source_url' => $this->source_url,
            'data_updated_at' => $this->data_updated_at?->toDateString(),
        ];
    }
}
