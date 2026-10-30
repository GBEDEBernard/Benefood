<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Address;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Services\CartService;
use App\Services\DeliveryService;
use App\Services\DriverSelectionService;
use App\Services\OrderService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Commandes client et vendeur (M5 — J82 à J85).
 */
class OrderController extends Controller
{
    public function __construct(
        private readonly OrderService $orders,
        private readonly CartService $cartService,
        private readonly DriverSelectionService $driverSelection,
        private readonly DeliveryService $deliveries,
    ) {}

    public function summary(Request $request): JsonResponse
    {
        $data = $request->validate([
            'address_id' => ['required', 'uuid', 'exists:addresses,id'],
            'payment_method' => ['sometimes', 'string', 'in:online,cash'],
            'driver_profile_id' => ['sometimes', 'nullable', 'uuid', 'exists:driver_profiles,id'],
        ]);

        $address = $this->userAddress($request, $data['address_id']);
        $cart = $this->userOpenCart($request);

        if ($address === null) {
            return Api::error('Adresse introuvable.', 'not_found', 404);
        }

        if ($cart === null) {
            return Api::error('Votre panier est vide.', 'order.empty_cart', 422);
        }

        return Api::ok($this->orders->summary($cart, [
            'address' => $address,
            'payment_method' => $data['payment_method'] ?? 'online',
            'driver_profile_id' => $data['driver_profile_id'] ?? null,
        ]));
    }

    public function checkoutDrivers(Request $request): JsonResponse
    {
        $data = $request->validate([
            'address_id' => ['required', 'uuid', 'exists:addresses,id'],
            'radius_km' => ['sometimes', 'numeric', 'min:0.5', 'max:100'],
        ]);

        $address = $this->userAddress($request, $data['address_id']);
        $cart = $this->userOpenCart($request);

        if ($address === null) {
            return Api::error('Adresse introuvable.', 'not_found', 404);
        }

        if ($cart === null) {
            return Api::error('Votre panier est vide.', 'order.empty_cart', 422);
        }

        return Api::ok($this->driverSelection->nearbyForCheckout(
            $cart,
            $request->user(),
            $address->toHierarchy(),
            isset($data['radius_km']) ? (float) $data['radius_km'] : null,
        ));
    }

