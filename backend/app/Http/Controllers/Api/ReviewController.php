<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ReviewResource;
use App\Models\Order;
use App\Models\Product;
use App\Services\ReviewService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Avis client (cahier de conception v1.0) : dépôt d'une note sur le vendeur
 * et le livreur après livraison.
 */
class ReviewController extends Controller
{
    public function __construct(private readonly ReviewService $reviews) {}

    public function store(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'rating' => ['required', 'integer', 'between:1,5'],
            'driver_rating' => ['sometimes', 'nullable', 'integer', 'between:1,5'],
            'comment' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'product_ids' => ['sometimes', 'array'],
            'product_ids.*' => ['uuid', 'exists:products,id'],
        ]);

        $review = $this->reviews->submitForOrder($order, $request->user(), $data);

        return Api::created(new ReviewResource($review->loadMissing('user', 'order')));
    }

    /**
     * Avis direct sur un produit (sans commande) : note + commentaire du
     * client, renvoyant la note moyenne et le nombre d'avis mis à jour.
     */
    public function storeForProduct(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'rating' => ['required', 'integer', 'between:1,5'],
            'comment' => ['sometimes', 'nullable', 'string', 'max:1000'],
        ]);

        $review = $this->reviews->submitForProduct($product, $request->user(), $data);

        $average = $product->reviews()->avg('rating');
        $count = $product->reviews()->count();

        return Api::created([
            'id' => $review->id,
            'rating' => $review->rating,
            'comment' => $review->comment,
            'product_rating' => $average !== null ? round((float) $average, 1) : null,
            'product_reviews_count' => $count,
        ]);
    }
}
