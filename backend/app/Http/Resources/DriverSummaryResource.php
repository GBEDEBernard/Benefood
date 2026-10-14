<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Fiche compacte d'un livreur (favoris, candidats, sélecteur mobile).
 */
class DriverSummaryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'name' => $this->user?->name,
            'phone' => $this->user?->phone,
            'vehicle' => $this->vehicle,
            'rating' => $this->rating,
            'status' => $this->status,
        ];
    }
}
