<?php

use App\Http\Controllers\Api\HealthController;
use App\Http\Middleware\AddRequestId;
use App\Http\Middleware\ForceJsonResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful;

// Diagnostic temporaire de déploiement : à retirer une fois le 500 corrigé.
Route::get('/__diag', function (): JsonResponse {
    /** @var array<string, mixed> $checks */
    $checks = [
        'env' => config('app.env'),
        'debug' => config('app.debug'),
        'app_key_set' => config('app.key') !== null,
        'config_cached' => file_exists(base_path('bootstrap/cache/config.php')),
        'vite_manifest' => file_exists(public_path('build/manifest.json')),
    ];

    $caPath = '/etc/secrets/ca.pem';
    $checks['ca_exists'] = file_exists($caPath);
    $checks['ca_readable'] = is_readable($caPath);

    try {
        /** @var array<string, mixed>|false $cert */
        $cert = openssl_x509_parse((string) file_get_contents($caPath));
        $checks['ca_valid'] = $cert === false
            ? 'parse failed: '.openssl_error_string()
            : ($cert['subject']['CN'] ?? 'parsed');
    } catch (Throwable $e) {
        $checks['ca_valid'] = $e::class.' : '.$e->getMessage();
    }

    $checks['db'] = 'ok';
    try {
        DB::select('select 1');
    } catch (Throwable $e) {
        $checks['db'] = $e::class.' : '.$e->getMessage().' @ '.$e->getFile().':'.$e->getLine();
    }

    foreach (['migrations', 'cache', 'cache_locks', 'sessions', 'jobs'] as $table) {
        try {
            $checks['table_'.$table] = DB::table($table)->count();
        } catch (Throwable $e) {
            $checks['table_'.$table] = $e::class.' : '.$e->getMessage();
        }
    }

    try {
        Cache::put('__diag', true, 10);
        $checks['cache'] = Cache::get('__diag') === true;
    } catch (Throwable $e) {
        $checks['cache'] = $e::class.' : '.$e->getMessage();
    }

    try {
        app('session')->start();
        $checks['session'] = 'ok';
    } catch (Throwable $e) {
        $checks['session'] = $e::class.' : '.$e->getMessage();
    }

    try {
        app(HealthController::class)->index();
        $checks['health_controller'] = 'ok';
    } catch (Throwable $e) {
        $checks['health_controller'] = $e::class.' : '.$e->getMessage().' @ '.$e->getFile().':'.$e->getLine();
    }

    return response()->json($checks);
})->withoutMiddleware([
    AddRequestId::class,
    ForceJsonResponse::class,
    EnsureFrontendRequestsAreStateful::class,
    'throttle:api',
]);

Route::prefix('v1')->group(function (): void {
    require __DIR__.'/api_v1.php';
});
