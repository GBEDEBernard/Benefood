<?php

namespace App\Http\Controllers\Admin;

use App\Enums\DriverDocumentStatus;
use App\Enums\DriverStatus;
use App\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Models\DriverDocument;
use App\Models\DriverProfile;
use App\Models\User;
use App\Services\DriverOnboardingService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;

/**
 * Phase 16 — Gestion des livreurs au back-office porteuse (J136).
 *
 * Consultation, validation des documents, approbation, suspension (motif
 * obligatoire), réactivation, fermeture et création de livreur interne.
 */
class AdminDriversController extends Controller
{
    public function __construct(private readonly DriverOnboardingService $driverService) {}

    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = DriverProfile::query()->with('user');

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($request->query('available') === '1') {
            $query->where('available', true);
        }

        if ($search = trim((string) $request->query('q'))) {
            $query->where(fn ($q) => $q
                ->where('vehicle', 'like', "%{$search}%")
                ->orWhereHas('user', fn ($u) => $u
                    ->where('name', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")));
        }

        $drivers = $query->orderByDesc('created_at')->paginate(20)->withQueryString();

        return view('admin.drivers.index', [
            'drivers' => $drivers,
            'counts' => [
                'all' => DriverProfile::count(),
                'active' => DriverProfile::where('status', DriverStatus::Active->value)->count(),
                'pending' => DriverProfile::whereIn('status', [DriverStatus::Candidate->value, DriverStatus::PendingValidation->value])->count(),
                'suspended' => DriverProfile::where('status', DriverStatus::Suspended->value)->count(),
                'online' => DriverProfile::where('status', DriverStatus::Active->value)->where('available', true)->count(),
            ],
            'filters' => [
                'q' => $request->query('q'),
                'status' => $status,
                'available' => $request->query('available'),
            ],
        ]);
    }

    public function show(DriverProfile $driver): View
    {
        $this->authorize('manage', User::class);

        $driver->load([
            'user',
            'documents',
            'statusHistory',
            'availabilityLogs',
            'deliveries.order' => fn ($q) => $q->with('vendor'),
        ]);

        return view('admin.drivers.show', ['driver' => $driver]);
    }

    public function create(): View
    {
        $this->authorize('manage', User::class);

        return view('admin.drivers.form');
    }

    public function store(Request $request): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:20'],
            'password' => ['nullable', 'string', 'min:8'],
            'vehicle' => ['nullable', 'string', 'max:255'],
        ]);

        try {
            $result = $this->driverService->createInternal($request->user(), $data);
        } catch (DomainException $e) {
            return back()->with('error', $e->getMessage())->withInput();
        }

        return redirect()->route('admin.drivers.show', $result['profile'])
            ->with('success', "Livreur créé — mot de passe initial : {$result['initial_password']}");
    }

    public function activate(DriverProfile $driver): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if ($driver->status === DriverStatus::Active->value || $driver->status === DriverStatus::Closed->value) {
            return back()->with('error', 'Ce livreur ne peut pas être activé depuis son statut actuel.');
        }

        $from = DriverStatus::tryFrom($driver->status);

        $this->driverService->recordHistory($driver, $from, DriverStatus::Active, actorType: 'admin', actorId: Auth::id());
        $driver->update(['status' => DriverStatus::Active->value]);

        return back()->with('success', 'Le livreur a été activé.');
    }

    public function suspend(Request $request, DriverProfile $driver): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'reason' => ['required', 'string', 'min:3', 'max:500'],
        ]);

        if ($driver->status === DriverStatus::Closed->value) {
            return back()->with('error', 'Ce livreur est déjà fermé.');
        }

        $from = DriverStatus::tryFrom($driver->status);

        $this->driverService->recordHistory($driver, $from, DriverStatus::Suspended, reason: $data['reason'], actorType: 'admin', actorId: Auth::id());
        $driver->update(['status' => DriverStatus::Suspended->value]);

        return back()->with('success', 'Le livreur a été suspendu.');
    }

    public function close(Request $request, DriverProfile $driver): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'reason' => ['required', 'string', 'min:3', 'max:500'],
        ]);

        if ($driver->status === DriverStatus::Closed->value) {
            return back()->with('error', 'Ce livreur est déjà fermé.');
        }

        $from = DriverStatus::tryFrom($driver->status);

        $this->driverService->recordHistory($driver, $from, DriverStatus::Closed, reason: $data['reason'], actorType: 'admin', actorId: Auth::id());
        $driver->update(['status' => DriverStatus::Closed->value]);

        return back()->with('success', 'Le compte livreur a été fermé.');
    }

    public function reviewDocument(Request $request, DriverProfile $driver, DriverDocument $document): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if ($document->driver_profile_id !== $driver->id) {
            abort(404);
        }

        $data = $request->validate([
            'status' => ['required', 'string', 'in:'.implode(',', array_column(DriverDocumentStatus::cases(), 'value'))],
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        $document->update([
            'status' => $data['status'],
            'reason' => $data['status'] === DriverDocumentStatus::Invalid->value ? $data['reason'] : null,
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ]);

        return back()->with('success', 'Le document a été mis à jour.');
    }

    public function downloadDocument(DriverProfile $driver, DriverDocument $document)
    {
        $this->authorize('manage', User::class);

        if ($document->driver_profile_id !== $driver->id) {
            abort(404);
        }

        $disk = Storage::disk('private');

        if (! $disk->exists($document->file_path)) {
            abort(404, 'Fichier introuvable.');
        }

        return $disk->download($document->file_path);
    }
}
