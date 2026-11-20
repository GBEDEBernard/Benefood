<?php

namespace App\Http\Resources;

use App\Services\DeliveryTrackingService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class ParcelResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $pendingAssignment = $this->relationLoaded('assignments')
            ? $this->assignments->firstWhere('status', 'pending_handover')
            : null;
        $openIncident = $this->relationLoaded('incidents')
            ? $this->incidents->firstWhere('status', 'open')
            : null;

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
            'approach_fee' => (int) $this->approach_fee,
            'approach_distance_km' => $this->approach_distance_km !== null ? (float) $this->approach_distance_km : null,
            'approach_payment_method' => $this->approach_payment_method?->value,
            'approach_payment_status' => $this->approach_payment_status?->value,
            'approach_driver_id' => $this->approach_driver_profile_id,
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
            'reassignment_count' => (int) $this->reassignment_count,
            'handover_required' => $pendingAssignment !== null,
            'handover_code' => $request->user()?->id === $this->user_id
                ? $pendingAssignment?->handover_code
                : null,
            'open_incident' => $openIncident === null ? null : [
                'id' => $openIncident->id,
                'type' => $openIncident->type,
                'message' => $openIncident->message,
                'created_at' => $openIncident->created_at?->toIso8601String(),
            ],
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
            'position' => app(DeliveryTrackingService::class)->positionForParcel($this->resource),
            'payment' => $this->whenLoaded('payment', fn () => $this->payment === null ? null : [
                'id' => $this->payment->id,
                'reference' => $this->payment->reference,
                'status' => $this->payment->status?->value,
                'amount' => (int) $this->payment->amount,
                'paid_at' => $this->payment->paid_at?->toIso8601String(),
            ]),
            'approach_payment' => $this->whenLoaded('approachPayment', fn () => $this->approachPayment === null ? null : [
                'id' => $this->approachPayment->id,
                'reference' => $this->approachPayment->reference,
                'status' => $this->approachPayment->status?->value,
                'amount' => (int) $this->approachPayment->amount,
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
