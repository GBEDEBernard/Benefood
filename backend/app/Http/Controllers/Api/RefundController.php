<?php

namespace App\Http\Controllers\Api;

use App\Enums\RefundStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\RefundResource;
use App\Models\Refund;
use App\Services\RefundService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Remboursements (J120/J121) — gestion par la porteuse.
 */
class RefundController extends Controller
{
    public function __construct(private readonly RefundService $refunds) {}

    public function index(Request $request): JsonResponse
    {
        $refunds = Refund::query()
            ->with('order', 'payment')
            ->orderByDesc('created_at')
            ->paginate((int) $request->query('per_page', config('beninfood.pagination.per_page')));

        return Api::ok(RefundResource::collection($refunds->items())->values(), [
            'pagination' => [
                'total' => $refunds->total(),
                'per_page' => $refunds->perPage(),
                'current_page' => $refunds->currentPage(),
                'last_page' => $refunds->lastPage(),
            ],
        ]);
    }

    public function show(Refund $refund): JsonResponse
    {
        return Api::ok(new RefundResource($refund->load('order')));
    }

    public function execute(Request $request, Refund $refund): JsonResponse
    {
        if ($refund->status !== RefundStatus::Pending) {
            return Api::error('Ce remboursement n\'est pas en attente.', 'refund.not_pending', 409);
        }

        $refund = $this->refunds->executeRefund($refund, $request->user()->id);

        return Api::ok(new RefundResource($refund->load('order')));
    }
}
