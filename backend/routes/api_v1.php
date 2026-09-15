<?php

use App\Http\Controllers\Admin\AdminVendorController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CatalogController;
use App\Http\Controllers\Api\DeliveryQuoteController;
use App\Http\Controllers\Api\DriverController;
use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\MeController;
use App\Http\Controllers\Api\VendorController;
use App\Http\Controllers\Api\VendorProductController;
use Illuminate\Support\Facades\Route;

Route::get('/health', [HealthController::class, 'index'])->name('api.v1.health');

Route::prefix('auth')->middleware('throttle:auth')->group(function (): void {
    Route::post('/register', [AuthController::class, 'register'])->name('api.v1.auth.register');
    Route::post('/login', [AuthController::class, 'login'])->name('api.v1.auth.login');
    Route::post('/forgot-password', [AuthController::class, 'forgotPassword'])->name('api.v1.auth.forgot-password');
    Route::post('/reset-password', [AuthController::class, 'resetPassword'])->name('api.v1.auth.reset-password');
});

Route::middleware('auth:sanctum')->group(function (): void {
    Route::post('/auth/logout', [AuthController::class, 'logout'])->name('api.v1.auth.logout');
    Route::post('/auth/refresh', [AuthController::class, 'refresh'])->name('api.v1.auth.refresh');
    Route::post('/auth/send-phone-code', [AuthController::class, 'sendPhoneCode'])->name('api.v1.auth.send-phone-code')->middleware('throttle:auth');
    Route::post('/auth/verify-phone', [AuthController::class, 'verifyPhone'])->name('api.v1.auth.verify-phone')->middleware('throttle:auth');

    Route::get('/me', [MeController::class, 'show'])->name('api.v1.me.show');
    Route::get('/me/roles', [MeController::class, 'roles'])->name('api.v1.me.roles');
    Route::post('/me/active-role', [MeController::class, 'activeRole'])->name('api.v1.me.active-role');
    Route::patch('/me', [MeController::class, 'update'])->name('api.v1.me.update');
    Route::get('/me/devices', [MeController::class, 'devices'])->name('api.v1.me.devices.index');
    Route::post('/me/devices', [MeController::class, 'registerDevice'])->name('api.v1.me.devices.store');

    Route::prefix('vendors/me')->group(function (): void {
        Route::post('/onboarding', [VendorController::class, 'onboarding'])->name('api.v1.vendors.me.onboarding');
        Route::post('/documents', [VendorController::class, 'uploadDocument'])->name('api.v1.vendors.me.documents');
        Route::get('/status', [VendorController::class, 'status'])->name('api.v1.vendors.me.status');
        Route::get('/products', [VendorController::class, 'myProducts'])->name('api.v1.vendors.me.products');
        Route::post('/products', [VendorProductController::class, 'store'])->name('api.v1.vendors.me.products.store');
        Route::patch('/products/{product}', [VendorProductController::class, 'update'])->name('api.v1.vendors.me.products.update');
        Route::delete('/products/{product}', [VendorProductController::class, 'destroy'])->name('api.v1.vendors.me.products.destroy');
        Route::post('/products/{product}/images', [VendorProductController::class, 'uploadImage'])->name('api.v1.vendors.me.products.images.store');
        Route::delete('/products/{product}/images/{image}', [VendorProductController::class, 'removeImage'])->name('api.v1.vendors.me.products.images.destroy');
        Route::patch('/', [VendorController::class, 'updateProfile'])->name('api.v1.vendors.me.update');
        Route::get('/contacts', [VendorController::class, 'listContacts'])->name('api.v1.vendors.me.contacts.index');
        Route::post('/contacts', [VendorController::class, 'addContact'])->name('api.v1.vendors.me.contacts.store');
        Route::delete('/contacts/{contact}', [VendorController::class, 'removeContact'])->name('api.v1.vendors.me.contacts.destroy');
        Route::get('/zones', [VendorController::class, 'listZones'])->name('api.v1.vendors.me.zones.index');
        Route::post('/zones', [VendorController::class, 'syncZones'])->name('api.v1.vendors.me.zones.sync');
        Route::delete('/zones/{zone}', [VendorController::class, 'detachZone'])->name('api.v1.vendors.me.zones.detach');
    });

    Route::prefix('driver/me')->group(function (): void {
        Route::post('/onboarding', [DriverController::class, 'onboarding'])->name('api.v1.driver.me.onboarding');
        Route::post('/documents', [DriverController::class, 'uploadDocument'])->name('api.v1.driver.me.documents');
        Route::get('/status', [DriverController::class, 'status'])->name('api.v1.driver.me.status');
    });

    Route::prefix('admin')->group(function (): void {
        Route::post('/drivers', [DriverController::class, 'createInternal'])->name('api.v1.admin.drivers.create');
        Route::post('/vendors/{vendor}/approve', [AdminVendorController::class, 'approve'])->name('api.v1.admin.vendors.approve');
        Route::post('/vendors/{vendor}/suspend', [AdminVendorController::class, 'suspend'])->name('api.v1.admin.vendors.suspend');
    });
});

Route::get('/categories', [CatalogController::class, 'categories'])->name('api.v1.categories.index');
Route::get('/products', [CatalogController::class, 'index'])->name('api.v1.products.index');
Route::get('/products/{product}', [CatalogController::class, 'show'])->name('api.v1.products.show');
Route::get('/vendors', [VendorController::class, 'index'])->name('api.v1.vendors.index');
Route::get('/vendors/{vendor}/products', [VendorProductController::class, 'index'])->name('api.v1.vendors.products.index');

Route::post('/delivery/quote', [DeliveryQuoteController::class, 'quote'])->name('api.v1.delivery.quote');
