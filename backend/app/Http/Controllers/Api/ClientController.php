<?php

namespace App\Http\Controllers\Api;

use App\Enums\ClientDocumentType;
use App\Http\Controllers\Controller;
use App\Models\ClientProfile;
use App\Services\ClientOnboardingService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Onboarding du compte client (J19) : coordonnées + documents.
 */
class ClientController extends Controller
{
    public function __construct(private readonly ClientOnboardingService $clientService) {}

    public function onboarding(Request $request): JsonResponse
    {
        $this->authorize('create', ClientProfile::class);

        $data = $request->validate([
            'full_name' => ['sometimes', 'nullable', 'string', 'max:255'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:20'],
            'address' => ['sometimes', 'nullable', 'string', 'max:255'],
            'city' => ['sometimes', 'nullable', 'string', 'max:120'],
        ]);

        $profile = $this->clientService->onboard($request->user(), $data);

        return Api::created([
            'id' => $profile->id,
            'status' => $profile->status,
        ]);
    }

    public function uploadDocument(Request $request): JsonResponse
    {
        $request->validate([
            'type' => ['required', 'string', 'in:'.implode(',', ClientDocumentType::values())],
            'document' => ['required', 'file', 'mimes:pdf,png,jpg,jpeg,webp', 'max:5120'],
        ]);

        $profile = $request->user()->clientProfile()->first();

        if ($profile === null) {
            return Api::error(
                'Veuillez d\'abord compléter votre inscription client.',
                'client.not_onboarded',
                409,
            );
        }

        $this->authorize('manageDocuments', $profile);

        $document = $this->clientService->submitDocument($profile, $request->file('document'), $request->input('type'));

        return Api::created([
            'id' => $document->id,
            'type' => $document->type,
            'status' => $document->status,
        ]);
    }

    public function status(Request $request): JsonResponse
    {
        $profile = $request->user()->clientProfile()->with('documents')->first();

        if ($profile === null) {
            return Api::error('Aucun profil client associé à ce compte.', 'client.not_onboarded', 404);
        }

        $this->authorize('view', $profile);

        return Api::ok($this->clientService->getStatus($profile));
    }
}
