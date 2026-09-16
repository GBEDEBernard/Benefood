<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\DeliveryResource;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Services\DeliveryService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Livraisons temps réel côté livreur (M9 — J97 à J106).
 */
class DeliveryController extends Controller
{
    public function __construct(private readonly DeliveryService $deliveryService) {}

    public function setAvailability(Request $request): JsonResponse
    {
        $this->authorize('toggleAvailability', $profile = $this->driverProfile($request));

        $data = $request->validate([
            'available' => ['required', 'boolean'],
            'latitude' => ['sometimes', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'numeric', 'between:-180,180'],
        ]);

        $location = [
            'latitude' => $data['latitude'] ?? null,
            'longitude' => $data['longitude'] ?? null,
        ];

        if ($location['latitude'] === null || $location['longitude'] === null) {
            $location = [];
        }

        $profile = $this->deliveryService->toggleAvailability($profile, (bool) $data['available'], $location);

        return Api::ok([
            'available' => (bool) $profile->available,
            'status' => $profile->status,
        ]);
    }

    public function updateLocation(Request $request): JsonResponse
    {
        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $profile = $this->deliveryService->updateLocation($this->driverProfile($request), $data);

        return Api::ok([
            'latitude' => $profile->last_latitude,
            'longitude' => $profile->last_longitude,
        ]);
    }

    public function availableOffers(Request $request): JsonResponse
    {
        $this->driverProfile($request);

        return Api::ok(DeliveryResource::collection(
            $this->deliveryService->availableOffers()
                ->map(fn (Delivery $delivery) => $delivery->load(['order.vendor', 'order.user', 'vendor', 'zone']))
        )->resolve());
    }

    public function myDeliveries(Request $request): JsonResponse
    {
        $driver = $this->driverProfile($request);

        return Api::ok(DeliveryResource::collection(
            $this->deliveryService->driverDeliveries($driver)
                ->map(fn (Delivery $delivery) => $delivery->load(['order.vendor', 'order.user', 'vendor', 'statusHistory', 'driverProfile']))
        )->resolve());
    }

    public function accept(Request $request, Delivery $delivery): JsonResponse
    {
        $delivery = $this->deliveryService->acceptOffer($delivery, $this->driverProfile($request));

        return Api::ok(new DeliveryResource($delivery));
    }

    public function decline(Request $request, Delivery $delivery): JsonResponse
    {
        $data = $request->validate([
            'reason' => ['sometimes', 'nullable', 'string', 'max:500'],
        ]);

        $delivery = $this->deliveryService->declineOffer($delivery, $this->driverProfile($request), $data['reason'] ?? null);

        return Api::ok(new DeliveryResource($delivery));
    }

    public function pickup(Request $request, Delivery $delivery): JsonResponse
    {
        $delivery = $this->deliveryService->markPickedUp($delivery, $this->driverProfile($request));

        return Api::ok(new DeliveryResource($delivery));
    }

    public function start(Request $request, Delivery $delivery): JsonResponse
    {
        $delivery = $this->deliveryService->markInDelivery($delivery, $this->driverProfile($request));

        return Api::ok(new DeliveryResource($delivery));
    }

    public function deliver(Request $request, Delivery $delivery): JsonResponse
    {
        $data = $request->validate([
            'proof_code' => ['sometimes', 'nullable', 'string', 'max:10'],
            'proof_photo' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        $delivery = $this->deliveryService->markDelivered($delivery, $this->driverProfile($request), $data);

        return Api::ok(new DeliveryResource($delivery));
    }

    public function incident(Request $request, Delivery $delivery): JsonResponse
    {
        $data = $request->validate([
            'message' => ['required', 'string', 'max:1000'],
        ]);

        $delivery = $this->deliveryService->reportIncident($delivery, $this->driverProfile($request), $data['message']);

        return Api::ok(new DeliveryResource($delivery));
    }

    private function driverProfile(Request $request): DriverProfile
    {
        $profile = $request->user()->driverProfile()->first();

        if ($profile === null) {
            abort(404, 'Aucun profil livreur associé à ce compte.');
        }

        return $profile;
    }
}
