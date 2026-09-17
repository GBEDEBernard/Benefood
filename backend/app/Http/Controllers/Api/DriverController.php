<?php

namespace App\Http\Controllers\Api;

use App\Enums\DriverDocumentType;
use App\Http\Controllers\Controller;
use App\Models\DriverProfile;
use App\Models\User;
use App\Services\DriverOnboardingService;
use App\Support\Api;
use App\Support\Phone;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DriverController extends Controller
{
    public function __construct(private readonly DriverOnboardingService $driverService) {}

    public function onboarding(Request $request): JsonResponse
    {
        $this->authorize('create', DriverProfile::class);

        $data = $request->validate([
            'vehicle' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        $profile = $this->driverService->candidacy($request->user(), $data);

        return Api::created([
            'id' => $profile->id,
            'type' => $profile->type,
            'status' => $profile->status,
        ]);
    }

    public function uploadDocument(Request $request): JsonResponse
    {
        $request->validate([
            'type' => ['required', 'string', 'in:'.implode(',', DriverDocumentType::values())],
            'document' => ['required', 'file', 'mimes:pdf,png,jpg,jpeg,webp', 'max:5120'],
        ]);

        $user = $request->user();
        $profile = $user->driverProfile()->first();

        if ($profile === null) {
            return Api::error(
                'Veuillez d\'abord compléter votre inscription livreur.',
                'driver.not_onboarded',
                409,
            );
        }

        $this->authorize('manageDocuments', $profile);

        $document = $this->driverService->submitDocument($profile, $request->file('document'), $request->input('type'), $user);

        return Api::created([
            'id' => $document->id,
            'type' => $document->type,
            'status' => $document->status,
        ]);
    }

    public function status(Request $request): JsonResponse
    {
        $profile = $request->user()->driverProfile()->with('documents')->first();

        if ($profile === null) {
            return Api::error('Aucun profil livreur associé à ce compte.', 'driver.not_onboarded', 404);
        }

        $this->authorize('view', $profile);

        return Api::ok($this->driverService->getStatus($profile));
    }

    /**
     * POST /admin/drivers — création de compte livreur interne Béninfood (J48).
     * Réservé aux profils porteuse / admin-technique (AdminPolicy).
     */
    public function createInternal(Request $request): JsonResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'regex:/^(?:\+?229|00229|0)?0?1?[0-9]{8}$/'],
            'password' => ['sometimes', 'nullable', 'string', 'min:8'],
            'vehicle' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        $data['phone'] = Phone::normalize($data['phone']);
        $result = $this->driverService->createInternal($request->user(), $data);

        return Api::created([
            'profile' => [
                'id' => $result['profile']->id,
                'type' => $result['profile']->type,
                'status' => $result['profile']->status,
                'user_id' => $result['profile']->user_id,
            ],
            'initial_password' => $result['initial_password'],
        ]);
    }
}
