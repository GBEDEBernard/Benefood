<?php

namespace App\Http\Controllers\Api;

use App\Enums\VendorDocumentType;
use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\ComplaintResource;
use App\Http\Resources\ProductResource;
use App\Http\Resources\VendorResource;
use App\Models\Order;
use App\Models\Vendor;
use App\Models\VendorDocument;
use App\Services\ComplaintService;
use App\Services\VendorActivityService;
use App\Services\VendorOnboardingService;
use App\Support\Api;
use App\Support\Phone;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class VendorController extends Controller
{
    public function __construct(
        private readonly VendorOnboardingService $vendorService,
        private readonly VendorActivityService $activityService,
        private readonly ComplaintService $complaints,
    ) {}

    public function onboarding(Request $request): JsonResponse
    {
        $this->authorize('create', Vendor::class);

        $data = $request->validate([
            'business_name' => ['required', 'string', 'max:255'],
            'legal_name' => ['sometimes', 'nullable', 'string', 'max:255'],
            'ifu' => ['sometimes', 'nullable', 'string', 'max:30'],
            'description' => ['sometimes', 'nullable', 'string'],
            'phone' => ['required', 'string', 'regex:/^(?:\+?229|00229|0)?0?1?[0-9]{8}$/'],
            'email' => ['sometimes', 'nullable', 'email', 'max:255'],
            'city' => ['sometimes', 'nullable', 'string', 'max:100'],
            'address' => ['sometimes', 'nullable', 'string'],
            'category_id' => ['sometimes', 'nullable', 'uuid', 'exists:categories,id'],
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

    /**
     * Liste des documents du dossier vendeur (J21 §4.2/4.3) avec métadonnées
     * de vérification et URL signée de consultation.
     */
    public function documents(Request $request): JsonResponse
    {
        $vendor = $request->user()->vendor()->with('documents')->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        $this->authorize('view', $vendor);

        return Api::ok(
            $vendor->documents
                ->sortBy('created_at')
                ->map(fn (VendorDocument $document) => $this->vendorService->documentPayload($document))
                ->values(),
        );
    }

    /**
     * Téléchargement/consultation d'un document via URL temporaire signée.
     * Le fichier reste sur le disque privé, jamais exposé publiquement.
     */
    public function downloadDocument(VendorDocument $document)
    {
        if (! Storage::disk('private')->exists($document->file_path)) {
            return Api::error('Document introuvable.', 'not_found', 404);
        }

        return Storage::disk('private')->response($document->file_path);
    }

    /**
     * Historique des activités du vendeur (J21 §10).
     */
    public function activity(Request $request): JsonResponse
    {
        $vendor = $request->user()->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        $this->authorize('view', $vendor);

        $limit = (int) $request->query('limit', 100);
        $limit = min(max($limit, 1), 200);

        return Api::ok($this->activityService->forVendor($vendor, $limit));
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
            'phone' => ['sometimes', 'string', 'regex:/^(?:\+?229|00229|0)?0?1?[0-9]{8}$/'],
            'email' => ['sometimes', 'nullable', 'email', 'max:255'],
            'city' => ['sometimes', 'nullable', 'string', 'max:100'],
            'address' => ['sometimes', 'nullable', 'string'],
            'category_id' => ['sometimes', 'nullable', 'uuid', 'exists:categories,id'],
            'logo_url' => ['sometimes', 'nullable', 'string'],
            'cover_url' => ['sometimes', 'nullable', 'string'],
            'logo' => ['sometimes', 'file', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'cover' => ['sometimes', 'file', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'closed_at' => ['sometimes', 'nullable', 'date'],
            'closed_reason' => ['sometimes', 'nullable', 'string', 'max:255'],
            'hours' => ['sometimes', 'array'],
            'hours.*.day_of_week' => ['required_with:hours', 'integer', 'between:0,6'],
            'hours.*.opens_at' => ['nullable', 'date_format:H:i'],
            'hours.*.closes_at' => ['nullable', 'date_format:H:i'],
            'hours.*.is_closed' => ['boolean'],
        ]);

        // Handle image uploads
        if ($request->hasFile('logo')) {
            $path = $request->file('logo')->storeAs("vendor-media/{$vendor->id}", 'logo_'.uniqid().'.'.$request->file('logo')->getClientOriginalExtension(), 'public');
            $data['logo_url'] = Storage::disk('public')->url($path);
        }

        if ($request->hasFile('cover')) {
            $path = $request->file('cover')->storeAs("vendor-media/{$vendor->id}", 'cover_'.uniqid().'.'.$request->file('cover')->getClientOriginalExtension(), 'public');
            $data['cover_url'] = Storage::disk('public')->url($path);
        }

        unset($data['logo'], $data['cover']);

        if (isset($data['phone'])) {
            $data['phone'] = Phone::normalize($data['phone']);
        }

        // `closed_at` peut être null (réouverture) : traité hors de
        // array_filter qui écarte les valeurs nulles ci-dessous.
        $closedAtProvided = array_key_exists('closed_at', $data);
        $closedAt = $data['closed_at'] ?? null;
        $closedReasonProvided = array_key_exists('closed_reason', $data);
        $closedReason = $data['closed_reason'] ?? null;
        unset($data['closed_at'], $data['closed_reason']);

        $vendor->update(array_filter($data, fn ($v) => $v !== null && $v !== []));

        if ($closedAtProvided) {
            // Réouverture : le motif de fermeture n'a plus lieu d'être.
            $vendor->update([
                'closed_at' => $closedAt,
                'closed_reason' => $closedAt === null ? null : ($closedReasonProvided ? $closedReason : $vendor->closed_reason),
            ]);
        } elseif ($closedReasonProvided && $vendor->closed_at !== null) {
            $vendor->update(['closed_reason' => $closedReason]);
        }

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

        return Api::ok($vendor->contacts()->orderByDesc('is_primary')->get()->map(fn ($c) => [
            'id' => $c->id,
            'name' => $c->name,
            'role' => $c->role,
            'phone' => $c->phone,
            'email' => $c->email,
            'is_primary' => (bool) $c->is_primary,
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

    public function listZones(Request $request): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->with('zones')->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        $this->authorize('view', $vendor);

        return Api::ok($vendor->zones()->orderBy('name')->get()->map(fn ($z) => [
            'id' => $z->id,
            'name' => $z->name,
            'city' => $z->city,
        ])->values());
    }

    public function syncZones(Request $request): JsonResponse
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
            'zone_ids' => ['required', 'array'],
            'zone_ids.*' => ['uuid'],
        ]);

        $vendor->zones()->sync(array_values($data['zone_ids']));

        return Api::ok($vendor->zones()->orderBy('name')->get()->map(fn ($z) => [
            'id' => $z->id,
            'name' => $z->name,
            'city' => $z->city,
        ])->values());
    }

    public function detachZone(Request $request, $zoneId): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        if (! $user->hasPermission('vendor.profile.manage')) {
            return Api::error('Accès refusé.', 'forbidden', 403);
        }

        $vendor->zones()->detach($zoneId);

        return Api::noContent();
    }

    /**
     * Préférences de la boutique : reversement, notifications, langue (J21 §3.6).
     */
    public function settings(Request $request): JsonResponse
    {
        $vendor = $this->vendorForSettings($request);

        if ($vendor instanceof JsonResponse) {
            return $vendor;
        }

        return Api::ok($this->settingsPayload($vendor));
    }

    /**
     * Met à jour les préférences de la boutique.
     */
    public function updateSettings(Request $request): JsonResponse
    {
        $vendor = $this->vendorForSettings($request);

        if ($vendor instanceof JsonResponse) {
            return $vendor;
        }

        $data = $request->validate([
            'auto_accept' => ['sometimes', 'boolean'],
            'payout_method' => ['sometimes', 'nullable', 'string', 'in:bank,mobile_money,cash'],
            'payout_details' => ['sometimes', 'nullable', 'string', 'max:191'],
            'notify_new_orders' => ['sometimes', 'boolean'],
            'notify_cancellations' => ['sometimes', 'boolean'],
            'notify_payments' => ['sometimes', 'boolean'],
            'locale' => ['sometimes', 'string', 'in:fr,en'],
        ]);

        $settings = $vendor->settings()->firstOrCreate([]);
        $settings->update($data);

        return Api::ok($this->settingsPayload($vendor->fresh('settings')));
    }

    /**
     * Le vendeur signale un problème sur une de ses commandes (J21 §3.4).
     */
    public function reportIncident(Request $request, Order $order): JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        if ($order->vendor_id !== $vendor->id) {
            return Api::error('Commande introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'subject' => ['required', 'string', 'max:120'],
            'description' => ['required', 'string', 'max:2000'],
            'type' => ['sometimes', 'string', 'in:product,delivery,payment,other'],
        ]);

        $complaint = $this->complaints->openForVendor($user, $order, $data);

        return Api::created(new ComplaintResource($complaint));
    }

    private function vendorForSettings(Request $request): Vendor|JsonResponse
    {
        $user = $request->user();
        $vendor = $user->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        if ($user->id !== $vendor->user_id || ! $user->hasPermission('vendor.profile.manage')) {
            return Api::error('Accès refusé.', 'forbidden', 403);
        }

        return $vendor;
    }

    /**
     * @return array<string, mixed>
     */
    private function settingsPayload(Vendor $vendor): array
    {
        $settings = $vendor->settings()->firstOrCreate([]);
        $settings->refresh();

        return [
            'auto_accept' => (bool) $settings->auto_accept,
            'payout_method' => $settings->payout_method,
            'payout_details' => $settings->payout_details,
            'notify_new_orders' => (bool) $settings->notify_new_orders,
            'notify_cancellations' => (bool) $settings->notify_cancellations,
            'notify_payments' => (bool) $settings->notify_payments,
            'locale' => $settings->locale ?? 'fr',
        ];
    }

    public function index(Request $request): JsonResponse
    {
        $query = Vendor::query()
            ->with(['settings'])
            ->where('status', VendorStatus::Active->value)
            ->whereNull('closed_at');

        $q = trim((string) $request->query('q'));
        if ($q !== '') {
            $query->where(function ($builder) use ($q) {
                $builder->where('business_name', 'like', "%{$q}%")
                    ->orWhere('description', 'like', "%{$q}%")
                    ->orWhere('city', 'like', "%{$q}%");
            });
        }

        if ($request->filled('city')) {
            $query->where('city', $request->query('city'));
        }

        if ($request->filled('category_id')) {
            $query->whereHas('products', fn ($products) => $products->orderable()->where('category_id', $request->query('category_id')));
        }

        $perPage = (int) $request->query('per_page', config('beninfood.pagination.per_page'));
        $perPage = $perPage > 0 && $perPage <= config('beninfood.pagination.max_per_page') ? $perPage : config('beninfood.pagination.per_page');

        $paginator = $query->orderBy('business_name')->paginate($perPage);

        return Api::ok(VendorResource::collection($paginator->items())->values(), [
            'pagination' => [
                'total' => $paginator->total(),
                'per_page' => $paginator->perPage(),
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
            ],
        ]);
    }

    public function show(Request $request, Vendor $vendor): JsonResponse
    {
        if ($vendor->status !== VendorStatus::Active->value || $vendor->closed_at !== null) {
            return Api::error('Boutique introuvable.', 'not_found', 404);
        }

        $vendor->load([
            'settings',
            'hours',
            'products' => fn ($products) => $products->orderable()->orderBy('name'),
        ]);

        return Api::ok($this->shopPayload($vendor));
    }

    /**
     * Fiche boutique (J78) : informations, horaires et produits commandables.
     *
     * @return array<string, mixed>
     */
    private function shopPayload(Vendor $vendor): array
    {
        return [
            'id' => $vendor->id,
            'business_name' => $vendor->business_name,
            'description' => $vendor->description,
            'logo_url' => $this->mediaUrl($vendor->logo_url),
            'cover_url' => $this->mediaUrl($vendor->cover_url),
            'phone' => $vendor->phone,
            'city' => $vendor->city,
            'address' => $vendor->address,
            'latitude' => $vendor->latitude,
            'longitude' => $vendor->longitude,
            'is_open' => $vendor->isOpenNow(),
            'delivery_fee_share' => $vendor->settings?->delivery_fee_share,
            'max_preparation_minutes' => $vendor->settings?->max_preparation_minutes ?? 30,
            'hours' => $vendor->hours->map(fn ($hour) => [
                'day_of_week' => $hour->day_of_week,
                'opens_at' => $hour->opens_at,
                'closes_at' => $hour->closes_at,
                'is_closed' => (bool) $hour->is_closed,
            ])->values(),
            'products' => ProductResource::collection($vendor->products)->resolve(),
        ];
    }

    /**
     * Normalise un chemin de média en URL publique (chemins relatifs legacy
     * compris, URL absolues renvoyées telles quelles).
     */
    private function mediaUrl(?string $path): ?string
    {
        if ($path === null || $path === '') {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        return Storage::disk('public')->url($path);
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

        $products = $vendor->products()
            ->where('is_active', true)
            ->orderBy('name')
            ->withAvg('reviews as reviews_avg_rating', 'rating')
            ->withCount(['reviews', 'favorites'])
            ->get();

        return Api::ok(ProductResource::collection($products)->values());
    }
}
