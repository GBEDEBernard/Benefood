<?php

use App\Http\Controllers\Admin\AdminVendorController;
use App\Http\Controllers\Api\AddressController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CartController;
use App\Http\Controllers\Api\CatalogController;
use App\Http\Controllers\Api\ComplaintController;
use App\Http\Controllers\Api\DeliveryController;
use App\Http\Controllers\Api\DeliveryQuoteController;
use App\Http\Controllers\Api\DeliveryZoneController;
use App\Http\Controllers\Api\DriverController;
use App\Http\Controllers\Api\DriverFloatController;
use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\HomeController;
use App\Http\Controllers\Api\MeController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\ParcelController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\RefundController;
use App\Http\Controllers\Api\ReviewController;
use App\Http\Controllers\Api\VendorController;
use App\Http\Controllers\Api\VendorProductController;
use App\Http\Controllers\Api\VendorRevenueController;
use App\Http\Controllers\Api\VendorReviewController;
use App\Http\Controllers\Api\WalletController;
use Illuminate\Support\Facades\Route;

Route::get('/health', [HealthController::class, 'index'])->name('api.v1.health');

Route::get('/home', [HomeController::class, 'index'])->name('api.v1.home');

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
    Route::post('/me/avatar', [MeController::class, 'uploadAvatar'])->name('api.v1.me.avatar.store');
    Route::post('/me/password', [MeController::class, 'changePassword'])->name('api.v1.me.password.update');
    Route::get('/me/stats', [MeController::class, 'stats'])->name('api.v1.me.stats');
    Route::get('/me/notifications', [MeController::class, 'notifications'])->name('api.v1.me.notifications.index');
    Route::post('/me/notifications/read-all', [MeController::class, 'markAllNotificationsRead'])->name('api.v1.me.notifications.read-all');
    Route::post('/me/notifications/{notification}/read', [MeController::class, 'markNotificationRead'])->name('api.v1.me.notifications.read');
    Route::get('/me/favorites', [MeController::class, 'favorites'])->name('api.v1.me.favorites.index');
    Route::post('/me/favorites', [MeController::class, 'addFavorite'])->name('api.v1.me.favorites.store');
    Route::delete('/me/favorites/{product}', [MeController::class, 'removeFavorite'])->name('api.v1.me.favorites.destroy');
    Route::get('/me/payment-methods', [MeController::class, 'paymentMethods'])->name('api.v1.me.payment-methods.index');
    Route::post('/me/payment-methods', [MeController::class, 'storePaymentMethod'])->name('api.v1.me.payment-methods.store');
    Route::patch('/me/payment-methods/{paymentMethod}', [MeController::class, 'updatePaymentMethod'])->name('api.v1.me.payment-methods.update');
    Route::delete('/me/payment-methods/{paymentMethod}', [MeController::class, 'destroyPaymentMethod'])->name('api.v1.me.payment-methods.destroy');
    Route::get('/me/coupons', [MeController::class, 'coupons'])->name('api.v1.me.coupons.index');

    Route::prefix('vendors/me')->group(function (): void {
        Route::post('/onboarding', [VendorController::class, 'onboarding'])->name('api.v1.vendors.me.onboarding');
        Route::post('/documents', [VendorController::class, 'uploadDocument'])->name('api.v1.vendors.me.documents');
        Route::get('/documents', [VendorController::class, 'documents'])->name('api.v1.vendors.me.documents.index');
        Route::get('/status', [VendorController::class, 'status'])->name('api.v1.vendors.me.status');
        Route::get('/activity', [VendorController::class, 'activity'])->name('api.v1.vendors.me.activity');
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
        Route::get('/settings', [VendorController::class, 'settings'])->name('api.v1.vendors.me.settings.index');
        Route::patch('/settings', [VendorController::class, 'updateSettings'])->name('api.v1.vendors.me.settings.update');
        Route::post('/orders/{order}/incident', [VendorController::class, 'reportIncident'])->name('api.v1.vendors.me.orders.incident');
    });

    Route::prefix('vendors/me/reviews')->group(function (): void {
        Route::get('/', [VendorReviewController::class, 'index'])->name('api.v1.vendors.me.reviews.index');
        Route::post('/{review}/reply', [VendorReviewController::class, 'reply'])->name('api.v1.vendors.me.reviews.reply');
    });

    Route::get('vendors/me/revenues', [VendorRevenueController::class, 'index'])->name('api.v1.vendors.me.revenues.index');

    // ---------- Wallets & retraits (cahier v1.0) ----------
    Route::get('vendors/me/wallet', [WalletController::class, 'vendorWallet'])->name('api.v1.vendors.me.wallet');
    Route::get('vendors/me/wallet/payouts', [WalletController::class, 'vendorPayouts'])->name('api.v1.vendors.me.wallet.payouts');
    Route::post('vendors/me/wallet/payouts', [WalletController::class, 'requestVendorPayout'])->name('api.v1.vendors.me.wallet.payouts.store');

    Route::prefix('driver/me')->group(function (): void {
        Route::post('/onboarding', [DriverController::class, 'onboarding'])->name('api.v1.driver.me.onboarding');
        Route::post('/documents', [DriverController::class, 'uploadDocument'])->name('api.v1.driver.me.documents');
        Route::get('/status', [DriverController::class, 'status'])->name('api.v1.driver.me.status');

        // ---------- Wallet & retraits livreur (cahier v1.0) ----------
        Route::get('/wallet', [WalletController::class, 'driverWallet'])->name('api.v1.driver.me.wallet');
        Route::post('/wallet/payouts', [WalletController::class, 'requestDriverPayout'])->name('api.v1.driver.me.wallet.payouts.store');

        // ---------- Flottant cash (cahier v1.0) ----------
        Route::prefix('float')->middleware('permission:driver.finance.earnings')->group(function (): void {
            Route::get('/', [DriverFloatController::class, 'show'])->name('api.v1.driver.me.float');
            Route::post('/topup', [DriverFloatController::class, 'topUp'])->name('api.v1.driver.me.float.topup');
        });

        Route::prefix('availability')->middleware('permission:driver.availability.manage')->group(function (): void {
            Route::post('/', [DeliveryController::class, 'setAvailability'])->name('api.v1.driver.me.availability');
            Route::patch('/location', [DeliveryController::class, 'updateLocation'])->name('api.v1.driver.me.location');
        });

        Route::prefix('deliveries')->middleware('permission:driver.deliveries.manage')->group(function (): void {
            Route::get('/', [DeliveryController::class, 'myDeliveries'])->name('api.v1.driver.me.deliveries.index');
            Route::get('/offers', [DeliveryController::class, 'availableOffers'])->name('api.v1.driver.me.deliveries.offers');
            Route::post('/{delivery}/accept', [DeliveryController::class, 'accept'])->name('api.v1.driver.me.deliveries.accept');
            Route::post('/{delivery}/decline', [DeliveryController::class, 'decline'])->name('api.v1.driver.me.deliveries.decline');
            Route::post('/{delivery}/pickup', [DeliveryController::class, 'pickup'])->name('api.v1.driver.me.deliveries.pickup');
            Route::post('/{delivery}/start', [DeliveryController::class, 'start'])->name('api.v1.driver.me.deliveries.start');
            Route::post('/{delivery}/deliver', [DeliveryController::class, 'deliver'])->name('api.v1.driver.me.deliveries.deliver');
            Route::post('/{delivery}/incident', [DeliveryController::class, 'incident'])->name('api.v1.driver.me.deliveries.incident');
        });

        Route::prefix('parcels')->middleware('permission:driver.parcels.manage')->group(function (): void {
            Route::get('/', [ParcelController::class, 'driverIndex'])->name('api.v1.driver.me.parcels.index');
            Route::get('/offers', [ParcelController::class, 'offers'])->name('api.v1.driver.me.parcels.offers');
            Route::post('/{parcel}/accept', [ParcelController::class, 'accept'])->name('api.v1.driver.me.parcels.accept');
            Route::post('/{parcel}/pickup', [ParcelController::class, 'pickup'])->name('api.v1.driver.me.parcels.pickup');
            Route::post('/{parcel}/start', [ParcelController::class, 'start'])->name('api.v1.driver.me.parcels.start');
            Route::post('/{parcel}/deliver', [ParcelController::class, 'deliver'])->name('api.v1.driver.me.parcels.deliver');
        });
    });

    Route::prefix('addresses')->middleware('permission:client.cart.manage')->group(function (): void {
        Route::get('/', [AddressController::class, 'index'])->name('api.v1.addresses.index');
        Route::post('/', [AddressController::class, 'store'])->name('api.v1.addresses.store');
        Route::patch('/{address}', [AddressController::class, 'update'])->name('api.v1.addresses.update');
        Route::delete('/{address}', [AddressController::class, 'destroy'])->name('api.v1.addresses.destroy');
    });

    Route::prefix('cart')->middleware('permission:client.cart.manage')->group(function (): void {
        Route::get('/', [CartController::class, 'show'])->name('api.v1.cart.show');
        Route::delete('/', [CartController::class, 'clear'])->name('api.v1.cart.clear');
        Route::post('/items', [CartController::class, 'addItem'])->name('api.v1.cart.items.store');
        Route::patch('/items/{item}', [CartController::class, 'updateItem'])->name('api.v1.cart.items.update');
        Route::delete('/items/{item}', [CartController::class, 'destroyItem'])->name('api.v1.cart.items.destroy');
    });

    Route::prefix('orders')->group(function (): void {
        Route::post('/summary', [OrderController::class, 'summary'])->name('api.v1.orders.summary')->middleware('permission:client.orders.manage');
        Route::post('/', [OrderController::class, 'store'])->name('api.v1.orders.store')->middleware('permission:client.orders.manage');
        Route::get('/', [OrderController::class, 'index'])->name('api.v1.orders.index')->middleware('permission:client.orders.manage');
        Route::get('/{order}', [OrderController::class, 'show'])->name('api.v1.orders.show')->middleware('permission:client.orders.manage');
        Route::post('/{order}/cancel', [OrderController::class, 'cancel'])->name('api.v1.orders.cancel')->middleware('permission:client.orders.manage');
        Route::post('/{order}/confirm-delivery', [OrderController::class, 'confirmDelivery'])->name('api.v1.orders.confirm-delivery')->middleware('permission:client.orders.manage');
        Route::post('/{order}/dispute', [OrderController::class, 'dispute'])->name('api.v1.orders.dispute')->middleware('permission:client.orders.manage');
    });

    // Dépôt d'avis client (vendeur + livreur) après livraison.
    Route::post('orders/{order}/review', [ReviewController::class, 'store'])->name('api.v1.orders.review')->middleware('permission:client.orders.manage');

    // Service colis (cahier v1.0, phase 3).
    Route::prefix('parcels')->group(function (): void {
        Route::post('/quote', [ParcelController::class, 'quote'])->name('api.v1.parcels.quote')->middleware('permission:client.parcels.manage');
        Route::post('/', [ParcelController::class, 'store'])->name('api.v1.parcels.store')->middleware('permission:client.parcels.manage');
        Route::get('/', [ParcelController::class, 'index'])->name('api.v1.parcels.index')->middleware('permission:client.parcels.manage');
        Route::get('/{parcel}', [ParcelController::class, 'show'])->name('api.v1.parcels.show')->middleware('permission:client.parcels.manage');
        Route::post('/{parcel}/cancel', [ParcelController::class, 'cancel'])->name('api.v1.parcels.cancel')->middleware('permission:client.parcels.manage');
    });

    Route::prefix('complaints')->middleware('permission:client.complaints.manage')->group(function (): void {
        Route::get('/', [ComplaintController::class, 'index'])->name('api.v1.complaints.index');
        Route::post('/', [ComplaintController::class, 'store'])->name('api.v1.complaints.store');
        Route::get('/{complaint}', [ComplaintController::class, 'show'])->name('api.v1.complaints.show');
        Route::post('/{complaint}/messages', [ComplaintController::class, 'reply'])->name('api.v1.complaints.reply');
    });

    Route::prefix('vendors/me/orders')->middleware('permission:vendor.orders.manage')->group(function (): void {
        Route::get('/', [OrderController::class, 'vendorIndex'])->name('api.v1.vendors.orders.index');
        Route::get('/{order}', [OrderController::class, 'show'])->name('api.v1.vendors.orders.show');
        Route::post('/{order}/accept', [OrderController::class, 'accept'])->name('api.v1.vendors.orders.accept')->middleware('permission:vendor.orders.accept');
        Route::post('/{order}/refuse', [OrderController::class, 'refuse'])->name('api.v1.vendors.orders.refuse')->middleware('permission:vendor.orders.accept');
        Route::post('/{order}/cancel', [OrderController::class, 'vendorCancel'])->name('api.v1.vendors.orders.cancel')->middleware('permission:vendor.orders.accept');
        Route::post('/{order}/preparing', [OrderController::class, 'markPreparing'])->name('api.v1.vendors.orders.preparing')->middleware('permission:vendor.orders.accept');
        Route::post('/{order}/ready', [OrderController::class, 'markReady'])->name('api.v1.vendors.orders.ready')->middleware('permission:vendor.orders.accept');
    });

    Route::prefix('admin')->group(function (): void {
        Route::post('/drivers', [DriverController::class, 'createInternal'])->name('api.v1.admin.drivers.create');
        Route::post('/vendors/{vendor}/approve', [AdminVendorController::class, 'approve'])->name('api.v1.admin.vendors.approve');
        Route::post('/vendors/{vendor}/suspend', [AdminVendorController::class, 'suspend'])->name('api.v1.admin.vendors.suspend');
        Route::post('/orders/{order}/cancel', [OrderController::class, 'adminCancel'])->name('api.v1.admin.orders.cancel')->middleware('permission:admin.orders.cancel');
        Route::post('/orders/{order}/dispute/resolve', [OrderController::class, 'adminResolveDispute'])->name('api.v1.admin.orders.dispute.resolve')->middleware('permission:admin.support.resolve');

        Route::prefix('complaints')->middleware('permission:admin.support.resolve')->group(function (): void {
            Route::get('/', [ComplaintController::class, 'adminIndex'])->name('api.v1.admin.complaints.index');
            Route::get('/{complaint}', [ComplaintController::class, 'show'])->name('api.v1.admin.complaints.show');
            Route::post('/{complaint}/reply', [ComplaintController::class, 'reply'])->name('api.v1.admin.complaints.reply');
            Route::post('/{complaint}/mark-in-progress', [ComplaintController::class, 'markInProgress'])->name('api.v1.admin.complaints.mark-in-progress');
            Route::post('/{complaint}/close', [ComplaintController::class, 'close'])->name('api.v1.admin.complaints.close');
        });

        Route::prefix('refunds')->middleware('permission:payments.refund')->group(function (): void {
            Route::get('/', [RefundController::class, 'index'])->name('api.v1.admin.refunds.index');
            Route::get('/{refund}', [RefundController::class, 'show'])->name('api.v1.admin.refunds.show');
            Route::post('/{refund}/execute', [RefundController::class, 'execute'])->name('api.v1.admin.refunds.execute');
        });
    });

    // Payments (client)
    Route::prefix('payments')->group(function (): void {
        Route::post('/create', [PaymentController::class, 'create'])->name('api.v1.payments.create')->middleware('permission:client.orders.manage');
        Route::post('/verify', [PaymentController::class, 'verify'])->name('api.v1.payments.verify')->middleware('permission:client.orders.manage');
        Route::post('/orders/{order}/retry', [PaymentController::class, 'retry'])->name('api.v1.payments.retry')->middleware('permission:client.orders.manage');
    });
});

