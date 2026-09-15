<?php

namespace App\Http\Controllers\Admin;

use App\Enums\VendorDocumentStatus;
use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Vendor;
use App\Models\VendorDocument;
use App\Services\VendorOnboardingService;
use Illuminate\Support\Facades\Storage;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

/**
 * Phase 07 — Gestion des vendeurs et boutiques depuis le back-office (J54-J60).
 *
 * La porteuse pilote le cycle de vie du vendeur : vérification des documents,
 * approbation, suspension (motif obligatoire), réactivation, fermeture.
 */
class VendorsController extends Controller
{
    public function __construct(private readonly VendorOnboardingService $vendorService) {}

    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = Vendor::query()->with(['user', 'settings', 'products']);

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($search = trim((string) $request->query('q'))) {
            $query->where(function ($q) use ($search) {
                $q->where('business_name', 'like', "%{$search}%")
                    ->orWhere('legal_name', 'like', "%{$search}%")
                    ->orWhere('ifu', 'like', "%{$search}%")
                    ->orWhere('city', 'like', "%{$search}%")
                    ->orWhereHas('user', fn ($u) => $u->where('name', 'like', "%{$search}%"));
            });
        }

        $vendors = $query->orderByDesc('created_at')->paginate(20)->withQueryString();

        $counts = [
            'all' => Vendor::count(),
            'pending_verification' => Vendor::where('status', VendorStatus::PendingVerification->value)->count(),
            'active' => Vendor::where('status', VendorStatus::Active->value)->count(),
            'suspended' => Vendor::where('status', VendorStatus::Suspended->value)->count(),
            'closed' => Vendor::where('status', VendorStatus::Closed->value)->count(),
        ];

        return view('admin.vendors.index', [
            'vendors' => $vendors,
            'counts' => $counts,
            'statuses' => VendorStatus::cases(),
            'filters' => [
                'q' => $request->query('q'),
                'status' => $status,
            ],
        ]);
    }

    public function show(Vendor $vendor): View
    {
        $this->authorize('manage', User::class);

        $vendor->load([
            'user',
            'documents',
            'contacts',
            'hours',
            'settings',
            'zones',
            'products',
            'statusHistory',
        ]);

        $histories = $vendor->statusHistory->sortByDesc('created_at');
        $actorIds = $histories->pluck('actor_id')->filter()->unique();
        $actors = User::whereIn('id', $actorIds)->pluck('name', 'id');

        return view('admin.vendors.show', [
            'vendor' => $vendor,
            'histories' => $histories,
            'actors' => $actors,
        ]);
    }

    public function approve(Vendor $vendor): RedirectResponse
    {
        $this->authorize('approve', Vendor::class);

        if (! in_array($vendor->status, [VendorStatus::Registered->value, VendorStatus::PendingVerification->value, VendorStatus::Verified->value, VendorStatus::Suspended->value], true)) {
            return back()->with('error', 'Ce vendeur ne peut pas être approuvé depuis son statut actuel.');
        }

        $from = VendorStatus::tryFrom($vendor->status);

        $this->vendorService->recordHistory($vendor, $from, VendorStatus::Active, actorType: 'admin', actorId: Auth::id());
        $vendor->update(['status' => VendorStatus::Active->value]);

        return back()->with('success', "Le vendeur « {$vendor->business_name} » a été approuvé et activé.");
    }

    public function suspend(Request $request, Vendor $vendor): RedirectResponse
    {
        $this->authorize('suspend', Vendor::class);

        $data = $request->validate([
            'reason' => ['required', 'string', 'min:3', 'max:500'],
        ]);

        if ($vendor->status === VendorStatus::Closed->value) {
            return back()->with('error', 'Ce vendeur est déjà fermé.');
        }

        $from = VendorStatus::tryFrom($vendor->status);

        $this->vendorService->recordHistory($vendor, $from, VendorStatus::Suspended, reason: $data['reason'], actorType: 'admin', actorId: Auth::id());
        $vendor->update(['status' => VendorStatus::Suspended->value]);

        return back()->with('success', "Le vendeur « {$vendor->business_name} » a été suspendu.");
    }

    public function activate(Vendor $vendor): RedirectResponse
    {
        $this->authorize('approve', Vendor::class);

        if ($vendor->status !== VendorStatus::Suspended->value) {
            return back()->with('error', 'Seul un vendeur suspendu peut être réactivé.');
        }

        $this->vendorService->recordHistory($vendor, VendorStatus::Suspended, VendorStatus::Active, actorType: 'admin', actorId: Auth::id());
        $vendor->update(['status' => VendorStatus::Active->value]);

        return back()->with('success', "Le vendeur « {$vendor->business_name} » est de nouveau actif.");
    }

    public function close(Request $request, Vendor $vendor): RedirectResponse
    {
        $this->authorize('suspend', Vendor::class);

        $data = $request->validate([
            'reason' => ['required', 'string', 'min:3', 'max:500'],
        ]);

        if ($vendor->status === VendorStatus::Closed->value) {
            return back()->with('error', 'Ce vendeur est déjà fermé.');
        }

        $from = VendorStatus::tryFrom($vendor->status);

        $this->vendorService->recordHistory($vendor, $from, VendorStatus::Closed, reason: $data['reason'], actorType: 'admin', actorId: Auth::id());
        $vendor->update(['status' => VendorStatus::Closed->value]);

        return back()->with('success', "Le compte vendeur « {$vendor->business_name} » a été fermé.");
    }

    public function reviewDocument(Request $request, Vendor $vendor, VendorDocument $document): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if ($document->vendor_id !== $vendor->id) {
            abort(404);
        }

        $data = $request->validate([
            'status' => ['required', 'string', 'in:'.implode(',', array_column(VendorDocumentStatus::cases(), 'value'))],
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        $document->update([
            'status' => $data['status'],
            'reason' => $data['status'] === VendorDocumentStatus::Invalid->value ? $data['reason'] : null,
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ]);

        return back()->with('success', 'Le document a été mis à jour.');
    }

    public function downloadDocument(Vendor $vendor, VendorDocument $document)
    {
        $this->authorize('manage', User::class);

        if ($document->vendor_id !== $vendor->id) {
            abort(404);
        }

        $disk = Storage::disk('private');

        if (! $disk->exists($document->file_path)) {
            abort(404, 'Fichier introuvable.');
        }

        return $disk->download($document->file_path);
    }
}