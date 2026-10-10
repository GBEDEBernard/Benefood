<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\Review;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class VendorReviewsTest extends TestCase
{
    use RefreshDatabase;

    public function test_vendor_can_list_reviews_with_summary(): void
    {
        $vendorUser = User::factory()->create();
        $vendor = Vendor::factory()->create(['user_id' => $vendorUser->id, 'status' => 'active']);
        $client = User::factory()->create(['name' => 'Awa Client']);

        $goodOrder = $this->orderFor($client, $vendor, '#BF1001');
        $badOrder = $this->orderFor($client, $vendor, '#BF1002');

        Review::create(['order_id' => $goodOrder->id, 'user_id' => $client->id, 'rating' => 5, 'comment' => 'Excellent']);
        Review::create(['order_id' => $badOrder->id, 'user_id' => $client->id, 'rating' => 3, 'comment' => 'Moyen']);

        Sanctum::actingAs($vendorUser);

        $this->getJson('/api/v1/vendors/me/reviews')
            ->assertOk()
            ->assertJsonPath('data.summary.total', 2)
            ->assertJsonPath('data.summary.average', 4)
            ->assertJsonPath('data.summary.distribution.5', 1)
            ->assertJsonPath('data.summary.distribution.3', 1)
            ->assertJsonCount(2, 'data.reviews')
            ->assertJsonStructure(['data' => ['summary', 'reviews' => [['id', 'rating', 'comment', 'customer_name', 'order_reference', 'vendor_reply']]]]);
    }

    public function test_vendor_can_reply_to_own_review(): void
    {
        $vendorUser = User::factory()->create();
        $vendor = Vendor::factory()->create(['user_id' => $vendorUser->id, 'status' => 'active']);
        $client = User::factory()->create();

        $order = $this->orderFor($client, $vendor, '#BF1003');
        $review = Review::create(['order_id' => $order->id, 'user_id' => $client->id, 'rating' => 4, 'comment' => 'Bon']);

        Sanctum::actingAs($vendorUser);

        $this->postJson("/api/v1/vendors/me/reviews/{$review->id}/reply", [
            'reply' => 'Merci pour votre retour !',
        ])->assertOk()
            ->assertJsonPath('data.vendor_reply', 'Merci pour votre retour !');

        $this->assertDatabaseHas('reviews', [
            'id' => $review->id,
            'vendor_reply' => 'Merci pour votre retour !',
        ]);
    }

    public function test_vendor_cannot_reply_to_foreign_review(): void
    {
        $otherVendorUser = User::factory()->create();
        $otherVendor = Vendor::factory()->create(['user_id' => $otherVendorUser->id, 'status' => 'active']);

        $vendorUser = User::factory()->create();
        Vendor::factory()->create(['user_id' => $vendorUser->id, 'status' => 'active']);
        $client = User::factory()->create();

        $order = $this->orderFor($client, $otherVendor, '#BF1004');
        $review = Review::create(['order_id' => $order->id, 'user_id' => $client->id, 'rating' => 1, 'comment' => 'Mauvais']);

        Sanctum::actingAs($vendorUser);

        $this->postJson("/api/v1/vendors/me/reviews/{$review->id}/reply", [
            'reply' => 'Réponse indue',
        ])->assertNotFound();
    }

    private function orderFor(User $client, Vendor $vendor, string $reference): Order
    {
        return Order::create([
            'reference' => $reference,
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => 'delivered',
            'payment_status' => 'confirmed',
            'currency' => 'XOF',
            'subtotal' => 1000,
            'total' => 1000,
        ]);
    }
}
