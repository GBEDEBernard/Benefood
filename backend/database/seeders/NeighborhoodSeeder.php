<?php

namespace Database\Seeders;

use App\Models\DeliveryZone;
use App\Models\Neighborhood;
use Illuminate\Database\Seeder;

/**
 * Référentiel des quartiers de Cotonou et d'Abomey-Calavi (recherche par
 * localité, sélecteurs d'adresse/colis). Les coordonnées sont des centres
 * approximatifs ; elles servent de repli quand le GPS n'est pas disponible.
 */
class NeighborhoodSeeder extends Seeder
{
    /**
     * @var array<string, array<string, array{0: float, 1: float}>>
     */
    private const QUARTERS = [
        'Cotonou' => [
            'Ganhi' => [6.3620, 2.4260],
            'Dantokpa' => [6.3680, 2.4310],
            'Saint-Michel' => [6.3650, 2.4220],
            'Gbégamey' => [6.3730, 2.4130],
            'Jéricho' => [6.3800, 2.4120],
            'Cadjèhoun' => [6.3660, 2.4000],
            'Étoile Rouge' => [6.3780, 2.4190],
            'Akpakpa' => [6.3570, 2.4520],
            'Sainte-Rita' => [6.3620, 2.4430],
            'Sègbèya' => [6.3700, 2.4400],
            'Yénawa' => [6.3660, 2.4480],
            'Kpondéhou' => [6.3720, 2.4480],
            'Avotrou' => [6.3740, 2.4520],
            'Donatin' => [6.3680, 2.4560],
            'Fidjrossè' => [6.3450, 2.3830],
            'Haie Vive' => [6.3580, 2.4030],
            'Les Cocotiers' => [6.3620, 2.3900],
            'Houéyiho' => [6.3630, 2.4080],
            'Agla' => [6.3830, 2.3900],
            'Aïbatin' => [6.3780, 2.3980],
            'Zogbo' => [6.3700, 2.3980],
            'Mènontin' => [6.3830, 2.4080],
        ],
        'Abomey-Calavi' => [
            'Calavi-Centre' => [6.4489, 2.3556],
            'Kpota' => [6.4450, 2.3700],
            'Zogbadjè' => [6.4400, 2.3600],
            'Tankpè' => [6.4300, 2.3450],
            'Tokpa-Zoungo' => [6.4520, 2.3650],
            'Zopah' => [6.4380, 2.3500],
            'Agori' => [6.4550, 2.3400],
            'Godomey-Togoudo' => [6.3900, 2.3450],
            'Cocotomey' => [6.3930, 2.3600],
            'Cococodji' => [6.3800, 2.3600],
            'Womey' => [6.4200, 2.3300],
            'Dékoungbé' => [6.4600, 2.3200],
            'Togbin' => [6.3300, 2.3500],
            'Hêvié' => [6.4100, 2.3200],
            'Akassato' => [6.5000, 2.3400],
            'Glo-Djigbé' => [6.5200, 2.3000],
            'Ouèdo' => [6.4700, 2.4000],
            'Togba' => [6.4300, 2.4000],
            'Zinvié' => [6.4900, 2.4200],
            'Kpanroun' => [6.4600, 2.3800],
        ],
    ];

    /**
     * Quartiers rattachés à une zone de livraison nommée (sinon zone de la ville).
     *
     * @var array<string, string>
     */
    private const ZONE_BY_QUARTER = [
        'Akpakpa' => 'Cotonou Akpakpa',
        'Sainte-Rita' => 'Cotonou Akpakpa',
        'Sègbèya' => 'Cotonou Akpakpa',
        'Yénawa' => 'Cotonou Akpakpa',
        'Kpondéhou' => 'Cotonou Akpakpa',
        'Avotrou' => 'Cotonou Akpakpa',
        'Donatin' => 'Cotonou Akpakpa',
        'Fidjrossè' => 'Cotonou Fidjrossè',
        'Cadjèhoun' => 'Cotonou Cadjehoun',
    ];

    /**
     * @var array<string, string>
     */
    private const ZONE_BY_CITY = [
        'Cotonou' => 'Cotonou Centre',
        'Abomey-Calavi' => 'Abomey-Calavi Centre',
    ];

    public function run(): void
    {
        $zoneIds = DeliveryZone::query()->pluck('id', 'name');
        $sortOrder = 0;

        foreach (self::QUARTERS as $city => $quarters) {
            foreach ($quarters as $name => [$latitude, $longitude]) {
                $zoneName = self::ZONE_BY_QUARTER[$name] ?? self::ZONE_BY_CITY[$city] ?? null;

                Neighborhood::query()->updateOrCreate(
                    ['city' => $city, 'name' => $name],
                    [
                        'latitude' => $latitude,
                        'longitude' => $longitude,
                        'delivery_zone_id' => $zoneName !== null ? ($zoneIds[$zoneName] ?? null) : null,
                        'sort_order' => $sortOrder++,
                        'is_active' => true,
                    ],
                );
            }
        }
    }
}
