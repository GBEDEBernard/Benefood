<?php

namespace App\Http\Controllers\Admin;

use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Models\Vendor;
use App\Services\VendorOnboardingService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminVendorController extends Controller
{
    public function __construct(private readonly VendorOnboardingService $vendorService) {}

    public function approve(Request $request, Vendor $vendor): JsonResponse
    {
        $this->authorize('approve', Vendor::class);

        $this->vendorService->recordHistory($vendor, null, VendorStatus::Active, actorType: 'admin', actorId: $request->user()->id);

        $vendor->update(['status' => VendorStatus::Active->value]);

        return Api::ok(new \App\Http\Resources\VendorResource($vendor->fresh()));
    }

    public function suspend(Request $request, Vendor $vendor): JsonResponse
    {
        $this->authorize('suspend', Vendor::class);

        $this->vendorService->recordHistory($vendor, null, VendorStatus::Closed, actorType: 'admin', actorId: $request->user()->id);

        $vendor->update(['status' => VendorStatus::Closed->value]);

        return Api::ok(new \App\Http\Resources\VendorResource($vendor->fresh()));
    }
}