// Document vendeur : consultation via URL temporaire signée (disque privé).
Route::get('/vendors/me/documents/{document}/download', [VendorController::class, 'downloadDocument'])
    ->middleware('signed')
    ->name('api.v1.vendors.me.documents.download');

Route::get('/categories', [CatalogController::class, 'categories'])->name('api.v1.categories.index');
Route::get('/products', [CatalogController::class, 'index'])->name('api.v1.products.index');
Route::get('/products/{product}', [CatalogController::class, 'show'])->name('api.v1.products.show');
Route::get('/vendors', [VendorController::class, 'index'])->name('api.v1.vendors.index');
Route::get('/delivery/zones', [DeliveryZoneController::class, 'index'])->name('api.v1.delivery.zones.index');
Route::get('/vendors/{vendor}', [VendorController::class, 'show'])->name('api.v1.vendors.show');
Route::get('/vendors/{vendor}/products', [VendorProductController::class, 'index'])->name('api.v1.vendors.products.index');

Route::post('/delivery/quote', [DeliveryQuoteController::class, 'quote'])->name('api.v1.delivery.quote');

// Public webhook for payment providers
Route::post('/payments/webhook', [PaymentController::class, 'webhook'])->name('api.v1.payments.webhook');
Route::get('/payments/callback', [PaymentController::class, 'callback'])->name('api.v1.payments.callback');
