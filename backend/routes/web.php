<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Http\Controllers\Admin\AdminController;

Route::get('/admin/dev-login', function () {
    $user = \App\Models\User::where('email', 'admin@local')->first();

    if (! $user) {
        abort(404, 'Admin user not found. Run AdminDashboardSeeder.');
    }

    auth()->login($user);

    return redirect()->route('admin.dashboard');
});

// Simple web login/logout routes for dashboard
Route::get('/login', function () {
    return view('auth.login');
})->name('login');

Route::post('/login', function (Request $request) {
    $credentials = $request->only('email', 'password');

    if (Auth::attempt($credentials, $request->filled('remember'))) {
        $request->session()->regenerate();
        return redirect()->intended(route('admin.dashboard'));
    }

    return back()->withErrors(['email' => 'Les identifiants sont invalides.'])->withInput();
})->name('login.post');

Route::post('/logout', function (Request $request) {
    Auth::logout();
    $request->session()->invalidate();
    $request->session()->regenerateToken();
    return redirect()->route('login');
})->name('logout');

Route::middleware('auth')->group(function () {
    Route::get('/admin', [AdminController::class, 'index'])->name('admin.dashboard');
});

// legacy/alias route: keep /dashboard working
Route::get('/dashboard', function () {
    return redirect()->route('admin.dashboard');
});


Route::get('/', function () {
    return view('welcome');
});
