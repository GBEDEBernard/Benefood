<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ReviewResource;
use App\Models\Order;
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
}
