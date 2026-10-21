<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\VendorStatsService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class VendorStatsController extends Controller
{
    public function __construct(private readonly VendorStatsService $statsService) {}

    public function index(Request $request): JsonResponse
    {
        $vendor = $request->user()->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        $this->authorize('view', $vendor);

        $data = $request->validate([
            'period' => ['nullable', 'string', 'in:7d,30d,90d,12m'],
        ]);

        return Api::ok($this->statsService->forVendor(
            $vendor,
            $data['period'] ?? '30d',
        ));
    }
}
