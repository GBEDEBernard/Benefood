<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Http\Resources\ComplaintResource;
use App\Models\Complaint;
use App\Services\ComplaintService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Réclamations (M12 — J122) côté client et back-office.
 */
class ComplaintController extends Controller
{
    public function __construct(private readonly ComplaintService $complaints) {}

    public function index(Request $request): JsonResponse
    {
        $complaints = $request->user()->complaints()
            ->with('order')
            ->orderByDesc('created_at')
            ->paginate((int) $request->query('per_page', config('beninfood.pagination.per_page')));

        return Api::ok(ComplaintResource::collection($complaints->items())->values(), [
            'pagination' => [
                'total' => $complaints->total(),
                'per_page' => $complaints->perPage(),
                'current_page' => $complaints->currentPage(),
                'last_page' => $complaints->lastPage(),
            ],
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'order_id' => ['sometimes', 'nullable', 'uuid', 'exists:orders,id'],
            'type' => ['required', 'string', 'max:30', 'in:product,delivery,payment,other'],
            'subject' => ['required', 'string', 'max:120'],
            'description' => ['required', 'string', 'max:2000'],
        ]);

        $complaint = $this->complaints->open($request->user(), $data);

        return Api::created(new ComplaintResource($complaint));
    }

    public function show(Request $request, Complaint $complaint): JsonResponse
    {
        if (! $this->canAccess($request, $complaint)) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $complaint->load('messages');

        return Api::ok(new ComplaintResource($complaint));
    }

    public function reply(Request $request, Complaint $complaint): JsonResponse
    {
        if (! $this->canAccess($request, $complaint)) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'message' => ['required', 'string', 'max:2000'],
        ]);

        try {
            $message = $this->complaints->reply($complaint, $request->user(), $data['message']);
        } catch (DomainException $e) {
            return Api::error($e->getMessage(), $e->errorCode, $e->status);
        }

        return Api::created($message->fresh());
    }

    public function adminIndex(Request $request): JsonResponse
    {
        $complaints = Complaint::query()
            ->with('order', 'user')
            ->orderByDesc('created_at')
            ->paginate((int) $request->query('per_page', config('beninfood.pagination.per_page')));

        return Api::ok(ComplaintResource::collection($complaints->items())->values(), [
            'pagination' => [
                'total' => $complaints->total(),
                'per_page' => $complaints->perPage(),
                'current_page' => $complaints->currentPage(),
                'last_page' => $complaints->lastPage(),
            ],
        ]);
    }

    public function markInProgress(Request $request, Complaint $complaint): JsonResponse
    {
        $complaint = $this->complaints->markInProgress($complaint, $request->user());

        return Api::ok(new ComplaintResource($complaint));
    }

    public function close(Request $request, Complaint $complaint): JsonResponse
    {
        $data = $request->validate([
            'resolution' => ['sometimes', 'nullable', 'string', 'max:2000'],
        ]);

        $complaint = $this->complaints->close($complaint, $request->user(), $data['resolution'] ?? null);

        return Api::ok(new ComplaintResource($complaint));
    }

    private function canAccess(Request $request, Complaint $complaint): bool
    {
        if ($complaint->user_id === $request->user()->id) {
            return true;
        }

        return $request->user()->hasPermission('admin.support.resolve');
    }
}
