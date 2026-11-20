<?php

namespace App\Http\Controllers\Api;

use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Parcel;
use App\Services\DeliveryTrackingService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Lecture légère du suivi d'une mission active.
 *
 * Les endpoints de détail (`GET /orders/{order}`, `GET /parcels/{parcel}`)
 * restent la source historique et exposent le même `position`. Celui-ci est le
 * endpoint de polling haute fréquence : il ne renvoie que le suivi, avec les
 * trois positions, les distances et l'ETA calculés par le service central.
 */
class DeliveryTrackingController extends Controller
{
    public function __construct(private readonly DeliveryTrackingService $tracking) {}

    public function order(Request $request, Order $order): JsonResponse
    {
        if (! $this->canAccessOrder($request, $order)) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $delivery = $order->loadMissing('delivery')->delivery;

        if ($delivery === null) {
            return Api::error('Aucune livraison associée à cette commande.', 'tracking.no_mission', 404);
        }

        return Api::ok($this->tracking->trackingForDelivery($delivery));
    }

    public function parcel(Request $request, Parcel $parcel): JsonResponse
    {
        if (! $this->canAccessParcel($request, $parcel)) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        return Api::ok($this->tracking->trackingForParcel($parcel));
    }

    private function canAccessOrder(Request $request, Order $order): bool
    {
        if ($order->user_id === $request->user()->id) {
            return true;
        }

        $driver = $request->user()->driverProfile()->first();
        if ($driver !== null && $order->delivery()->where('driver_profile_id', $driver->id)->exists()) {
            return true;
        }

        $vendor = $request->user()->vendor()->first();

        return $vendor !== null
            && $vendor->status === VendorStatus::Active->value
            && $vendor->closed_at === null
            && $vendor->id === $order->vendor_id;
    }

    private function canAccessParcel(Request $request, Parcel $parcel): bool
    {
        if ($parcel->user_id === $request->user()->id) {
            return true;
        }

        $driver = $request->user()->driverProfile()->first();

        return $driver !== null && $parcel->driver_profile_id === $driver->id;
    }
}
