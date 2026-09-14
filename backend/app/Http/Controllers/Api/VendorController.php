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
use App\Http\Resources\ProductResource;
use App\Models\Product;

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

    public function updateProfile(Request $request): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        if ($user->id !== $vendor->user_id || ! $user->hasPermission('vendor.profile.manage')) {
            return Api::error('Accès refusé.', 'forbidden', 403);
        }

        $data = $request->validate([
            'business_name' => ['sometimes', 'string', 'max:255'],
            'legal_name' => ['sometimes', 'nullable', 'string', 'max:255'],
            'ifu' => ['sometimes', 'nullable', 'string', 'max:30'],
            'description' => ['sometimes', 'nullable', 'string'],
            'phone' => ['sometimes', 'string', 'max:20'],
            'email' => ['sometimes', 'nullable', 'email', 'max:255'],
            'city' => ['sometimes', 'nullable', 'string', 'max:100'],
            'address' => ['sometimes', 'nullable', 'string'],
            'logo_url' => ['sometimes', 'nullable', 'string'],
            'cover_url' => ['sometimes', 'nullable', 'string'],
            'hours' => ['sometimes', 'array'],
            'hours.*.day_of_week' => ['required_with:hours', 'integer', 'between:0,6'],
            'hours.*.opens_at' => ['nullable', 'date_format:H:i'],
            'hours.*.closes_at' => ['nullable', 'date_format:H:i'],
            'hours.*.is_closed' => ['boolean'],
        ]);

        $vendor->update(array_filter($data, fn($v) => $v !== null && $v !== []));

        if (isset($data['hours']) && is_array($data['hours'])) {
            // replace existing hours with provided set
            $vendor->hours()->delete();

            foreach ($data['hours'] as $entry) {
                $vendor->hours()->create([
                    'day_of_week' => $entry['day_of_week'],
                    'opens_at' => $entry['opens_at'] ?? null,
                    'closes_at' => $entry['closes_at'] ?? null,
                    'is_closed' => $entry['is_closed'] ?? false,
                ]);
            }
        }

        return Api::ok(new VendorResource($vendor->fresh()));
    }

    public function listContacts(Request $request): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        $this->authorize('view', $vendor);

        return Api::ok($vendor->contacts()->orderByDesc('is_primary')->get()->map(fn($c) => [
            'id' => $c->id,
            'name' => $c->name,
            'role' => $c->role,
            'phone' => $c->phone,
            'email' => $c->email,
            'is_primary' => (bool)$c->is_primary,
        ])->values());
    }

    public function addContact(Request $request): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        if (! $user->hasPermission('vendor.profile.manage')) {
            return Api::error('Accès refusé.', 'forbidden', 403);
        }

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'role' => ['sometimes', 'nullable', 'string', 'max:100'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:20'],
            'email' => ['sometimes', 'nullable', 'email', 'max:255'],
            'is_primary' => ['sometimes', 'boolean'],
        ]);

        if (! empty($data['is_primary'])) {
            $vendor->contacts()->update(['is_primary' => false]);
        }

        $contact = $vendor->contacts()->create($data);

        return Api::created([
            'id' => $contact->id,
            'name' => $contact->name,
        ]);
    }

    public function removeContact(Request $request, $contactId): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        if (! $user->hasPermission('vendor.profile.manage')) {
            return Api::error('Accès refusé.', 'forbidden', 403);
        }

        $contact = $vendor->contacts()->where('id', $contactId)->first();

        if ($contact === null) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $contact->delete();

        return Api::noContent();
    }

    public function index(Request $request): JsonResponse
    {
        $vendors = Vendor::query()
            ->where('is_active', true)
            ->orderBy('business_name')
            ->get();

        return Api::ok(VendorResource::collection($vendors)->values());
    }

    public function myProducts(Request $request): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        if ($user->id !== $vendor->user_id || ! $user->hasPermission('vendor.products.manage')) {
            return Api::error('Accès refusé.', 'forbidden', 403);
        }

        $products = $vendor->products()->where('is_active', true)->orderBy('name')->get();

        return Api::ok(ProductResource::collection($products)->values());
    }
}
