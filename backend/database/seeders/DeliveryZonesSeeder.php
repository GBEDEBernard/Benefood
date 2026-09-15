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
            ['name' => 'Cotonou Centre', 'city' => 'Cotonou', 'sort_order' => 1, 'identification_mode' => 'zone'],
            ['name' => 'Cotonou Akpakpa', 'city' => 'Cotonou', 'sort_order' => 2, 'identification_mode' => 'quarter', 'terms' => ['Akpakpa', 'Akpakpa Dodomè', 'Akpakpa Adjidogomè']],
            ['name' => 'Cotonou Fidjrossè', 'city' => 'Cotonou', 'sort_order' => 3, 'identification_mode' => 'quarter', 'terms' => ['Fidjrossè', 'Fidjrossè Marine', 'Fidjrossè Plaza']],
            ['name' => 'Cotonou Cadjehoun', 'city' => 'Cotonou', 'sort_order' => 4, 'identification_mode' => 'quarter', 'terms' => ['Cadjehoun', 'Cadjehoun Centre', 'Aéroport']],
            ['name' => 'Abomey-Calavi Centre', 'city' => 'Abomey-Calavi', 'sort_order' => 5, 'identification_mode' => 'zone'],
            ['name' => 'Porto-Novo Centre', 'city' => 'Porto-Novo', 'sort_order' => 6, 'identification_mode' => 'zone'],
            ['name' => 'Parakou Centre', 'city' => 'Parakou', 'sort_order' => 7, 'identification_mode' => 'zone'],
            ['name' => 'Bohicon Centre', 'city' => 'Bohicon', 'sort_order' => 8, 'identification_mode' => 'zone'],
            ['name' => 'Cotonou 10 km', 'city' => 'Cotonou', 'sort_order' => 9, 'identification_mode' => 'distance', 'center_latitude' => 6.3702932, 'center_longitude' => 2.3912362, 'radius_km' => 10],
        ];

        foreach ($zones as $zone) {
            DeliveryZone::updateOrCreate(
                ['name' => $zone['name']],
                $zone,
            );
        }
    }
}
