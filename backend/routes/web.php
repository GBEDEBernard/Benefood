<?php

use App\Http\Controllers\Admin\AdminAuditController;
use App\Http\Controllers\Admin\AdminCategoriesController;
use App\Http\Controllers\Admin\AdminClientsController;
use App\Http\Controllers\Admin\AdminCommissionsController;
use App\Http\Controllers\Admin\AdminComplaintsController;
use App\Http\Controllers\Admin\AdminController;
use App\Http\Controllers\Admin\AdminDriversController;
use App\Http\Controllers\Admin\AdminOrdersController;
use App\Http\Controllers\Admin\AdminPaymentsController;
use App\Http\Controllers\Admin\AdminProductsController;
use App\Http\Controllers\Admin\AdminRatesController;
use App\Http\Controllers\Admin\AdminRefundsController;
use App\Http\Controllers\Admin\AdminReportsController;
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

    // ---------- Phase 10 — Clients (CRUD back-office) ----------
    Route::resource('clients', AdminClientsController::class)->only(['index', 'show', 'edit', 'update', 'destroy']);

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

    // ---------- Phase 16 — Paiements / transactions ----------
    Route::resource('payments', AdminPaymentsController::class)->only(['index', 'show']);

    // ---------- Phase 16 — Livreurs (J136) ----------
    Route::resource('drivers', AdminDriversController::class)->only(['index', 'show', 'create', 'store']);
    Route::post('drivers/{driver}/activate', [AdminDriversController::class, 'activate'])->name('drivers.activate');
    Route::post('drivers/{driver}/suspend', [AdminDriversController::class, 'suspend'])->name('drivers.suspend');
    Route::post('drivers/{driver}/close', [AdminDriversController::class, 'close'])->name('drivers.close');
    Route::get('drivers/{driver}/documents/{document}/download', [AdminDriversController::class, 'downloadDocument'])->name('drivers.documents.download');
    Route::post('drivers/{driver}/documents/{document}/review', [AdminDriversController::class, 'reviewDocument'])->name('drivers.documents.review');

    // ---------- Phase 16 — Commandes (J137) ----------
    Route::resource('orders', AdminOrdersController::class)->only(['index', 'show']);
    Route::post('orders/{order}/cancel', [AdminOrdersController::class, 'cancel'])->name('orders.cancel');

    // ---------- Phase 16 — Commissions (J138) ----------
    Route::get('commissions', [AdminCommissionsController::class, 'index'])->name('commissions.index');
    Route::post('commissions', [AdminCommissionsController::class, 'store'])->name('commissions.store');
    Route::delete('commissions/{rate}', [AdminCommissionsController::class, 'destroy'])->name('commissions.destroy');

    // ---------- Phase 16 — Remboursements (J140) ----------
    Route::resource('refunds', AdminRefundsController::class)->only(['index', 'show']);
    Route::post('refunds/{refund}/execute', [AdminRefundsController::class, 'execute'])->name('refunds.execute');

    // ---------- Phase 16 — Réclamations & litiges (J141) ----------
    Route::resource('complaints', AdminComplaintsController::class)->only(['index', 'show']);
    Route::post('complaints/{complaint}/reply', [AdminComplaintsController::class, 'reply'])->name('complaints.reply');
    Route::post('complaints/{complaint}/mark-in-progress', [AdminComplaintsController::class, 'markInProgress'])->name('complaints.in-progress');
    Route::post('complaints/{complaint}/close', [AdminComplaintsController::class, 'close'])->name('complaints.close');

    // ---------- Phase 16 — Audit & rapports (J142) ----------
    Route::get('audit', [AdminAuditController::class, 'index'])->name('audit.index');
    Route::get('audit/export', [AdminAuditController::class, 'export'])->name('audit.export');
    Route::get('rapports', [AdminReportsController::class, 'index'])->name('reports.index');
    Route::get('rapports/export/orders', [AdminReportsController::class, 'exportOrders'])->name('reports.export.orders');
    Route::get('rapports/export/commissions', [AdminReportsController::class, 'exportCommissions'])->name('reports.export.commissions');
    Route::get('rapports/export/refunds', [AdminReportsController::class, 'exportRefunds'])->name('reports.export.refunds');

    // ---------- Boutiques (J135) : renvoie vers les vendeurs actifs ----------
    Route::get('/boutiques', fn () => redirect()->route('admin.vendors.index', ['status' => 'active']))->name('shops.index');

    // ---------- Paramètres (hors périmètre Phase 16) ----------
    Route::get('/parametres', fn () => view('admin.placeholder', ['title' => 'Paramètres', 'section' => 'Configuration des règles métier']))->name('settings.index');
});

// Legacy / redirect / landing
Route::get('/dashboard', fn () => redirect()->route('admin.dashboard'));

// Backoffice shortlink
Route::get('/backoffice', fn () => redirect()->route('admin.dashboard'))->name('backoffice');

Route::get('/', fn () => view('welcome'));
