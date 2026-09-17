<?php

namespace App\Http\Controllers\Admin;

use App\Enums\ComplaintStatus;
use App\Http\Controllers\Controller;
use App\Models\Complaint;
use App\Models\User;
use App\Services\ComplaintService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * Phase 16 — Réclamations & litiges au back-office porteuse (J141).
 *
 * Traitement via la permission `admin.support.resolve` : prise en charge,
 * réponse aux messages et clôture avec résolution.
 */
class AdminComplaintsController extends Controller
{
    public function __construct(private readonly ComplaintService $complaints) {}

    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = Complaint::query()->with(['user', 'order']);

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($search = trim((string) $request->query('q'))) {
            $query->where(function ($q) use ($search) {
                $q->where('subject', 'like', "%{$search}%")
                    ->orWhere('type', 'like', "%{$search}%")
                    ->orWhereHas('user', fn ($u) => $u->where('name', 'like', "%{$search}%"))
                    ->orWhereHas('order', fn ($o) => $o->where('reference', 'like', "%{$search}%"));
            });
        }

        $complaints = $query->orderByDesc('created_at')->paginate(20)->withQueryString();

        return view('admin.complaints.index', [
            'complaints' => $complaints,
            'counts' => [
                'all' => Complaint::count(),
                'open' => Complaint::where('status', ComplaintStatus::Open->value)->count(),
                'in_progress' => Complaint::where('status', ComplaintStatus::InProgress->value)->count(),
                'closed' => Complaint::where('status', ComplaintStatus::Closed->value)->count(),
            ],
            'filters' => [
                'q' => $request->query('q'),
                'status' => $status,
            ],
        ]);
    }

    public function show(Request $request, Complaint $complaint): View
    {
        $this->authorize('manage', User::class);

        $complaint->load(['user', 'order', 'messages', 'closer']);

        return view('admin.complaints.show', [
            'complaint' => $complaint,
            'canResolve' => $request->user()->hasPermission('admin.support.resolve'),
        ]);
    }

    public function reply(Request $request, Complaint $complaint): RedirectResponse
    {
        $this->authorize('manage', User::class);

        if (! $request->user()->hasPermission('admin.support.resolve')) {
            abort(403, 'Vous n\'avez pas le droit de traiter les réclamations.');
        }

        $data = $request->validate([
            'message' => ['required', 'string', 'max:2000'],
        ]);

        $this->complaints->reply($complaint, $request->user(), $data['message']);

        return back()->with('success', 'Votre réponse a été transmise au client.');
    }

    public function markInProgress(Request $request, Complaint $complaint): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $this->complaints->markInProgress($complaint, $request->user());

        return back()->with('success', 'La réclamation est marquée en cours de traitement.');
    }

    public function close(Request $request, Complaint $complaint): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'resolution' => ['nullable', 'string', 'max:2000'],
        ]);

        $this->complaints->close($complaint, $request->user(), $data['resolution'] ?? null);

        return back()->with('success', 'La réclamation a été clôturée.');
    }
}
