<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ReviewResource;
use App\Models\Review;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Avis clients du vendeur (J21 §9) : note moyenne, répartition, commentaires
 * et réponse du vendeur.
 */
class VendorReviewController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $vendor = $request->user()->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        $this->authorize('view', $vendor);

        $base = Review::query()->whereHas('order', fn ($query) => $query->where('vendor_id', $vendor->id));

        $distribution = [1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0];

        foreach ((clone $base)->selectRaw('rating, count(*) as total')->groupBy('rating')->pluck('total', 'rating') as $rating => $total) {
            $distribution[(int) $rating] = (int) $total;
        }

        $summary = [
            'average' => round((float) ((clone $base)->avg('rating') ?? 0), 1),
            'total' => (clone $base)->count(),
            'distribution' => $distribution,
        ];

        $perPage = (int) $request->query('per_page', config('beninfood.pagination.per_page'));
        $reviews = $base
            ->with(['user', 'order', 'items.product'])
            ->orderByDesc('created_at')
            ->paginate($perPage);

        return Api::ok([
            'summary' => $summary,
            'reviews' => ReviewResource::collection($reviews->items())->resolve(),
        ], [
            'pagination' => [
                'total' => $reviews->total(),
                'per_page' => $reviews->perPage(),
                'current_page' => $reviews->currentPage(),
                'last_page' => $reviews->lastPage(),
            ],
        ]);
    }

    public function reply(Request $request, Review $review): JsonResponse
    {
        $vendor = $request->user()->vendor()->first();

        if ($vendor === null) {
            return Api::error('Aucun profil vendeur associé à ce compte.', 'vendor.not_onboarded', 404);
        }

        $this->authorize('view', $vendor);

        $ownsReview = $review->order()->where('vendor_id', $vendor->id)->exists();

        if (! $ownsReview) {
            return Api::error('Ressource introuvable.', 'not_found', 404);
        }

        $data = $request->validate([
            'reply' => ['required', 'string', 'max:1000'],
        ]);

        $review->update([
            'vendor_reply' => $data['reply'],
            'vendor_replied_at' => now(),
        ]);

        $review->load(['user', 'order', 'items.product']);

        return Api::ok(new ReviewResource($review));
    }
}
