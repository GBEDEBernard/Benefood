<?php

namespace Database\Seeders;

use App\Models\DeliveryZone;
use Illuminate\Database\Seeder;

class DeliveryZonesSeeder extends Seeder
{
    /**
     * Zones de livraison initiales (à faire valider par la porteuse).
     */
    public function run(): void
    {
        $zones = [
            ['name' => 'Cotonou Centre', 'city' => 'Cotonou', 'sort_order' => 1],
            ['name' => 'Cotonou Akpakpa', 'city' => 'Cotonou', 'sort_order' => 2],
            ['name' => 'Cotonou Fidjrossè', 'city' => 'Cotonou', 'sort_order' => 3],
            ['name' => 'Cotonou Cadjehoun', 'city' => 'Cotonou', 'sort_order' => 4],
            ['name' => 'Abomey-Calavi Centre', 'city' => 'Abomey-Calavi', 'sort_order' => 5],
            ['name' => 'Porto-Novo Centre', 'city' => 'Porto-Novo', 'sort_order' => 6],
            ['name' => 'Parakou Centre', 'city' => 'Parakou', 'sort_order' => 7],
            ['name' => 'Bohicon Centre', 'city' => 'Bohicon', 'sort_order' => 8],
        ];

        foreach ($zones as $zone) {
            DeliveryZone::updateOrCreate(
                ['name' => $zone['name']],
                [
                    'city' => $zone['city'],
                    'sort_order' => $zone['sort_order'],
                    'is_active' => true,
                ],
            );
        }
    }
}
