<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\AddressResource;
use App\Models\Address;
use App\Support\Api;
use App\Support\GeoFields;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Adresses de livraison client (M5 — J81).
 */
class AddressController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $addresses = $request->user()->addresses()->orderByDesc('is_default')->orderByDesc('updated_at')->get();

        return Api::ok(AddressResource::collection($addresses)->values());
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);

        $user = $request->user();
        $isFirst = ! $user->addresses()->exists();
        $isDefault = (bool) ($data['is_default'] ?? $isFirst);
        $data['is_default'] = $isDefault;

        if ($isDefault) {
            $user->addresses()->update(['is_default' => false]);
        }

        $address = $user->addresses()->create($data);

        return Api::created(new AddressResource($address));
    }

    public function update(Request $request, Address $address): JsonResponse
    {
        if ($address->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $this->validated($request, $address);

        if (! empty($data['is_default'])) {
            $request->user()->addresses()
                ->where('id', '!=', $address->id)
                ->update(['is_default' => false]);
        }

        $address->update($data);

        return Api::ok(new AddressResource($address->fresh()));
    }

    public function destroy(Request $request, Address $address): JsonResponse
    {
        if ($address->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $address->delete();

        return Api::noContent();
    }

    /**
     * @return array<string, mixed>
     */
    private function validated(Request $request, ?Address $address = null): array
    {
        $validated = $request->validate(array_merge([
            'label' => ['sometimes', 'nullable', 'string', 'max:100'],
            'zone_id' => ['sometimes', 'nullable', 'uuid', 'exists:delivery_zones,id'],
            'full_address' => ['required', 'string', 'max:500'],
            'landmark' => ['sometimes', 'nullable', 'string', 'max:255'],
            'contact_phone' => ['sometimes', 'nullable', 'string', 'max:20'],
            'city' => ['sometimes', 'nullable', 'string', 'max:100'],
            'area' => ['sometimes', 'nullable', 'string', 'max:100'],
            'latitude' => ['sometimes', 'nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'nullable', 'numeric', 'between:-180,180'],
            'is_default' => ['sometimes', 'boolean'],
        ], GeoFields::rules()));

        $legacy = array_intersect_key($validated, array_flip([
            'label', 'zone_id', 'full_address', 'landmark', 'contact_phone',
            'city', 'area', 'latitude', 'longitude', 'is_default',
        ]));

        $geo = GeoFields::resolve($validated, ['current' => $address]);
        unset($geo['location_recorded_at']);

        return array_merge($legacy, $geo);
    }
}
