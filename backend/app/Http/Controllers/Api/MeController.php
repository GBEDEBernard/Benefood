<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use App\Http\Resources\UserResource;
use App\Models\Notification;
use App\Models\PaymentMethod;
use App\Models\Product;
use App\Services\AuthService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Profil et contexte d'utilisation (J51-J52).
 */
class MeController extends Controller
{
    public function __construct(private readonly AuthService $auth) {}

    public function show(Request $request): JsonResponse
    {
        return Api::ok(new UserResource($request->user()->loadMissing('roles')));
    }

    public function roles(Request $request): JsonResponse
    {
        $roles = $request->user()->roles()
            ->orderByPivot('is_active', 'desc')
            ->orderByPivot('last_used_at', 'desc')
            ->get();

        return Api::ok($roles->map(fn ($role) => [
            'role' => [
                'slug' => $role->slug,
                'name' => $role->name,
            ],
            'is_active' => (bool) $role->pivot->is_active,
        ])->values());
    }

    public function activeRole(Request $request): JsonResponse
    {
        $data = $request->validate([
            'role_slug' => ['required', 'string', 'max:64'],
        ]);

        $active = $this->auth->switchActiveRole($request->user(), $data['role_slug']);

        return Api::ok([
            'active_role' => $active,
            'message' => "Mode « {$active} » activé.",
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'email' => ['sometimes', 'nullable', 'email', 'max:255'],
        ]);

        $user = $this->auth->updateProfile($request->user(), $data);

        return Api::ok(new UserResource($user->loadMissing('roles')));
    }

    public function devices(Request $request): JsonResponse
    {
        $devices = $request->user()->devices()->orderByDesc('last_seen_at')->get();

        return Api::ok($devices->map(function ($device) {
            return [
                'id' => $device->id,
                'platform' => $device->platform,
                'device_type' => $device->device_type,
                'app_version' => $device->app_version,
                'is_active' => $device->is_active,
                'last_seen_at' => $device->last_seen_at?->toIso8601String(),
            ];
        })->values());
    }

    public function registerDevice(Request $request): JsonResponse
    {
        $data = $request->validate([
            'fcm_token' => ['required', 'string', 'max:255'],
            'platform' => ['required', 'string', 'in:android,ios,web'],
            'device_type' => ['sometimes', 'nullable', 'string', 'max:64'],
            'app_version' => ['sometimes', 'nullable', 'string', 'max:32'],
        ]);

        $device = $this->auth->registerDevice($request->user(), $data);

        return Api::created([
            'id' => $device->id,
            'platform' => $device->platform,
            'is_active' => $device->is_active,
        ]);
    }

    // ------------------------------------------------------------------ J153
    /** Photo de profil : upload multipart `avatar`, l'ancienne est supprimée. */
    public function uploadAvatar(Request $request): JsonResponse
    {
        $request->validate([
            'avatar' => ['required', 'file', 'image', 'mimes:jpeg,png,webp', 'max:5120'],
        ]);

        $user = $request->user();
        $file = $request->file('avatar');
        $extension = strtolower($file->getClientOriginalExtension() ?: 'jpg');
        $path = $file->storeAs('avatars', $user->id.'-'.Str::random(8).'.'.$extension, 'public');

        if ($user->avatar_path !== null && $user->avatar_path !== '') {
            Storage::disk('public')->delete($user->avatar_path);
        }

        $user->update(['avatar_path' => $path]);

        return Api::ok(new UserResource($user->fresh()->loadMissing('roles')));
    }

    /** Changement de mot de passe : révocation des autres jetons. */
    public function changePassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = $request->user();

        if (! Hash::check($data['current_password'], $user->password)) {
            return Api::error('Le mot de passe actuel est incorrect.', 'validation_error', 422, [
                'current_password' => 'Le mot de passe actuel est incorrect.',
            ]);
        }

        $user->update(['password' => $data['password']]);

        $token = $user->currentAccessToken();

        if ($token instanceof PersonalAccessToken) {
            $user->tokens()->where('id', '!=', $token->id)->delete();
        }

