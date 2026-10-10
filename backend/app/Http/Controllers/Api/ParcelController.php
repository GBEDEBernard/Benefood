<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ParcelResource;
use App\Models\DriverProfile;
use App\Models\Parcel;
use App\Services\ParcelService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Service colis — client (envoi) et livreur (course) — cahier v1.0, phase 3.
 */
class ParcelController extends Controller
{
    public function __construct(private readonly ParcelService $parcels) {}

    // ------------------------------------------------------------------- Client

    public function quote(Request $request): JsonResponse
    {
        $data = $this->validateAddresses($request);

        return Api::ok($this->parcels->quote($data['pickup'], $data['dropoff']));
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validateAddresses($request);

        $parcel = $this->parcels->create(
            $request->user(),
            $data['pickup'],
            $data['dropoff'],
            $data['description'] ?? null,
        );

        return Api::created(new ParcelResource($parcel->load('payment')));
    }

    public function index(Request $request): JsonResponse
    {
        $parcels = $request->user()->parcels()
            ->with(['driverProfile.user', 'statusHistory'])
            ->orderByDesc('created_at')
            ->paginate((int) $request->query('per_page', config('beninfood.pagination.per_page')));

        return Api::ok(ParcelResource::collection($parcels->items())->resolve(), [
            'pagination' => [
                'total' => $parcels->total(),
                'per_page' => $parcels->perPage(),
                'current_page' => $parcels->currentPage(),
                'last_page' => $parcels->lastPage(),
            ],
        ]);
    }

    public function show(Request $request, Parcel $parcel): JsonResponse
    {
        if ($parcel->user_id !== $request->user()->id && ! $this->isOwnParcelDriver($request, $parcel)) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        return Api::ok(new ParcelResource($parcel->load(['payment', 'driverProfile.user', 'statusHistory'])));
    }

    public function cancel(Request $request, Parcel $parcel): JsonResponse
    {
        if ($parcel->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $parcel = $this->parcels->cancel($parcel, 'client', $request->user()->id, $data['reason']);

        return Api::ok(new ParcelResource($parcel));
    }

    // ------------------------------------------------------------------ Livreur

    public function offers(Request $request): JsonResponse
    {
        $this->driverProfile($request);

        return Api::ok(ParcelResource::collection(
            $this->parcels->availableOffers()->load('user')
        )->resolve());
    }

    public function driverIndex(Request $request): JsonResponse
    {
        $driver = $this->driverProfile($request);

        return Api::ok(ParcelResource::collection(
            $this->parcels->driverParcels($driver)->load('user')
        )->resolve());
    }

    public function accept(Request $request, Parcel $parcel): JsonResponse
    {
        $driver = $this->driverProfile($request);

        if ($parcel->driver_profile_id !== null || $parcel->status->value !== 'paid') {
            return Api::error('Ce colis n\'est plus disponible.', 'parcel.not_available', 409);
        }

        $parcel = $this->parcels->assignDriver($parcel, $driver, $driver->user_id);

        return Api::ok(new ParcelResource($parcel));
    }

    public function pickup(Request $request, Parcel $parcel): JsonResponse
    {
        $this->assertOwned($request, $parcel);

        return Api::ok(new ParcelResource($this->parcels->markPickedUp($parcel, $this->driverProfile($request)->user_id)));
    }

    public function start(Request $request, Parcel $parcel): JsonResponse
    {
        $this->assertOwned($request, $parcel);

        return Api::ok(new ParcelResource($this->parcels->markInDelivery($parcel, $this->driverProfile($request)->user_id)));
    }

    public function deliver(Request $request, Parcel $parcel): JsonResponse
    {
        $this->assertOwned($request, $parcel);

        return Api::ok(new ParcelResource($this->parcels->markDelivered($parcel, $this->driverProfile($request)->user_id)));
    }

    // ------------------------------------------------------------------ Helpers

    /**
     * @return array{pickup: array<string, mixed>, dropoff: array<string, mixed>, description?: ?string}
     */
    private function validateAddresses(Request $request): array
    {
        return $request->validate([
            'pickup' => ['required', 'array'],
            'pickup.label' => ['sometimes', 'nullable', 'string', 'max:100'],
            'pickup.address_text' => ['sometimes', 'nullable', 'string', 'max:255'],
            'pickup.area' => ['sometimes', 'nullable', 'string', 'max:120'],
            'pickup.city' => ['sometimes', 'nullable', 'string', 'max:120'],
            'pickup.latitude' => ['sometimes', 'nullable', 'numeric', 'between:-90,90'],
            'pickup.longitude' => ['sometimes', 'nullable', 'numeric', 'between:-180,180'],
            'dropoff' => ['required', 'array'],
            'dropoff.label' => ['sometimes', 'nullable', 'string', 'max:100'],
            'dropoff.address_text' => ['sometimes', 'nullable', 'string', 'max:255'],
            'dropoff.area' => ['sometimes', 'nullable', 'string', 'max:120'],
            'dropoff.city' => ['sometimes', 'nullable', 'string', 'max:120'],
            'dropoff.latitude' => ['sometimes', 'nullable', 'numeric', 'between:-90,90'],
            'dropoff.longitude' => ['sometimes', 'nullable', 'numeric', 'between:-180,180'],
            'description' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);
    }

    private function driverProfile(Request $request): DriverProfile
    {
        $profile = $request->user()->driverProfile()->first();

        if ($profile === null) {
            abort(404, 'Aucun profil livreur associé à ce compte.');
        }

        return $profile;
    }

    private function assertOwned(Request $request, Parcel $parcel): void
    {
        if ($parcel->driver_profile_id !== $this->driverProfile($request)->id) {
            abort(404, 'Ce colis ne vous appartient pas.');
        }
    }

    private function isOwnParcelDriver(Request $request, Parcel $parcel): bool
    {
        $profile = $request->user()->driverProfile()->first();

        return $profile !== null && $parcel->driver_profile_id === $profile->id;
    }
}
