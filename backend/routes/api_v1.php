<?php

use App\Http\Controllers\Api\HealthController;
use Illuminate\Support\Facades\Route;

Route::get('/health', [HealthController::class, 'index'])->name('api.v1.health');

Route::prefix('auth')->middleware('throttle:auth')->group(function (): void {
    // J45 : inscription / connexion
});