        return Api::ok(['message' => 'Mot de passe modifié avec succès.']);
    }

    /** Compteurs du tableau de bord profil (commandes, favoris, coupons, portefeuille). */
    public function stats(Request $request): JsonResponse
    {
        $user = $request->user();

        return Api::ok([
            'orders_count' => $user->orders()->count(),
            'favorites_count' => $user->favorites()->count(),
            'coupons_count' => $user->userCoupons()
                ->whereNull('used_at')
                ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))
                ->count(),
            'wallet_balance' => (int) $user->wallet_balance,
            'unread_notifications' => $user->appNotifications()->whereNull('read_at')->count(),
        ]);
    }

    public function notifications(Request $request): JsonResponse
    {
        $notifications = $request->user()->appNotifications()
            ->latest()
            ->limit(50)
            ->get();

        return Api::ok($notifications->map(fn (Notification $notification) => [
            'id' => $notification->id,
            'type' => $notification->type,
            'title' => $notification->title,
            'body' => $notification->body,
            'data' => $notification->data,
            'order_id' => data_get($notification->data, 'order_id'),
            'screen' => data_get($notification->data, 'screen'),
            'deeplink' => data_get($notification->data, 'deeplink'),
            'image_url' => data_get($notification->data, 'image_url'),
            'read_at' => $notification->read_at?->toIso8601String(),
            'created_at' => $notification->created_at?->toIso8601String(),
        ])->values());
    }

    public function markNotificationRead(Request $request, Notification $notification): JsonResponse
    {
        if ($notification->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        if ($notification->read_at === null) {
            $notification->update(['read_at' => now()]);
        }

        return Api::ok(['id' => $notification->id, 'read_at' => $notification->fresh()->read_at?->toIso8601String()]);
    }

    public function markAllNotificationsRead(Request $request): JsonResponse
    {
        $count = $request->user()->appNotifications()
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return Api::ok(['updated' => $count]);
    }

    public function favorites(Request $request): JsonResponse
    {
        $favorites = $request->user()->favorites()
            ->with(['product.vendor', 'product.category', 'product.images'])
            ->latest()
            ->get();

        return Api::ok($favorites->map(fn ($favorite) => [
            'id' => $favorite->id,
            'product_id' => $favorite->product_id,
            'created_at' => $favorite->created_at?->toIso8601String(),
            'product' => $favorite->product !== null ? new ProductResource($favorite->product) : null,
        ])->values());
    }

    public function addFavorite(Request $request): JsonResponse
    {
        $data = $request->validate([
            'product_id' => ['required', 'uuid', 'exists:products,id'],
        ]);

        $user = $request->user();
        $favorite = $user->favorites()->firstOrCreate(['product_id' => $data['product_id']]);

        return Api::created([
            'id' => $favorite->id,
            'product_id' => $favorite->product_id,
        ]);
    }

    public function removeFavorite(Request $request, Product $product): JsonResponse
    {
        $request->user()->favorites()->where('product_id', $product->id)->delete();

        return Api::noContent();
    }

    public function paymentMethods(Request $request): JsonResponse
    {
        $methods = $request->user()->paymentMethods()->orderByDesc('is_default')->orderByDesc('updated_at')->get();

        return Api::ok($methods->map(fn (PaymentMethod $method) => [
            'id' => $method->id,
            'type' => $method->type,
            'provider' => $method->provider,
            'label' => $method->label,
            'last4' => $method->last4,
            'is_default' => $method->is_default,
            'updated_at' => $method->updated_at?->toIso8601String(),
        ])->values());
    }

    public function storePaymentMethod(Request $request): JsonResponse
    {
        $data = $this->validatedPaymentMethod($request);

        $user = $request->user();
        $isFirst = ! $user->paymentMethods()->exists();
        $isDefault = (bool) ($data['is_default'] ?? $isFirst);

        if ($isDefault) {
            $user->paymentMethods()->update(['is_default' => false]);
        }

        $method = $user->paymentMethods()->create($data + ['is_default' => $isDefault]);

        return Api::created($this->paymentMethodPayload($method));
    }

    public function updatePaymentMethod(Request $request, PaymentMethod $paymentMethod): JsonResponse
    {
        if ($paymentMethod->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $this->validatedPaymentMethod($request, updating: true);

        if (! empty($data['is_default'])) {
            $request->user()->paymentMethods()
                ->where('id', '!=', $paymentMethod->id)
                ->update(['is_default' => false]);
        }

        $paymentMethod->update($data);

        return Api::ok($this->paymentMethodPayload($paymentMethod->fresh()));
    }

    public function destroyPaymentMethod(Request $request, PaymentMethod $paymentMethod): JsonResponse
    {
        if ($paymentMethod->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $wasDefault = $paymentMethod->is_default;
        $paymentMethod->delete();

        if ($wasDefault) {
            $next = $request->user()->paymentMethods()->orderByDesc('updated_at')->first();

            if ($next !== null) {
                $next->update(['is_default' => true]);
            }
        }

        return Api::noContent();
    }

    public function coupons(Request $request): JsonResponse
    {
        $coupons = $request->user()->userCoupons()->orderByDesc('created_at')->get();

        return Api::ok($coupons->map(fn ($coupon) => [
            'id' => $coupon->id,
            'code' => $coupon->code,
            'label' => $coupon->label,
            'discount_type' => $coupon->discount_type,
            'discount_value' => (int) $coupon->discount_value,
            'min_amount' => $coupon->min_amount !== null ? (int) $coupon->min_amount : null,
            'expires_at' => $coupon->expires_at?->toIso8601String(),
            'used_at' => $coupon->used_at?->toIso8601String(),
            'is_available' => $coupon->isAvailable(),
        ])->values());
    }

    /**
     * @return array<string, mixed>
     */
    private function validatedPaymentMethod(Request $request, bool $updating = false): array
    {
        $required = $updating ? 'sometimes' : 'required';

        return $request->validate([
            'type' => [$required, 'string', 'in:card,mobile_money,cash'],
            'provider' => [$required, 'string', 'max:60'],
            'label' => [$required, 'string', 'max:100'],
            'last4' => ['sometimes', 'nullable', 'string', 'regex:/^[0-9]{4}$/'],
            'is_default' => ['sometimes', 'boolean'],
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function paymentMethodPayload(PaymentMethod $method): array
    {
        return [
            'id' => $method->id,
            'type' => $method->type,
            'provider' => $method->provider,
            'label' => $method->label,
            'last4' => $method->last4,
            'is_default' => $method->is_default,
            'updated_at' => $method->updated_at?->toIso8601String(),
        ];
    }
}
