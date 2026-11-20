<?php

namespace App\Http\Resources;

use App\Support\GeoFields;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AddressResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $geo = GeoFields::payload($this->resource);

        return [
            'id' => $this->id,
            'label' => $this->label,
            'zone_id' => $this->zone_id,
            'is_default' => (bool) $this->is_default,
            'full_address' => $this->full_address,
            'landmark' => $this->landmark,
            'contact_phone' => $this->contact_phone,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'city' => $this->city,
            'area' => $this->area,
            'country_code' => $geo['country']['code'] ?? null,
            'division_id' => $this->division_id,
            'locality_id' => $this->locality_id,
            'geographic_path' => $geo['geographic_path'],
            'geo' => $geo,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
