<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Models\DriverProfile;
use App\Services\DriverStatsService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DriverStatsController extends Controller
{
    public function __construct(private readonly DriverStatsService $statsService) {}

    public function index(Request $request): JsonResponse
    {
        $driver = DriverProfile::query()->where('user_id', $request->user()->id)->first();

        if ($driver === null) {
            throw new DomainException('stats.no_driver_profile', 'Profil livreur introuvable.', 404);
        }

        $data = $request->validate([
            'period' => ['nullable', 'string', 'in:7d,30d,90d,12m'],
        ]);

        return Api::ok($this->statsService->forDriver(
            $driver,
            $data['period'] ?? '30d',
        ));
    }
}
