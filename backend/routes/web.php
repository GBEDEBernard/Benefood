<?php

use App\Http\Controllers\Admin\AdminCategoriesController;
use App\Http\Controllers\Admin\AdminController;
use App\Http\Controllers\Admin\AdminProductsController;
use App\Http\Controllers\Admin\AdminRatesController;
use App\Http\Controllers\Admin\AdminZonesController;
use App\Http\Controllers\Admin\RolesController;
use App\Http\Controllers\Admin\UsersController;
use App\Http\Controllers\Admin\VendorsController;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;

// --- Dev login (local only) ---
Route::get('/admin/dev-login', function () {
    $user = User::where('email', 'admin@local')->first();

    if (! $user) {
        abort(404, 'Admin user not found. Run AdminDashboardSeeder.');
    }

    auth()->login($user);

    return redirect()->route('admin.dashboard');
});

// --- Auth web (login / logout) ---
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

// --- Back-office (auth required) ---
Route::middleware('auth')->prefix('admin')->name('admin.')->group(function (): void {

    // Dashboard
    Route::get('', [AdminController::class, 'index'])->name('dashboard');

    // ---------- Phase 06 — Utilisateurs ----------
    Route::resource('users', UsersController::class)->only(['index', 'show']);
    Route::post('users/{user}/status', [UsersController::class, 'updateStatus'])->name('users.status');
    Route::post('users/{user}/roles', [UsersController::class, 'updateRoles'])->name('users.roles');

    // ---------- Phase 06 — Rôles & Permissions ----------
    Route::resource('roles', RolesController::class)->only(['index', 'show', 'update']);

    // ---------- Phase 07 — Vendeurs ----------
    Route::resource('vendors', VendorsController::class)->only(['index', 'show']);
    Route::post('vendors/{vendor}/approve', [VendorsController::class, 'approve'])->name('vendors.approve');
    Route::post('vendors/{vendor}/suspend', [VendorsController::class, 'suspend'])->name('vendors.suspend');
    Route::post('vendors/{vendor}/activate', [VendorsController::class, 'activate'])->name('vendors.activate');
    Route::post('vendors/{vendor}/close', [VendorsController::class, 'close'])->name('vendors.close');
    Route::get('vendors/{vendor}/documents/{document}/download', [VendorsController::class, 'downloadDocument'])->name('vendors.documents.download');
    Route::post('vendors/{vendor}/documents/{document}/review', [VendorsController::class, 'reviewDocument'])->name('vendors.documents.review');

    // ---------- Phase 08 — Catalogue (produits & catégories) ----------
    Route::resource('products', AdminProductsController::class)->except(['destroy']);
    Route::delete('products/{product}', [AdminProductsController::class, 'destroy'])->name('products.destroy');
    Route::post('products/{product}/active', [AdminProductsController::class, 'toggleActive'])->name('products.active');
    Route::post('products/{product}/availability', [AdminProductsController::class, 'setAvailability'])->name('products.availability');
    Route::post('products/{product}/images', [AdminProductsController::class, 'addImage'])->name('products.images.store');
    Route::delete('products/{product}/images/{image}', [AdminProductsController::class, 'removeImage'])->name('products.images.destroy');

    Route::resource('categories', AdminCategoriesController::class)->except(['show', 'destroy']);
    Route::delete('categories/{category}', [AdminCategoriesController::class, 'destroy'])->name('categories.destroy');
    Route::post('categories/{category}/active', [AdminCategoriesController::class, 'toggleActive'])->name('categories.active');

    // ---------- Phase 09 — Zones & tarifs de livraison ----------
    Route::resource('zones', AdminZonesController::class)->except(['show', 'destroy']);
    Route::delete('zones/{zone}', [AdminZonesController::class, 'destroy'])->name('zones.destroy');
    Route::post('zones/{zone}/active', [AdminZonesController::class, 'toggleActive'])->name('zones.active');

    Route::resource('rates', AdminRatesController::class)->except(['show', 'destroy']);
    Route::delete('rates/{rate}', [AdminRatesController::class, 'destroy'])->name('rates.destroy');
    Route::post('rates/{rate}/active', [AdminRatesController::class, 'toggleActive'])->name('rates.active');

    // ---------- Placeholders (sections pas encore développées) ----------
    Route::get('/clients', fn () => view('admin.placeholder', ['title' => 'Clients', 'section' => 'Gestion des clients']))->name('clients.index');
    Route::get('/livreurs', fn () => view('admin.placeholder', ['title' => 'Livreurs', 'section' => 'Gestion des livreurs']))->name('drivers.index');
    Route::get('/commandes', fn () => view('admin.placeholder', ['title' => 'Commandes', 'section' => 'Gestion des commandes']))->name('orders.index');
    Route::get('/boutiques', fn () => view('admin.placeholder', ['title' => 'Boutiques', 'section' => 'Gestion des boutiques']))->name('shops.index');
    Route::get('/commissions', fn () => view('admin.placeholder', ['title' => 'Commissions', 'section' => 'Gestion des commissions']))->name('commissions.index');
    Route::get('/transactions', fn () => view('admin.placeholder', ['title' => 'Transactions', 'section' => 'Gestion des transactions']))->name('payments.index');
    Route::get('/remboursements', fn () => view('admin.placeholder', ['title' => 'Remboursements', 'section' => 'Gestion des remboursements']))->name('refunds.index');
    Route::get('/reclamations', fn () => view('admin.placeholder', ['title' => 'Réclamations', 'section' => 'Gestion des réclamations et litiges']))->name('complaints.index');
    Route::get('/parametres', fn () => view('admin.placeholder', ['title' => 'Paramètres', 'section' => 'Configuration des règles métier']))->name('settings.index');
    Route::get('/audit', fn () => view('admin.placeholder', ['title' => 'Audit', 'section' => "Journal d'audit"]))->name('audit.index');
    Route::get('/rapports', fn () => view('admin.placeholder', ['title' => 'Rapports', 'section' => 'Rapports et statistiques']))->name('reports.index');
});

// Legacy / redirect / landing
Route::get('/dashboard', fn () => redirect()->route('admin.dashboard'));

Route::get('/', fn () => view('welcome'));
