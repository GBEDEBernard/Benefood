<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class HealthController extends Controller
{
    public function index(): JsonResponse
    {
        $db = $this->checkDatabase();
        $cache = $this->checkCache();

        Log::channel('beninfood')->info(
            '[health] requête reçue',
            ['db' => $db, 'cache' => $cache],
        );

        return Api::ok([
            'status' => 'ok',
            'service' => 'beninfood-api',
            'version' => config('beninfood.version'),
            'env' => config('app.env'),
            'db' => $db,
            'cache' => $cache,
            'queue' => config('queue.default'),
            'time' => now()->toIso8601String(),
        ]);
    }

    private function checkDatabase(): bool
    {
        try {
            DB::select('select 1');

            return true;
        } catch (\Throwable) {
            return false;
        }
    }

    private function checkCache(): bool
    {
        try {
            Cache::put('health.check', true, 10);

            return Cache::get('health.check') === true;
        } catch (\Throwable) {
            return false;
        }
    }
}
