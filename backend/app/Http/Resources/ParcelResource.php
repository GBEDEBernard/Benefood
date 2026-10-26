<?php

namespace App\Http\Resources;

use App\Enums\ParcelStatus;
use App\Services\DeliveryPricingService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class ParcelResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'reference' => $this->reference,
            'status' => $this->status?->value,
            'payment_status' => $this->payment_status?->value,
            'payment_method' => $this->payment_method?->value,
            'description' => $this->description,
            'currency' => $this->currency,
            'pickup' => $this->pickup_snapshot,
            'dropoff' => $this->dropoff_snapshot,
            'sender' => $this->whenLoaded('user', fn () => $this->user === null ? null : [
                'id' => $this->user->id,
                'name' => $this->user->name,
                'phone' => $this->user->phone,
                'avatar_url' => $this->mediaUrl($this->user->avatar_path),
            ]),
            'distance_km' => $this->distance_km !== null ? (float) $this->distance_km : null,
            'delivery_fee' => (int) $this->delivery_fee,
            'creation_fee' => (int) $this->creation_fee,
            'total_amount' => $this->totalAmount(),
            'pricing_snapshot' => $this->pricing_snapshot,
            'commission_rate' => (int) $this->commission_rate,
            'commission_amount' => (int) $this->commission_amount,
            'partner_amount' => (int) $this->partner_amount,
            'platform_amount' => (int) $this->platform_amount,
            'confirmation_code' => $this->when(
                $request->user()?->id === $this->user_id,
                $this->confirmation_code,
            ),
            'confirmation_code_expires_at' => $this->when(
                $request->user()?->id === $this->user_id,
                $this->confirmation_code_expires_at?->toIso8601String(),
            ),
            'targeted_driver_id' => $this->targeted_driver_profile_id,
            'targeted_driver' => $this->whenLoaded('targetedDriverProfile', fn () => $this->targetedDriverProfile === null ? null : [
                'id' => $this->targetedDriverProfile->id,
                'name' => $this->targetedDriverProfile->user?->name,
            ]),
            'driver_request' => $this->whenLoaded('driverAssignmentRequest', fn () => $this->driverAssignmentRequest === null
                ? null
                : (new DriverAssignmentRequestResource($this->driverAssignmentRequest))->resolve()),
            'driver' => $this->whenLoaded('driverProfile', fn () => $this->driverProfile === null ? null : [
                'id' => $this->driverProfile->id,
                'name' => $this->driverProfile->user?->name,
                'phone' => $this->driverProfile->user?->phone,
                'avatar_url' => $this->mediaUrl($this->driverProfile->user?->avatar_path),
                'vehicle' => $this->driverProfile->vehicle,
                'rating' => $this->driverProfile->rating,
            ]),
            'position' => $this->positionPayload(),
            'payment' => $this->whenLoaded('payment', fn () => $this->payment === null ? null : [
                'id' => $this->payment->id,
                'reference' => $this->payment->reference,
                'status' => $this->payment->status?->value,
                'amount' => (int) $this->payment->amount,
            ]),
            'status_history' => $this->whenLoaded('statusHistory', fn () => $this->statusHistory->map(fn ($history) => [
                'from_status' => $history->from_status,
                'to_status' => $history->to_status,
                'actor_type' => $history->actor_type,
                'reason' => $history->reason,
                'created_at' => $history->created_at?->toIso8601String(),
            ])->values()),
            'payment_deadline_at' => $this->payment_deadline_at?->toIso8601String(),
            'assigned_at' => $this->assigned_at?->toIso8601String(),
            'picked_up_at' => $this->picked_up_at?->toIso8601String(),
            'delivered_at' => $this->delivered_at?->toIso8601String(),
            'cancelled_at' => $this->cancelled_at?->toIso8601String(),
            'cancellation_reason' => $this->cancellation_reason,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }

    /**
     * Position du livreur, uniquement pendant la course active (J178).
     *
     * @return array<string, mixed>|null
     */
    private function positionPayload(): ?array
    {
        $active = in_array($this->status, [
            ParcelStatus::Assigned,
            ParcelStatus::EnRoutePickup,
            ParcelStatus::PickedUp,
            ParcelStatus::InDelivery,
        ], true);
        $driver = $this->relationLoaded('driverProfile') ? $this->driverProfile : null;

        if (! $active || $driver === null || $driver->last_latitude === null || $driver->last_longitude === null) {
            return null;
        }

        return [
            'latitude' => round((float) $driver->last_latitude, 3),
            'longitude' => round((float) $driver->last_longitude, 3),
            'heading' => $driver->last_heading !== null ? (float) $driver->last_heading : null,
            'last_location_at' => $driver->last_location_at?->toIso8601String(),
            'age_seconds' => $driver->last_location_at !== null
                ? max(0, (int) $driver->last_location_at->diffInSeconds(now()))
                : null,
            'distance_km' => $this->distanceToDropoff($driver),
        ];
    }

    private function distanceToDropoff($driver): ?float
    {
        $dropoff = $this->dropoff_snapshot ?? [];
        $lat = $dropoff['latitude'] ?? null;
        $lng = $dropoff['longitude'] ?? null;

        if ($lat === null || $lng === null) {
            return null;
        }

        return round(app(DeliveryPricingService::class)->distanceKm(
            $driver->last_latitude,
            $driver->last_longitude,
            $lat,
            $lng,
        ), 3);
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
