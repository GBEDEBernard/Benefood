<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\DriverSummaryResource;
use App\Http\Resources\FavoriteDriverResource;
use App\Models\DriverProfile;
use App\Models\FavoriteDriver;
use App\Services\FavoriteDriverService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Livreurs favoris d'un client/vendeur et demandes reçues par un livreur.
 */
class FavoriteDriverController extends Controller
{
    public function __construct(private readonly FavoriteDriverService $favorites) {}

    // ---------------------------------------------------------- Client / vendeur

    public function index(Request $request): JsonResponse
    {
        return Api::ok(FavoriteDriverResource::collection(
            $this->favorites->listFor($request->user())
        )->resolve());
    }

    public function candidates(Request $request): JsonResponse
    {
        return Api::ok(DriverSummaryResource::collection(
            $this->favorites->candidatesFor($request->user())
        )->resolve());
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'driver_profile_id' => ['required', 'uuid', 'exists:driver_profiles,id'],
        ]);

        $driver = DriverProfile::findOrFail($data['driver_profile_id']);

        $favorite = $this->favorites->request($request->user(), $driver);

        return Api::created(new FavoriteDriverResource($favorite));
    }

    public function destroy(Request $request, DriverProfile $driver): JsonResponse
    {
        $this->favorites->remove($request->user(), $driver);

        return Api::noContent();
    }

    // ------------------------------------------------------------------ Livreur

    public function driverIndex(Request $request): JsonResponse
    {
        $driver = $this->driverProfile($request);

        return Api::ok(FavoriteDriverResource::collection(
            $this->favorites->listForDriver($driver)
        )->resolve());
    }

    public function accept(Request $request, FavoriteDriver $favorite): JsonResponse
    {
        $favorite = $this->favorites->accept($favorite, $this->driverProfile($request));

        return Api::ok(new FavoriteDriverResource($favorite));
    }

    public function decline(Request $request, FavoriteDriver $favorite): JsonResponse
    {
        $favorite = $this->favorites->decline($favorite, $this->driverProfile($request));

        return Api::ok(new FavoriteDriverResource($favorite));
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
