<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

/**
 * Demande explicite du client à un livreur proche.
 *
 * Aucun numéro de téléphone n'est exposé ici : le contact n'est disponible
 * qu'une fois la course effectivement affectée (OrderResource/ParcelResource).
 */
class DriverAssignmentRequestResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $driver = $this->relationLoaded('driverProfile') ? $this->driverProfile : null;

        return [
            'id' => $this->id,
            'status' => $this->status?->value,
            'driver' => $driver === null ? null : [
                'id' => $driver->id,
                'name' => $driver->user?->name,
                'avatar_url' => $this->mediaUrl($driver->user?->avatar_path),
                'vehicle' => $driver->vehicle,
                'rating' => $driver->rating !== null ? (float) $driver->rating : null,
            ],
            'offered_at' => $this->offered_at?->toIso8601String(),
            'expires_at' => $this->expires_at?->toIso8601String(),
            'seconds_remaining' => $this->secondsRemaining(),
            'responded_at' => $this->responded_at?->toIso8601String(),
            'refusal_reason' => $this->refusal_reason,
            'created_at' => $this->created_at?->toIso8601String(),
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

        return Storage::disk('public')->url($path);
    }
}
