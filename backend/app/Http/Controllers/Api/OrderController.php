<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Enums\VendorStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Address;
use App\Models\Order;
use App\Services\CartService;
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
    ) {}

    public function summary(Request $request): JsonResponse
    {
        $data = $request->validate([
            'address_id' => ['required', 'uuid', 'exists:addresses,id'],
        ]);

        $address = $this->userAddress($request, $data['address_id']);
        $cart = $this->userOpenCart($request);

        if ($address === null) {
            return Api::error('Adresse introuvable.', 'not_found', 404);
        }

        if ($cart === null) {
            return Api::error('Votre panier est vide.', 'order.empty_cart', 422);
        }

        return Api::ok($this->orders->summary($cart, ['address' => $address]));
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'address_id' => ['required', 'uuid', 'exists:addresses,id'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:1000'],
        ]);

        $address = $this->userAddress($request, $data['address_id']);
        $cart = $this->userOpenCart($request);

        if ($address === null) {
            return Api::error('Adresse introuvable.', 'not_found', 404);
        }

        if ($cart === null) {
            return Api::error('Votre panier est vide.', 'order.empty_cart', 422);
        }

        $order = $this->orders->createFromCart($cart, $address, $data['notes'] ?? null);

        return Api::created(new OrderResource($order));
    }

    public function index(Request $request): JsonResponse
    {
        $orders = $request->user()->orders()
            ->with(['vendor', 'items'])
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

        $order->load(['vendor', 'items', 'payment', 'financials', 'statusHistory', 'refunds', 'delivery.driverProfile.user']);

        return Api::ok(new OrderResource($order));
    }

    public function vendorIndex(Request $request): JsonResponse
    {
        $vendor = $request->user()->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        $orders = $vendor->orders()
            ->with(['user', 'items'])
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

        $order = $this->orders->markReady($order, $request->user()->id);

        return Api::ok(new OrderResource($order->load(['statusHistory', 'delivery'])));
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
