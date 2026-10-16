<?php

namespace Database\Seeders;

use App\Models\DistancePricingRule;
use Illuminate\Database\Seeder;

class DistancePricingRulesSeeder extends Seeder
{
    public function run(): void
    {
        $defaults = [
            DistancePricingRule::ORDER_DELIVERY => [
                ['max_km' => 3, 'base_fee' => 500, 'per_km' => 0],
                ['max_km' => 8, 'base_fee' => 500, 'per_km' => 100],
                ['max_km' => 10, 'base_fee' => 1000, 'per_km' => 0],
                ['max_km' => 15, 'base_fee' => 1000, 'per_km' => 125],
                ['max_km' => null, 'base_fee' => 1625, 'per_km' => 75],
            ],
            DistancePricingRule::PARCEL_DELIVERY => [
                ['max_km' => 3, 'base_fee' => 500, 'per_km' => 0],
                ['max_km' => 7, 'base_fee' => 1000, 'per_km' => 0],
                ['max_km' => null, 'base_fee' => 2000, 'per_km' => 0],
            ],
        ];

        foreach ($defaults as $serviceType => $rules) {
            if (DistancePricingRule::query()->where('service_type', $serviceType)->exists()) {
                continue;
            }

            foreach ($rules as $index => $rule) {
                DistancePricingRule::create($rule + [
                    'service_type' => $serviceType,
                    'discount_percentage' => 0,
                    'sort_order' => $index + 1,
                    'is_active' => true,
                ]);
            }
        }
    }
}
