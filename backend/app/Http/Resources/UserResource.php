<?php

namespace App\Http\Resources;

use App\Support\GeoFields;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $geo = GeoFields::payload($this->resource);

        return [
            'id' => $this->id,
            'name' => $this->name,
            'phone' => $this->phone,
            'email' => $this->email,
            'status' => $this->status,
            'locale' => $this->locale,
            'avatar_url' => $this->mediaUrl($this->avatar_path),
            'wallet_balance' => (int) $this->wallet_balance,
            'email_verified_at' => $this->email_verified_at?->toIso8601String(),
            'phone_verified_at' => $this->phone_verified_at?->toIso8601String(),
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'adresse_texte' => $this->adresse_texte,
            'geo' => $geo,
            'geographic_path' => $geo['geographic_path'],
            'created_at' => $this->created_at?->toIso8601String(),
            'roles' => $this->whenLoaded('roles', fn () => $this->roles->map(fn ($role) => [
                'slug' => $role->slug,
                'name' => $role->name,
                'is_active' => (bool) $role->pivot->is_active,
            ])->values()),
            'social_accounts' => $this->whenLoaded('socialAccounts', fn () => $this->socialAccounts->map(fn ($account) => [
                'provider' => $account->provider,
                'email' => $account->provider_email,
                'linked_at' => $account->created_at?->toIso8601String(),
            ])->values()),
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
