<?php

namespace App\Http\Controllers\Api;

use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Models\Vendor;
use App\Services\DeliveryPricingService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * M5 — Devis de livraison avant validation de commande (J73).
 */
class DeliveryQuoteController extends Controller
{
    public function __construct(private readonly DeliveryPricingService $pricing) {}

    public function quote(Request $request): JsonResponse
    {
        $data = $request->validate([
            'vendor_id' => ['required', 'uuid', 'exists:vendors,id'],
            'address' => ['required', 'array'],
            'address.city' => ['nullable', 'string', 'max:255'],
            'address.area' => ['nullable', 'string', 'max:255'],
            'address.address_text' => ['nullable', 'string', 'max:255'],
            'address.latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'address.longitude' => ['nullable', 'numeric', 'between:-180,180'],
        ]);

        $vendor = Vendor::find($data['vendor_id']);

        if ($vendor === null || $vendor->status !== VendorStatus::Active->value) {
            return Api::error('Boutique introuvable.', 'vendor.not_found', 404);
        }

        $quote = $this->pricing->quoteForVendor($vendor, $data['address']);

        return Api::ok([
            'zone' => [
                'id' => $quote['zone']->id,
                'name' => $quote['zone']->name,
                'city' => $quote['zone']->city,
                'identification_mode' => $quote['zone']->identification_mode->value,
            ],
            'rate' => [
                'id' => $quote['rate']->id,
                'price' => $quote['rate']->price,
                'is_vendor_specific' => $quote['rate']->vendor_id !== null,
            ],
            'delivery_fee' => $quote['delivery_fee'],
            'currency' => 'XOF',
        ]);
    }
}
