<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Exceptions\DomainException;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Review;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Avis client (cahier de conception v1.0, J29 §9).
 *
 * Le client note, après livraison, le vendeur **et** le livreur. La note
 * vendeur alimente la moyenne de la boutique (calculée à la volée), la note
 * livreur met à jour la note moyenne du profil livreur.
 */
class ReviewService
{
    /**
     * @param  array{rating: int, driver_rating?: int|null, comment?: string|null, product_ids?: array<int, string>}  $data
     */
    public function submitForOrder(Order $order, User $client, array $data): Review
    {
        if ($order->user_id !== $client->id) {
            throw new DomainException('review.not_owned', 'Cette commande ne vous appartient pas.', 404);
        }

        if ($order->status !== OrderStatus::Delivered) {
            throw new DomainException('review.order_not_delivered', 'Vous ne pouvez noter qu\'une commande livrée.', 422);
        }

        if ($order->review()->exists()) {
            throw new DomainException('review.already_submitted', 'Vous avez déjà noté cette commande.', 422);
        }

        return DB::transaction(function () use ($order, $client, $data): Review {
            $order->loadMissing('delivery.driverProfile', 'items.product');

            $driverProfileId = $order->delivery?->driver_profile_id;

            /** @var Review $review */
            $review = $order->review()->create([
                'user_id' => $client->id,
                'rating' => $data['rating'],
                'driver_profile_id' => $driverProfileId,
                'driver_rating' => $data['driver_rating'] ?? null,
                'comment' => $data['comment'] ?? null,
                'status' => 'new',
            ]);

            $productIds = $data['product_ids'] ?? $order->items->pluck('product_id')->filter()->all();

            foreach (array_unique($productIds) as $productId) {
                $review->items()->create(['product_id' => $productId]);
            }

            if ($driverProfileId !== null && ($data['driver_rating'] ?? null) !== null) {
                $driver = DriverProfile::find($driverProfileId);

                if ($driver !== null) {
                    $this->refreshDriverRating($driver);
                }
            }

            return $review->fresh(['user', 'order', 'items.product']);
        });
    }

    /** Recalcule la note moyenne d'un livreur depuis les avis reçus. */
    public function refreshDriverRating(DriverProfile $driver): void
    {
        $average = Review::query()
            ->where('driver_profile_id', $driver->id)
            ->whereNotNull('driver_rating')
            ->avg('driver_rating');

        $driver->update([
            'rating' => $average !== null ? round((float) $average, 2) : null,
        ]);
    }
}
