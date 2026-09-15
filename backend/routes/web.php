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

Route::middleware('auth')->prefix('admin')->name('admin.')->group(function () {
    Route::get('', [AdminController::class, 'index'])->name('dashboard');

    // --- Vendeurs ---
    Route::get('/vendeurs', fn () => view('admin.placeholder', ['title' => 'Vendeurs', 'section' => 'Gestion des vendeurs']))->name('vendors.index');

    // --- Clients ---
    Route::get('/clients', fn () => view('admin.placeholder', ['title' => 'Clients', 'section' => 'Gestion des clients']))->name('clients.index');

    // --- Livreurs ---
    Route::get('/livreurs', fn () => view('admin.placeholder', ['title' => 'Livreurs', 'section' => 'Gestion des livreurs']))->name('drivers.index');

    // --- Commandes ---
    Route::get('/commandes', fn () => view('admin.placeholder', ['title' => 'Commandes', 'section' => 'Gestion des commandes']))->name('orders.index');

    // --- Boutiques ---
    Route::get('/boutiques', fn () => view('admin.placeholder', ['title' => 'Boutiques', 'section' => 'Gestion des boutiques']))->name('shops.index');

    // --- Produits ---
    Route::get('/produits', fn () => view('admin.placeholder', ['title' => 'Produits', 'section' => 'Gestion des produits']))->name('products.index');

    // --- Commissions ---
    Route::get('/commissions', fn () => view('admin.placeholder', ['title' => 'Commissions', 'section' => 'Gestion des commissions']))->name('commissions.index');

    // --- Livraison ---
    Route::get('/zones', fn () => view('admin.placeholder', ['title' => 'Zones', 'section' => 'Gestion des zones de livraison']))->name('zones.index');
    Route::get('/tarifs', fn () => view('admin.placeholder', ['title' => 'Tarifs', 'section' => 'Gestion des tarifs de livraison']))->name('rates.index');

    // --- Paiements ---
    Route::get('/transactions', fn () => view('admin.placeholder', ['title' => 'Transactions', 'section' => 'Gestion des transactions']))->name('payments.index');
    Route::get('/remboursements', fn () => view('admin.placeholder', ['title' => 'Remboursements', 'section' => 'Gestion des remboursements']))->name('refunds.index');

    // --- Réclamations ---
    Route::get('/reclamations', fn () => view('admin.placeholder', ['title' => 'Réclamations', 'section' => 'Gestion des réclamations et litiges']))->name('complaints.index');

    // --- Paramètres ---
    Route::get('/parametres', fn () => view('admin.placeholder', ['title' => 'Paramètres', 'section' => 'Configuration des règles métier']))->name('settings.index');

    // --- Audit & Rapports ---
    Route::get('/audit', fn () => view('admin.placeholder', ['title' => 'Audit', 'section' => "Journal d'audit"]))->name('audit.index');
    Route::get('/rapports', fn () => view('admin.placeholder', ['title' => 'Rapports', 'section' => 'Rapports et statistiques']))->name('reports.index');
});

// legacy/alias route: keep /dashboard working
Route::get('/dashboard', function () {
    return redirect()->route('admin.dashboard');
});


Route::get('/', function () {
    return view('welcome');
});
