<?php

namespace App\Services;

use App\Models\PlatformSetting;
use Illuminate\Support\Facades\Cache;

/**
 * Configuration financière modifiable depuis le back-office.
 * Les clés de config restent les valeurs de secours lors du premier démarrage.
 */
class PlatformPricingSettings
{
    private const CACHE_KEY = 'platform-pricing-settings-v1';

    /** @return array<string, mixed> */
    public function all(): array
    {
        return Cache::rememberForever(self::CACHE_KEY, function (): array {
            $defaults = [
                'order_minimum_fee' => (int) config('beninfood.delivery_pricing.min_fee', 500),
                'order_default_fee' => (int) config('beninfood.delivery_pricing.default_fee', 1000),
                // Frais d'approche : trajet du livreur vers le point de collecte.
                'approach_free_km' => (int) config('beninfood.delivery_pricing.approach_free_km', 3),
                'approach_per_km' => (int) config('beninfood.delivery_pricing.approach_per_km', 50),
                'parcel_minimum_fee' => 500,
                'parcel_default_fee' => (int) config('beninfood.parcels.default_fee', 1000),
                // Montant fixe payé par le créateur du colis (hors commission).
                'parcel_creation_fee' => (int) config('beninfood.parcels.creation_fee', 150),
                // Taux de la commission client, calculée sur le sous-total produits.
                'service_fee_rate' => (int) config('beninfood.service_fee.rate', 5),
                'delivery_commission_rate' => (int) config('beninfood.delivery_commission.rate', 20),
                'parcel_commission_rate' => (int) config('beninfood.parcels.commission_rate', 20),
                'gateway_fee_basis_points' => (int) config('beninfood.payment_gateway.fee_rate_basis_points', 120),
                'minimum_payout' => (int) config('beninfood.wallet.min_payout', 1000),
                'vendor_commission_rate' => (int) config('beninfood.commission.default_rate', 10),
            ];

            $stored = PlatformSetting::query()->whereKey('pricing')->value('value');

            if (is_string($stored)) {
                $stored = json_decode($stored, true);
            }

            return array_replace($defaults, is_array($stored) ? $stored : []);
        });
    }

    public function get(string $key): int
    {
        return (int) ($this->all()[$key] ?? 0);
    }

    /** @param array<string, int> $values */
    public function update(array $values, ?string $updatedBy = null): void
    {
        $merged = array_replace($this->all(), $values);

        PlatformSetting::query()->updateOrCreate(
            ['key' => 'pricing'],
            ['value' => $merged, 'updated_by' => $updatedBy],
        );

        Cache::forget(self::CACHE_KEY);
    }
}
