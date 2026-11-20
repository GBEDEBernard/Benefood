<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class GeoLocalityResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'country_id' => $this->country_id,
            'division_id' => $this->division_id,
            'code' => $this->code,
            'name' => $this->name,
            'kind' => $this->kind,
            'administrative_status' => $this->administrative_status,
            'label' => $this->displayPath(),
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'source' => $this->source,
            'source_url' => $this->source_url,
            'data_updated_at' => $this->data_updated_at?->toDateString(),
        ];
    }
}
