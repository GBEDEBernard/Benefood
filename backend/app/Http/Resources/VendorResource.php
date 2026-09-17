<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class VendorResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'business_name' => $this->business_name,
            'legal_name' => $this->legal_name,
            'ifu' => $this->ifu,
            'description' => $this->description,
            'phone' => $this->phone,
            'email' => $this->email,
            'city' => $this->city,
            'address' => $this->address,
            'logo_url' => $this->mediaUrl($this->logo_url),
            'cover_url' => $this->mediaUrl($this->cover_url),
            'status' => $this->status,
            'approved_at' => $this->approved_at?->toIso8601String(),
            'closed_at' => $this->closed_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }

    /**
     * Normalise un chemin de média en URL publique : les chemins relatifs
     * stockés par d'anciennes versions sont convertis, les URL absolues
     * sont renvoyées telles quelles.
     */
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
