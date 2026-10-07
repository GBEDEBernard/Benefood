<?php

namespace Database\Seeders;

use App\Models\Notification;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Données de démonstration du profil client (J153) :
 * solde portefeuille, coupons, favoris et notifications lisibles dès
 * la première connexion de l'app mobile.
 */
class ProfileDemoSeeder extends Seeder
{
    private const WALLETS = [24500, 15000, 8000];

    public function run(): void
    {
        $clients = User::whereHas('roles', fn ($query) => $query->where('slug', 'client'))
            ->orderBy('created_at')
            ->get();

        foreach ($clients as $index => $client) {
            $client->update(['wallet_balance' => self::WALLETS[$index % count(self::WALLETS)]]);

            $this->seedCoupons($client);
            $this->seedFavorites($client, $index);
            $this->seedNotifications($client, $index);
        }
    }

    private function seedCoupons(User $client): void
    {
        if ($client->userCoupons()->exists()) {
            return;
        }

        $coupons = [
            [
                'code' => 'BIENVENUE10',
                'label' => '10 % sur votre première commande',
                'discount_type' => 'percent',
                'discount_value' => 10,
                'min_amount' => 3000,
                'expires_at' => now()->addDays(30),
            ],
            [
                'code' => 'MAQUIS500',
                'label' => '500 FCFA sur le maquis',
                'discount_type' => 'fixed',
                'discount_value' => 500,
                'min_amount' => 2500,
                'expires_at' => now()->addDays(15),
            ],
            [
                'code' => 'LIVRAISON0',
                'label' => 'Livraison offerte (1 500 FCFA)',
                'discount_type' => 'fixed',
                'discount_value' => 1500,
                'min_amount' => 5000,
                'expires_at' => now()->addDays(60),
            ],
        ];

        foreach ($coupons as $coupon) {
            $client->userCoupons()->create($coupon);
        }
    }

    private function seedFavorites(User $client, int $index): void
    {
        if ($client->favorites()->exists()) {
            return;
        }

        $products = Product::query()
            ->where('is_active', true)
            ->where('is_available', true)
            ->orderBy('name')
            ->limit(3 - min($index, 2))
            ->get();

        foreach ($products as $product) {
            $client->favorites()->create(['product_id' => $product->id]);
        }
    }

    private function seedNotifications(User $client, int $index): void
    {
        if ($client->appNotifications()->count() >= 4) {
            return;
        }

        $reference = 'BF-'.str_pad((string) (100 + $index), 4, '0', STR_PAD_LEFT);

        $rows = [
            [
                'type' => 'order.accepted',
                'title' => 'Commande acceptée',
                'body' => "Votre commande #{$reference} a été acceptée.",
                'read_at' => now()->subDays(2),
            ],
            [
                'type' => 'order.delivered',
                'title' => 'Commande livrée',
                'body' => "Votre commande #{$reference} a été livrée.",
                'read_at' => now()->subDay(),
            ],
            [
                'type' => 'complaint.resolved',
                'title' => 'Réclamation traitée',
                'body' => 'Votre réclamation « Colis non reçu » a été traitée.',
                'read_at' => null,
            ],
            [
                'type' => 'order.refund_initiated',
                'title' => 'Remboursement en cours',
                'body' => "Un remboursement de 2 000 FCFA est en cours pour la commande #{$reference}.",
                'read_at' => null,
            ],
        ];

        foreach ($rows as $row) {
            Notification::create($row + [
                'user_id' => $client->id,
                'data' => null,
            ]);
        }
    }
}
