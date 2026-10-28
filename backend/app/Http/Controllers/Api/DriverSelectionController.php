<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\DriverAssignmentRequestResource;
use App\Models\DriverAssignmentRequest;
use App\Models\Order;
use App\Models\Parcel;
use App\Services\DriverSelectionService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Sélection d'un livreur proche après paiement (commande ou colis).
 */
class DriverSelectionController extends Controller
{
    public function __construct(private readonly DriverSelectionService $selection) {}

    public function nearbyOrder(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'radius_km' => ['sometimes', 'numeric', 'min:0.5', 'max:100'],
        ]);

        return Api::ok($this->selection->nearbyForOrder(
            $order,
            $request->user(),
            isset($data['radius_km']) ? (float) $data['radius_km'] : null,
        ));
    }

    public function requestOrder(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'driver_profile_id' => ['required', 'uuid', 'exists:driver_profiles,id'],
        ]);

        $assignment = $this->selection->requestForOrder($order, $request->user(), $data['driver_profile_id']);

        return Api::created(new DriverAssignmentRequestResource($assignment));
    }

    public function autoOrder(Request $request, Order $order): JsonResponse
    {
        $assignment = $this->selection->autoAssignForOrder($order, $request->user());

        return Api::created(new DriverAssignmentRequestResource($assignment));
    }

    public function cancelOrder(Request $request, Order $order): JsonResponse
    {
        $assignment = $this->selection->cancelForOrder($order, $request->user());

        return $this->cancelled($assignment);
    }

    public function nearbyParcel(Request $request, Parcel $parcel): JsonResponse
    {
        $data = $request->validate([
            'radius_km' => ['sometimes', 'numeric', 'min:0.5', 'max:100'],
        ]);

        return Api::ok($this->selection->nearbyForParcel(
            $parcel,
            $request->user(),
            isset($data['radius_km']) ? (float) $data['radius_km'] : null,
        ));
    }

    public function replacementParcel(Request $request, Parcel $parcel): JsonResponse
    {
        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'radius_km' => ['sometimes', 'numeric', 'min:0.5', 'max:100'],
        ]);

        return Api::ok($this->selection->nearbyForParcelReassignment(
            $parcel,
            $request->user(),
            (float) $data['latitude'],
            (float) $data['longitude'],
            isset($data['radius_km']) ? (float) $data['radius_km'] : null,
        ));
    }

    public function requestParcel(Request $request, Parcel $parcel): JsonResponse
    {
        $data = $request->validate([
            'driver_profile_id' => ['required', 'uuid', 'exists:driver_profiles,id'],
        ]);

        $assignment = $this->selection->requestForParcel($parcel, $request->user(), $data['driver_profile_id']);

        return Api::created(new DriverAssignmentRequestResource($assignment));
    }

    public function autoParcel(Request $request, Parcel $parcel): JsonResponse
    {
        $assignment = $this->selection->autoAssignForParcel($parcel, $request->user());

        return Api::created(new DriverAssignmentRequestResource($assignment));
    }

    public function cancelParcel(Request $request, Parcel $parcel): JsonResponse
    {
        $assignment = $this->selection->cancelForParcel($parcel, $request->user());

        return $this->cancelled($assignment);
    }

    private function cancelled(?DriverAssignmentRequest $assignment): JsonResponse
    {
        if ($assignment === null) {
            return Api::error('Aucune demande de livreur en attente.', 'driver_selection.no_pending_request', 404);
        }

        return Api::ok([
            'cancelled' => true,
            'request_id' => $assignment->id,
        ]);
    }
}
