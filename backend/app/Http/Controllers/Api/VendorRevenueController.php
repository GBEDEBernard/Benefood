<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\VendorRevenueService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Revenus, commissions et reversements du vendeur (J21 §8).
 */
class VendorRevenueController extends Controller
{
    public function __construct(private readonly VendorRevenueService $revenueService) {}

    public function index(Request $request): JsonResponse
    {
        $vendor = $request->user()->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        $this->authorize('view', $vendor);

        $data = $request->validate([
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date', 'after_or_equal:from'],
        ]);

        return Api::ok($this->revenueService->forVendor(
            $vendor,
            $data['from'] ?? null,
            $data['to'] ?? null,
        ));
    }
}
