<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class GeoCountryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'code' => $this->code,
            'name' => $this->name,
            'official_name' => $this->official_name,
            'hierarchy' => $this->hierarchy(),
            'locality_label' => $this->locality_label,
            'source' => $this->source,
            'source_url' => $this->source_url,
            'data_updated_at' => $this->data_updated_at?->toDateString(),
        ];
    }
}
