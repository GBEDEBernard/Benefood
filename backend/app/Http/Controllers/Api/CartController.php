<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CartResource;
use App\Models\CartItem;
use App\Models\Product;
use App\Services\CartService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Panier client (M5 — J79/J80) : persistant, mono-vendeur.
 */
class CartController extends Controller
{
    public function __construct(private readonly CartService $cartService) {}

    public function show(Request $request): JsonResponse
    {
        $cart = $this->cartService->getOpenCartForUser($request->user());

        return Api::ok($cart !== null ? new CartResource($cart) : null);
    }

    public function addItem(Request $request): JsonResponse
    {
        $data = $request->validate([
            'product_id' => ['required', 'uuid', 'exists:products,id'],
            'quantity' => ['sometimes', 'integer', 'min:1', 'max:999'],
        ]);

        $product = Product::findOrFail($data['product_id']);

        $cart = $this->cartService->getOrCreateOpenCart($request->user(), $product->vendor);

        $this->cartService->addItem($cart, $product, (int) ($data['quantity'] ?? 1));

        return Api::ok(new CartResource($cart->load('items.product', 'vendor')));
    }

    public function updateItem(Request $request, CartItem $item): JsonResponse
    {
        if (! $this->belongsToUser($request, $item)) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'quantity' => ['required', 'integer', 'min:1', 'max:999'],
        ]);

        $this->cartService->updateQuantity($item, $data['quantity']);

        return Api::ok(new CartResource($item->cart->load('items.product', 'vendor')));
    }

    public function destroyItem(Request $request, CartItem $item): JsonResponse
    {
        if (! $this->belongsToUser($request, $item)) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $this->cartService->removeItem($item);

        return Api::noContent();
    }

    public function clear(Request $request): JsonResponse
    {
        $cart = $this->cartService->getOpenCartForUser($request->user());

        if ($cart !== null) {
            $this->cartService->clearCart($cart);
        }

        return Api::noContent();
    }

    private function belongsToUser(Request $request, CartItem $item): bool
    {
        $cart = $item->cart()->first();

        if ($cart === null || $cart->user_id !== $request->user()->id) {
            return false;
        }

        return true;
    }
}
