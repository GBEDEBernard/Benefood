<?php

namespace App\Services;

use App\Enums\CartStatus;
use App\Exceptions\DomainException;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Product;
use App\Models\User;
use App\Models\Vendor;

/**
 * Panier mono-vendeur persistant (J79/J80).
 *
 * La contrainte métier retenue est le panier mono-vendeur : un panier ouvert
 * ne peut contenir des produits que d'un seul vendeur. Ajouter un produit d'un
 * autre vendeur lève une erreur tant que le panier contient au moins une ligne.
 */
class CartService
{
    public function __construct(private readonly CatalogService $catalog) {}

    /**
     * Récupère le panier ouvert existant pour l'utilisateur.
     */
    public function getOpenCartForUser(User $user): ?Cart
    {
        return $user->carts()->open()->with('items.product')->first();
    }

    /**
     * Récupère ou crée un panier ouvert pour l'utilisateur et le vendeur.
     *
     * @throws DomainException cart.vendor_conflict si le panier ouvert est rattaché à un autre vendeur
     */
    public function getOrCreateOpenCart(User $user, Vendor $vendor): Cart
    {
        $existing = $user->carts()->open()->first();

        if ($existing !== null) {
            if ($existing->vendor_id !== $vendor->id) {
                if ($existing->items()->count() > 0) {
                    throw new DomainException(
                        'cart.vendor_conflict',
                        'Un panier contenant des articles d\'un autre vendeur est déjà ouvert. Videz-le avant de commander ailleurs.',
                        409,
                    );
                }

                $existing->update(['vendor_id' => $vendor->id]);
                $existing->refresh();
            }

            return $existing->load('items.product');
        }

        return Cart::create([
            'user_id' => $user->id,
            'vendor_id' => $vendor->id,
            'status' => CartStatus::Open->value,
        ]);
    }

    /**
     * Ajoute un produit au panier ou crée une nouvelle ligne.
     *
     * @throws DomainException cart.vendor_conflict produit d'un autre vendeur
     * @throws DomainException cart.product_unavailable produit non commandable
     * @throws DomainException cart.quantity_invalid quantité invalide
     * @throws DomainException cart.insufficient_stock stock insuffisant
     */
    public function addItem(Cart $cart, Product $product, int $quantity): CartItem
    {
        if (! $cart->isOpen()) {
            throw new DomainException('cart.closed', 'Ce panier n\'est plus modifiable.', 422);
        }

        if ($product->vendor_id !== $cart->vendor_id) {
            throw new DomainException('cart.vendor_conflict', 'Ce produit appartient à un autre vendeur.', 409);
        }

        if (! $product->isOrderable()) {
            throw new DomainException('cart.product_unavailable', 'Ce produit n\'est pas disponible.', 422);
        }

        if ($quantity < 1) {
            throw new DomainException('cart.quantity_invalid', 'La quantité doit être au moins 1.', 422);
        }

        $existingItem = $cart->items()->where('product_id', $product->id)->first();

        $newQty = ($existingItem?->quantity ?? 0) + $quantity;

        $this->assertStockSufficient($product, $newQty);

        $unitPrice = (int) $product->price;

        if ($existingItem !== null) {
            $existingItem->update([
                'quantity' => $newQty,
                'subtotal' => $unitPrice * $newQty,
            ]);

            return $existingItem->fresh();
        }

        return $cart->items()->create([
            'product_id' => $product->id,
            'quantity' => $newQty,
            'unit_price' => $unitPrice,
            'subtotal' => $unitPrice * $newQty,
        ]);
    }

    /**
     * Met à jour la quantité d'une ligne du panier.
     *
     * @throws DomainException cart.quantity_invalid quantité invalide
     * @throws DomainException cart.insufficient_stock stock insuffisant
     */
    public function updateQuantity(CartItem $item, int $quantity): CartItem
    {
        $cart = $item->cart;

        if (! $cart->isOpen()) {
            throw new DomainException('cart.closed', 'Ce panier n\'est plus modifiable.', 422);
        }

        if ($quantity < 1) {
            throw new DomainException('cart.quantity_invalid', 'La quantité doit être au moins 1.', 422);
        }

        $product = $item->product()->with('vendor')->first();

        $this->assertStockSufficient($product, $quantity);

        $unitPrice = (int) $product->price;

        $item->update([
            'quantity' => $quantity,
            'unit_price' => $unitPrice,
            'subtotal' => $unitPrice * $quantity,
        ]);

        return $item->fresh();
    }

    public function removeItem(CartItem $item): void
    {
        $item->delete();
    }

    public function clearCart(Cart $cart): void
    {
        $cart->items()->delete();
    }

    /** Marque le panier comme converti en commande. */
    public function markConverted(Cart $cart): void
    {
        $cart->update(['status' => CartStatus::Converted->value]);
    }

    /** Sous-total courant d'un panier (basé sur le prix actuel des produits). */
    public function recalculateTotals(Cart $cart): array
    {
        $cart->loadMissing('items.product');

        $subtotal = $cart->items->sum(fn (CartItem $item) => (int) $item->product->price * $item->quantity);

        return [
            'subtotal' => $subtotal,
            'currency' => config('beninfood.currency', 'XOF'),
            'items_count' => $cart->items->count(),
        ];
    }

    /**
     * @throws DomainException cart.insufficient_stock
     */
    private function assertStockSufficient(Product $product, int $quantity): void
    {
        if ($product->stock_qty !== null && $product->stock_qty < $quantity) {
            throw new DomainException(
                'cart.insufficient_stock',
                'Stock insuffisant pour ce produit ('.$product->stock_qty.' disponibles).',
                422,
            );
        }
    }
}
