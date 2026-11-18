<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Vendor;
use App\Support\Api;
use App\Support\Geo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CheckoutController extends Controller
{
    public function calculateDelivery(Request $request): JsonResponse
    {
        $data = $request->validate([
            'vendor_id' => ['required', 'uuid', 'exists:vendors,id'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'client_latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'client_longitude' => ['nullable', 'numeric', 'between:-180,180'],
        ]);

        $clientLat = $data['latitude'] ?? $data['client_latitude'] ?? null;
        $clientLng = $data['longitude'] ?? $data['client_longitude'] ?? null;

        if ($clientLat === null || $clientLng === null) {
            return Api::error(
                'Les coordonnées du client sont requises pour calculer la livraison.',
                'checkout.coordinates_required',
                400,
            );
        }

        $vendor = Vendor::find($data['vendor_id']);

        if ($vendor === null) {
            return Api::error('Boutique introuvable.', 'vendor.not_found', 404);
        }

        if ($vendor->latitude === null || $vendor->longitude === null) {
            return Api::error(
                'La boutique n\'a pas de position GPS définie.',
                'vendor.coordinates_missing',
                400,
            );
        }

        $distanceKm = Geo::haversineKm(
            $vendor->latitude,
            $vendor->longitude,
            (float) $clientLat,
            (float) $clientLng,
        );

        if ($distanceKm === null) {
            return Api::error(
                'Impossible de calculer la distance de livraison.',
                'checkout.distance_unavailable',
                400,
            );
        }

        $deliveryFee = (int) round(200 + ($distanceKm * 150));

        return Api::ok([
            'vendor_id' => $vendor->id,
            'distance_km' => round($distanceKm, 2),
            'delivery_fee' => $deliveryFee,
            'currency' => 'XOF',
            'formula' => '200 + distance_km * 150',
        ]);
    }
}
