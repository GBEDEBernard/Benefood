<?php

namespace App\Http\Controllers\Api;

use App\Enums\VendorDocumentType;
use App\Http\Controllers\Controller;
use App\Http\Resources\VendorResource;
use App\Models\Vendor;
use App\Services\VendorOnboardingService;
use App\Support\Api;
use App\Support\Phone;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class VendorController extends Controller
{
    public function __construct(private readonly VendorOnboardingService $vendorService) {}

    public function onboarding(Request $request): JsonResponse
    {
        $this->authorize('create', Vendor::class);

        $data = $request->validate([
            'business_name' => ['required', 'string', 'max:255'],
            'legal_name' => ['sometimes', 'nullable', 'string', 'max:255'],
            'ifu' => ['sometimes', 'nullable', 'string', 'max:30'],
            'description' => ['sometimes', 'nullable', 'string'],
            'phone' => ['required', 'string', 'regex:/^(?:\+?229|00229|0)?[0-9]{8}$/'],
            'email' => ['sometimes', 'nullable', 'email', 'max:255'],
            'city' => ['sometimes', 'nullable', 'string', 'max:100'],
            'address' => ['sometimes', 'nullable', 'string'],
        ]);

        $data['phone'] = Phone::normalize($data['phone']);
        $vendor = $this->vendorService->onboard($request->user(), $data);

        return Api::created(new VendorResource($vendor));
    }

    public function uploadDocument(Request $request): JsonResponse
    {
        $request->validate([
            'type' => ['required', 'string', 'in:'.implode(',', VendorDocumentType::values())],
            'document' => ['required', 'file', 'mimes:pdf,png,jpg,jpeg,webp', 'max:5120'],
        ]);

        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null) {
            return Api::error(
                'Veuillez d\'abord compléter votre inscription vendeur.',
                'vendor.not_onboarded',
                409,
            );
        }

        $this->authorize('manageDocuments', $vendor);

        $document = $this->vendorService->submitDocument($vendor, $request->file('document'), $request->input('type'), $user);

        return Api::created([
            'id' => $document->id,
            'type' => $document->type,
            'status' => $document->status,
        ]);
    }

    public function status(Request $request): JsonResponse
    {
        $vendor = $request->user()->vendor()->with('documents')->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        $this->authorize('view', $vendor);

        return Api::ok($this->vendorService->getStatus($vendor));
    }
}
