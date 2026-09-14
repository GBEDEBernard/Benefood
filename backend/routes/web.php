<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Admin\AdminController;

if (app()->environment('local') || app()->environment('development')) {
    Route::get('/admin/dev-login', function () {
        $user = \App\Models\User::where('email', 'admin@local')->first();

        if (! $user) {
            abort(404, 'Admin user not found. Run AdminDashboardSeeder.');
        }

        auth()->login($user);

        return redirect()->route('admin.dashboard');
    });
}

Route::middleware('auth')->group(function () {
    Route::get('/admin', [AdminController::class, 'index'])->name('admin.dashboard');
});


Route::get('/', function () {
    return view('welcome');
});
