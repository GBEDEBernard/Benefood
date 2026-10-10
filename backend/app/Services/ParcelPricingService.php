<?php

namespace App\Services;

/**
 * Tarification des colis (cahier de conception v1.0, phase 3).
 *
 * Le prix dépend de la distance : 500 F (≤ 3 km), 1 000 F (≤ 7 km),
 * 2 000 F au-delà. Le livreur perçoit 80 %, la plateforme 20 %.
 */
class ParcelPricingService
{
    /**
     * @return array{distance_km: ?float, delivery_fee: int, commission_rate: int, commission_amount: int, partner_amount: int, platform_amount: int}
     */
    public function quote(?float $distanceKm): array
    {
        $fee = $this->feeForDistance($distanceKm);
        $rate = (int) config('beninfood.parcels.commission_rate', 20);
        $commission = (int) round($fee * $rate / 100);

        return [
            'distance_km' => $distanceKm,
            'delivery_fee' => $fee,
            'commission_rate' => $rate,
            'commission_amount' => $commission,
            'partner_amount' => $fee - $commission,
            'platform_amount' => $commission,
        ];
    }

    /** Prix applicable pour une distance donnée (paliers configurables). */
    public function feeForDistance(?float $distanceKm): int
    {
        $tiers = (array) config('beninfood.parcels.tiers', []);
        $default = (int) config('beninfood.parcels.default_fee', 1000);

        if ($distanceKm === null) {
            return $default;
        }

        $lastFee = $default;

        foreach ($tiers as $tier) {
            $max = $tier['max_km'] ?? null;
            $fee = (int) ($tier['fee'] ?? $default);

            if ($max === null || $distanceKm <= (float) $max) {
                return $fee;
            }

            $lastFee = $fee;
        }

        return $lastFee;
    }
}
