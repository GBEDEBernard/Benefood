<?php

namespace App\Http\Controllers\Admin;

use App\Enums\ParcelStatus;
use App\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Models\Parcel;
use App\Models\User;
use App\Services\ParcelService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

/**
 * Phase 16 — Gestion des colis au back-office (cahier v1.0, phase 3).
 */
class AdminParcelsController extends Controller
{
    public function __construct(private readonly ParcelService $parcels) {}

    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = Parcel::query()->with(['user', 'driverProfile.user', 'payment']);

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($search = trim((string) $request->query('q'))) {
            $query->where(function ($q) use ($search) {
                $q->where('reference', 'like', "%{$search}%")
                    ->orWhereHas('user', fn ($u) => $u->where('name', 'like', "%{$search}%"));
            });
        }

        if ($from = $request->query('from')) {
            $query->whereDate('created_at', '>=', $from);
        }

        if ($to = $request->query('to')) {
            $query->whereDate('created_at', '<=', $to);
        }

        $parcels = $query->orderByDesc('created_at')->paginate(20)->withQueryString();

        return view('admin.parcels.index', [
            'parcels' => $parcels,
            'statuses' => ParcelStatus::cases(),
            'counts' => [
                'all' => Parcel::count(),
                'awaiting_payment' => Parcel::where('status', ParcelStatus::AwaitingPayment->value)->count(),
                'paid' => Parcel::where('status', ParcelStatus::Paid->value)->count(),
                'in_progress' => Parcel::whereIn('status', [
                    ParcelStatus::Assigned->value,
                    ParcelStatus::PickedUp->value,
                    ParcelStatus::InDelivery->value,
                ])->count(),
                'delivered' => Parcel::where('status', ParcelStatus::Delivered->value)->count(),
                'cancelled' => Parcel::where('status', ParcelStatus::Cancelled->value)->count(),
            ],
            'filters' => [
                'q' => $request->query('q'),
                'status' => $status,
                'from' => $request->query('from'),
                'to' => $request->query('to'),
            ],
        ]);
    }

    public function show(Request $request, Parcel $parcel): View
    {
        $this->authorize('manage', User::class);

        $parcel->load(['user', 'driverProfile.user', 'payment', 'statusHistory']);

        return view('admin.parcels.show', [
            'parcel' => $parcel,
        ]);
    }

    public function cancel(Request $request, Parcel $parcel): RedirectResponse
    {
        $this->authorize('manage', User::class);

        $data = $request->validate([
            'reason' => ['required', 'string', 'min:3', 'max:500'],
        ]);

        try {
            DB::transaction(fn () => $this->parcels->cancel($parcel, 'porteuse', (string) Auth::id(), $data['reason']));
        } catch (DomainException $e) {
            return back()->with('error', $e->getMessage())->withInput();
        }

        return back()->with('success', "Le colis « {$parcel->reference} » a été annulé.");
    }
}