    public function replacementDrivers(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'radius_km' => ['sometimes', 'numeric', 'min:0.5', 'max:100'],
        ]);

        return Api::ok($this->driverSelection->nearbyForReassignment(
            $order,
            $request->user(),
            (float) $data['latitude'],
            (float) $data['longitude'],
            isset($data['radius_km']) ? (float) $data['radius_km'] : null,
        ));
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'address_id' => ['required', 'uuid', 'exists:addresses,id'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'payment_method' => ['sometimes', 'string', 'in:online,cash'],
            'favorite_driver_id' => ['sometimes', 'nullable', 'uuid', 'exists:driver_profiles,id'],
            'driver_profile_id' => ['sometimes', 'nullable', 'uuid', 'exists:driver_profiles,id'],
        ]);

        $address = $this->userAddress($request, $data['address_id']);
        $cart = $this->userOpenCart($request);

        if ($address === null) {
            return Api::error('Adresse introuvable.', 'not_found', 404);
        }

        if ($cart === null) {
            return Api::error('Votre panier est vide.', 'order.empty_cart', 422);
        }

        $order = $this->orders->createFromCart(
            $cart,
            $address,
            $data['notes'] ?? null,
            $data['payment_method'] ?? 'online',
            $data['driver_profile_id'] ?? $data['favorite_driver_id'] ?? null,
            array_key_exists('driver_profile_id', $data),
        );

        return Api::created(new OrderResource($order));
    }

    public function index(Request $request): JsonResponse
    {
        $orders = $request->user()->orders()
            ->with(['vendor', 'items.product.images', 'payment'])
            ->orderByDesc('created_at')
            ->paginate((int) $request->query('per_page', config('beninfood.pagination.per_page')));

        return Api::ok(OrderResource::collection($orders->items())->values(), [
            'pagination' => [
                'total' => $orders->total(),
                'per_page' => $orders->perPage(),
                'current_page' => $orders->currentPage(),
                'last_page' => $orders->lastPage(),
            ],
        ]);
    }

    public function show(Request $request, Order $order): JsonResponse
    {
        if (! $this->canAccess($request, $order)) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $this->driverSelection->expireStale($order);

        $order->load([
            'vendor',
            'items.product.images',
            'payment',
            'approachPayment',
            'financials',
            'statusHistory',
            'refunds',
            'review',
            'delivery.driverProfile.user',
            'delivery.incidents',
            'driverAssignmentRequest.driverProfile.user',
        ]);

        return Api::ok(new OrderResource($order));
    }

    public function vendorIndex(Request $request): JsonResponse
    {
        $vendor = $request->user()->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        $orders = $vendor->orders()
            ->with(['user', 'items.product.images', 'payment'])
            ->orderByDesc('created_at')
            ->paginate((int) $request->query('per_page', config('beninfood.pagination.per_page')));

        return Api::ok(OrderResource::collection($orders->items())->values(), [
            'pagination' => [
                'total' => $orders->total(),
                'per_page' => $orders->perPage(),
                'current_page' => $orders->currentPage(),
                'last_page' => $orders->lastPage(),
            ],
        ]);
    }

    public function accept(Request $request, Order $order): JsonResponse
    {
        if (! $this->isOwnVendorOrder($request, $order) || ! in_array($order->status, [OrderStatus::AwaitingPayment, OrderStatus::Paid])) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $order = $this->orders->acceptVendorOrder($order, $request->user()->id);

        return Api::ok(new OrderResource($order->load(['statusHistory'])));
    }

    public function refuse(Request $request, Order $order): JsonResponse
    {
        if (! $this->isOwnVendorOrder($request, $order) || ! in_array($order->status, [OrderStatus::AwaitingPayment, OrderStatus::Paid])) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $order = $this->orders->refuseVendorOrder($order, $request->user()->id, $data['reason']);

        return Api::ok(new OrderResource($order->load(['statusHistory', 'refunds'])));
    }

    public function cancel(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id || in_array($order->status, [OrderStatus::Cancelled, OrderStatus::Delivered, OrderStatus::Refunded])) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $order = $this->orders->cancelClientOrder($order, $request->user()->id, $data['reason']);

        return Api::ok(new OrderResource($order->load(['statusHistory', 'payment', 'refunds'])));
    }

    public function reportIncident(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'reason' => ['required', 'string', 'max:1000'],
            'type' => ['sometimes', 'string', 'max:40'],
        ]);

        $incident = $this->deliveries->reportClientIncident(
            $order,
            $request->user(),
            $data['reason'],
            $data['type'] ?? 'client',
        );

        return Api::created([
            'id' => $incident->id,
            'type' => $incident->type,
            'message' => $incident->message,
            'status' => $incident->status,
            'created_at' => $incident->created_at?->toIso8601String(),
        ]);
    }

    public function reassign(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'driver_profile_id' => ['required', 'uuid', 'exists:driver_profiles,id'],
            'reason' => ['required', 'string', 'max:500'],
            'latitude' => ['sometimes', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'numeric', 'between:-180,180'],
        ]);

        $driver = DriverProfile::findOrFail($data['driver_profile_id']);

        $result = $this->deliveries->reassignOrder(
            $order,
            $request->user(),
            $driver,
            $data['reason'],
            isset($data['latitude']) ? (float) $data['latitude'] : null,
            isset($data['longitude']) ? (float) $data['longitude'] : null,
        );

        return Api::ok([
            'handover_code' => $result['handover_code'],
            'assignment' => [
                'id' => $result['assignment']->id,
                'sequence' => $result['assignment']->sequence,
                'status' => $result['assignment']->status,
                'base_fee' => $result['assignment']->base_fee,
                'approach_fee' => $result['assignment']->approach_fee,
                'partner_amount' => $result['assignment']->partner_amount,
                'base_partner_amount' => $result['assignment']->base_partner_amount,
                'approach_partner_amount' => $result['assignment']->approach_partner_amount,
            ],
            'reassignment' => [
                'id' => $result['reassignment']->id,
                'status' => $result['reassignment']->status,
                'old_driver_profile_id' => $result['reassignment']->old_driver_profile_id,
                'new_driver_profile_id' => $result['reassignment']->new_driver_profile_id,
                'reason' => $result['reassignment']->reason,
                'handover_code' => $result['reassignment']->handover_code,
            ],
        ]);
    }

    public function vendorCancel(Request $request, Order $order): JsonResponse
    {
        if (! $this->isOwnVendorOrder($request, $order) || in_array($order->status, [OrderStatus::Cancelled, OrderStatus::Delivered, OrderStatus::Refunded])) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $order = $this->orders->cancelVendorOrder($order, $request->user()->id, $data['reason']);

        return Api::ok(new OrderResource($order->load(['statusHistory', 'payment', 'refunds'])));
    }

    public function markPreparing(Request $request, Order $order): JsonResponse
    {
        if (! $this->isOwnVendorOrder($request, $order) || $order->status !== OrderStatus::Accepted) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $order = $this->orders->markPreparing($order, $request->user()->id);

        return Api::ok(new OrderResource($order->load(['statusHistory'])));
    }

    public function markReady(Request $request, Order $order): JsonResponse
    {
        if (! $this->isOwnVendorOrder($request, $order) || $order->status !== OrderStatus::Preparing) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'favorite_driver_id' => ['sometimes', 'nullable', 'uuid', 'exists:driver_profiles,id'],
            'driver_profile_id' => ['sometimes', 'nullable', 'uuid', 'exists:driver_profiles,id'],
        ]);

        $order = $this->orders->markReady(
            $order,
            $request->user()->id,
            $data['favorite_driver_id'] ?? null,
            $request->has('favorite_driver_id'),
        );

        return Api::ok(new OrderResource($order->load(['statusHistory', 'delivery'])));
    }

    public function confirmDelivery(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'proof_code' => ['required', 'string', 'max:10'],
        ]);

        $order = $this->orders->confirmDelivery($order, 'client', $request->user()->id, $data['proof_code']);

        return Api::ok(new OrderResource($order->load(['statusHistory', 'delivery'])));
    }

    public function dispute(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $order = $this->orders->openDispute($order, 'client', $request->user()->id, $data['reason']);

        return Api::ok(new OrderResource($order->load(['statusHistory', 'delivery'])));
    }

    public function adminResolveDispute(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'resolution' => ['required', 'in:release,refund'],
            'refund_amount' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'reason' => ['sometimes', 'nullable', 'string', 'max:500'],
        ]);

        $order = $this->orders->resolveDispute(
            $order,
            $data['resolution'],
            $request->user()->id,
            $data['refund_amount'] ?? null,
        );

        return Api::ok(new OrderResource($order->load(['statusHistory', 'delivery', 'refunds'])));
    }

    public function adminCancel(Request $request, Order $order): JsonResponse
    {
        if (in_array($order->status, [OrderStatus::Cancelled, OrderStatus::Refunded])) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
            'refund_amount' => ['sometimes', 'nullable', 'integer', 'min:0'],
        ]);

        $order = $this->orders->cancelByPorteuse(
            $order,
            $request->user()->id,
            $data['reason'],
            $data['refund_amount'] ?? null,
        );

        return Api::ok(new OrderResource($order->load(['statusHistory', 'payment', 'refunds'])));
    }

    private function userAddress(Request $request, string $addressId): ?Address
    {
        return $request->user()->addresses()->where('id', $addressId)->first();
    }

    private function userOpenCart(Request $request)
    {
        return $this->cartService->getOpenCartForUser($request->user());
    }

    private function canAccess(Request $request, Order $order): bool
    {
        if ($order->user_id === $request->user()->id) {
            return true;
        }

        return $this->isOwnVendorOrder($request, $order);
    }

    private function isOwnVendorOrder(Request $request, Order $order): bool
    {
        $vendor = $request->user()->vendor()->first();

        if ($vendor === null) {
            return false;
        }

        return $vendor->status === VendorStatus::Active->value
            && $vendor->closed_at === null
            && $vendor->id === $order->vendor_id;
    }
}
