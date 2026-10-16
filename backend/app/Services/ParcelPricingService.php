<?php

namespace App\Services;

use App\Models\DistancePricingRule;

/**
 * Tarification des colis (cahier de conception v1.0, phase 3).
 *
 * Le prix dépend de la distance : 500 F (≤ 3 km), 1 000 F (≤ 7 km),
 * 2 000 F au-delà. Le livreur perçoit 80 %, la plateforme 20 %.
 */
class ParcelPricingService
{
    /**
     * @return array{distance_km: ?float, delivery_fee: int, commission_rate: int, commission_amount: int, partner_amount: int, platform_amount: int, pricing_snapshot: array<string, mixed>}
     */
    public function quote(?float $distanceKm): array
    {
        $pricing = $this->feeQuote($distanceKm);
        $fee = $pricing['fee'];
        $rate = app(PlatformPricingSettings::class)->get('parcel_commission_rate');
        $commission = (int) round($fee * $rate / 100);

        return [
            'distance_km' => $distanceKm,
            'delivery_fee' => $fee,
            'commission_rate' => $rate,
            'commission_amount' => $commission,
            'partner_amount' => $fee - $commission,
            'platform_amount' => $commission,
            'pricing_snapshot' => $pricing['snapshot'],
        ];
    }

    /** Prix applicable pour une distance donnée (paliers configurables). */
    public function feeForDistance(?float $distanceKm): int
    {
        return $this->feeQuote($distanceKm)['fee'];
    }

    /** @return array{fee: int, snapshot: array<string, mixed>} */
    private function feeQuote(?float $distanceKm): array
    {
        $settings = app(PlatformPricingSettings::class);
        $minimumFee = $settings->get('parcel_minimum_fee');
        $default = $settings->get('parcel_default_fee');

        if ($distanceKm === null) {
            return [
                'fee' => max($minimumFee, $default),
                'snapshot' => ['method' => 'default_fee', 'fee' => max($minimumFee, $default)],
            ];
        }

        $rules = DistancePricingRule::query()
            ->where('service_type', DistancePricingRule::PARCEL_DELIVERY)
            ->where('is_active', true)
            ->orderByRaw('max_km IS NULL')
            ->orderBy('max_km')
            ->get();

        if ($rules->isNotEmpty()) {
            $previousMaxKm = 0.0;

            foreach ($rules as $rule) {
                if ($rule->max_km === null || $distanceKm <= (float) $rule->max_km) {
                    $rawFee = (int) round((int) $rule->base_fee + (int) $rule->per_km * max(0, $distanceKm - $previousMaxKm));
                    $discountedFee = (int) round($rawFee * (100 - (int) $rule->discount_percentage) / 100);

                    return [
                        'fee' => max($minimumFee, $discountedFee),
                        'snapshot' => [
                            'rule_id' => $rule->id,
                            'from_km' => $previousMaxKm,
                            'max_km' => $rule->max_km,
                            'base_fee' => (int) $rule->base_fee,
                            'per_km' => (int) $rule->per_km,
                            'discount_percentage' => (int) $rule->discount_percentage,
                            'raw_fee' => $rawFee,
                            'discounted_fee' => $discountedFee,
                            'minimum_fee' => $minimumFee,
                        ],
                    ];
                }

                $previousMaxKm = (float) $rule->max_km;
            }
        }

        // Compatibilité avant le premier lancement du seeder des barèmes.
        foreach ((array) config('beninfood.parcels.tiers', []) as $tier) {
            $max = $tier['max_km'] ?? null;
            $fee = (int) ($tier['fee'] ?? $default);

            if ($max === null || $distanceKm <= (float) $max) {
                return [
                    'fee' => max($minimumFee, $fee),
                    'snapshot' => ['method' => 'legacy_config', 'max_km' => $max, 'fee' => $fee],
                ];
            }
        }

        return [
            'fee' => max($minimumFee, $default),
            'snapshot' => ['method' => 'default_fee', 'fee' => max($minimumFee, $default)],
        ];
    }
}
