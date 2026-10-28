<?php

namespace App\Services;

use App\Exceptions\DomainException;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\DistancePricingRule;
use App\Models\DriverProfile;
use App\Models\Vendor;
use Illuminate\Support\Str;

/**
 * Tarification livraison (M5 — J72/J73).
 *
 * - J72 : résolution automatique de la zone depuis l'adresse client
 *   (quartier/secteur/distance/havensine selon `identification_mode`).
 * - J73 : calcul des frais de livraison avant validation de commande, avec
 *   surcharge vendeur prioritaire puis tarif par défaut de la zone.
 */
class DeliveryPricingService
{
    public const EARTH_RADIUS_KM = 6371.0;

    /**
     * Résout la zone de livraison correspondant à l'adresse fournie.
     *
     * @param  array{city: ?string, area: ?string, address_text: ?string, latitude: float|string|null, longitude: float|string|null}  $address
     */
    public function resolveZone(array $address): ?DeliveryZone
    {
        $candidateZones = DeliveryZone::query()
            ->active()
            ->orderBy('sort_order')
            ->get();

        $matches = [];

        foreach ($candidateZones as $zone) {
            $score = $this->matchScore($zone, $address);

            if ($score > 0) {
                $matches[] = [$zone, $score];
            }
        }

        if ($matches === []) {
            return null;
        }

        usort($matches, fn ($a, $b) => $b[1] <=> $a[1]);

        return $matches[0][0];
    }

    /**
     * Résout la zone et détaille comment elle a été trouvée (J174/J176) :
     * critère gagnant et distance jusqu'au centre de la zone.
     *
     * @return array{zone: DeliveryZone, matched_by: string, distance_km: ?float}|null
     */
    public function matchDetails(array $address): ?array
    {
        $candidateZones = DeliveryZone::query()
            ->active()
            ->orderBy('sort_order')
            ->get();

        $best = null;

        foreach ($candidateZones as $zone) {
            $breakdown = $this->scoreBreakdown($zone, $address);
            $total = array_sum($breakdown);

            if ($total > 0 && ($best === null || $total > $best['score'])) {
                $best = [
                    'zone' => $zone,
                    'score' => $total,
                    'breakdown' => $breakdown,
                ];
            }
        }

        if ($best === null) {
            return null;
        }

        arsort($best['breakdown']);
        $matchedBy = (string) key($best['breakdown']);

        return [
            'zone' => $best['zone'],
            'matched_by' => $matchedBy,
            'distance_km' => $this->distanceKm(
                $address['latitude'] ?? null,
                $address['longitude'] ?? null,
                $best['zone']->center_latitude,
                $best['zone']->center_longitude,
            ),
        ];
    }

    /**
     * Calcule les frais de livraison pour une zone donnée.
     *
     * Le prix dépend de la distance boutique → client dès que les coordonnées
     * des deux parties sont connues ; sinon on retombe sur le tarif de zone.
     *
     * @return array{zone: DeliveryZone, rate: ?DeliveryRate, delivery_fee: int, distance_km: ?float}
     */
    public function quoteForVendor(Vendor $vendor, array $address): array
    {
        $zone = $this->resolveZone($address);

        if ($zone === null) {
            throw new DomainException('delivery.zone_not_found', 'Aucune zone de livraison ne correspond à cette adresse.', 422);
        }

        $rate = $this->rateForZone($zone, $vendor->id);

        $distanceKm = $this->distanceKm(
            $vendor->latitude,
            $vendor->longitude,
            $address['latitude'] ?? null,
            $address['longitude'] ?? null,
        );

        $minimumFee = app(PlatformPricingSettings::class)->get('order_minimum_fee');
        $fallbackFee = app(PlatformPricingSettings::class)->get('order_default_fee');
        $distanceRule = $distanceKm !== null ? $this->distanceRuleQuote($distanceKm) : null;

        $deliveryFee = $distanceKm !== null
            ? ($distanceRule['fee'] ?? $this->feeForDistance($distanceKm))
            : max($minimumFee, $rate !== null ? (int) $rate->price : $fallbackFee);

        return [
            'zone' => $zone,
            'rate' => $rate,
            'delivery_fee' => $distanceKm !== null ? max($minimumFee, $deliveryFee) : $deliveryFee,
            'distance_km' => $distanceKm,
            'distance_pricing_rule' => $distanceRule['snapshot'] ?? null,
        ];
    }

    /**
     * Frais d'approche : trajet du livreur jusqu'au point de collecte.
     *
     * Les premiers kilomètres sont offerts, puis chaque kilomètre est facturé
     * au tarif configuré par la porteuse. Le montant est arrondi au franc.
     *
     * @return array{distance_km: ?float, billable_km: float, fee: int, snapshot: array<string, mixed>}
     */
    public function approachQuote(DriverProfile $driver, Vendor $vendor): array
    {
        return $this->approachQuoteForPoint(
            $driver,
            $vendor->pickup_latitude ?? $vendor->latitude,
            $vendor->pickup_longitude ?? $vendor->longitude,
        );
    }

    /** Frais d'approche pour un point de collecte libre (colis). */
    public function approachQuoteForPoint(DriverProfile $driver, ?float $pickupLatitude, ?float $pickupLongitude): array
    {
        $distanceKm = $this->distanceKm(
            $driver->last_latitude,
            $driver->last_longitude,
            $pickupLatitude,
            $pickupLongitude,
        );

        $settings = app(PlatformPricingSettings::class);
        $freeKm = max(0, $settings->get('approach_free_km'));
        $perKm = max(0, $settings->get('approach_per_km'));
        $billableKm = $distanceKm === null ? 0.0 : max(0.0, $distanceKm - $freeKm);
        $fee = (int) round($billableKm * $perKm);

        return [
            'distance_km' => $distanceKm !== null ? round($distanceKm, 3) : null,
            'billable_km' => round($billableKm, 3),
            'fee' => $fee,
            'snapshot' => [
                'driver_profile_id' => $driver->id,
                'driver_latitude' => $driver->last_latitude,
                'driver_longitude' => $driver->last_longitude,
                'pickup_latitude' => $pickupLatitude,
                'pickup_longitude' => $pickupLongitude,
                'distance_km' => $distanceKm !== null ? round($distanceKm, 3) : null,
                'free_km' => $freeKm,
                'per_km' => $perKm,
                'billable_km' => round($billableKm, 3),
                'fee' => $fee,
                'computed_at' => now()->toIso8601String(),
            ],
        ];
    }

    /**
     * Tarif de livraison selon la distance boutique → client.
     *
     * Paliers (config `beninfood.delivery_pricing`) :
     * - ≤ `flat_km`                : `min_fee` (ex. 2 km = 500) ;
     * - `flat_km` → `base_km`      : progressif jusqu'à `base_fee` (ex. 8 km = 1000) ;
     * - jusqu'à `included_km`      : `base_fee` (ex. 10 km = 1000) ;
     * - `included_km` → `discount_km` : +`per_km`/km (ex. 11 km = 1125, 12 km = 1250) ;
     * - au-delà de `discount_km`   : +`discounted_per_km`/km (tarif réduit).
     */
    public function feeForDistance(float $distanceKm): int
    {
        $minimumFee = app(PlatformPricingSettings::class)->get('order_minimum_fee');
        $distanceRule = $this->distanceRuleQuote($distanceKm);

        if ($distanceRule !== null) {
            return max($minimumFee, $distanceRule['fee']);
        }

        // Compatibilité avant le premier lancement du seeder des barèmes.
        return $this->legacyFeeForDistance($distanceKm, $minimumFee);
    }

    /** @return array{fee: int, snapshot: array<string, mixed>}|null */
    private function distanceRuleQuote(float $distanceKm): ?array
    {
        $rules = DistancePricingRule::query()
            ->where('service_type', DistancePricingRule::ORDER_DELIVERY)
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
                        'fee' => $discountedFee,
                        'snapshot' => [
                            'rule_id' => $rule->id,
                            'from_km' => $previousMaxKm,
                            'max_km' => $rule->max_km,
                            'base_fee' => (int) $rule->base_fee,
                            'per_km' => (int) $rule->per_km,
                            'discount_percentage' => (int) $rule->discount_percentage,
                            'raw_fee' => $rawFee,
                            'discounted_fee' => $discountedFee,
                        ],
                    ];
                }

                $previousMaxKm = (float) $rule->max_km;
            }
        }

        return null;
    }

    private function legacyFeeForDistance(float $distanceKm, int $minimumFee): int
    {
        $config = config('beninfood.delivery_pricing');

        $minFee = (int) $config['min_fee'];
        $baseFee = (int) $config['base_fee'];
        $flatKm = (float) $config['flat_km'];
        $baseKm = (float) $config['base_km'];
        $includedKm = (float) $config['included_km'];
        $perKm = (int) $config['per_km'];
        $discountKm = (float) $config['discount_km'];
        $discountedPerKm = (int) $config['discounted_per_km'];

        if ($distanceKm <= $flatKm) {
            return max($minimumFee, $minFee);
        }

        if ($distanceKm <= $baseKm) {
            $span = max($baseKm - $flatKm, 0.0001);
            $ratio = ($distanceKm - $flatKm) / $span;

            return max($minimumFee, (int) round($minFee + ($baseFee - $minFee) * $ratio));
        }

        if ($distanceKm <= $includedKm) {
            return max($minimumFee, $baseFee);
        }

        if ($distanceKm <= $discountKm) {
            return max($minimumFee, $baseFee + (int) round($perKm * ($distanceKm - $includedKm)));
        }

        $feeAtDiscountKm = $baseFee + $perKm * ($discountKm - $includedKm);

        return max($minimumFee, (int) round($feeAtDiscountKm + $discountedPerKm * ($distanceKm - $discountKm)));
    }

    /**
     * Tarif applicable : surcharge vendeur prioritaire, sinon tarif par défaut.
     */
    public function rateForZone(DeliveryZone $zone, ?string $vendorId = null): ?DeliveryRate
    {
        $vendorRate = $vendorId !== null
            ? $zone->rates()->where('vendor_id', $vendorId)->get()->first(fn (DeliveryRate $rate) => $rate->isEffectiveAt())
            : null;

        if ($vendorRate !== null) {
            return $vendorRate;
        }

        return $zone->rates()->whereNull('vendor_id')->get()->first(fn (DeliveryRate $rate) => $rate->isEffectiveAt());
    }

    /**
     * J75 — Snapshot sérialisable du tarif appliqué, à stocker sur la commande.
     *
     * @return array<string, mixed>
     */
    public function snapshotForOrder(array $quote): array
    {
        $rate = $quote['rate'];
        $zone = $quote['zone'];

        return [
            'zone_id' => $zone->id,
            'zone_name' => $zone->name,
            'zone_city' => $zone->city,
            'identification_mode' => $zone->identification_mode->value,
            'rate_id' => $rate?->id,
            'vendor_id' => $rate?->vendor_id,
            'price' => $rate?->price,
            'is_vendor_specific' => $rate?->vendor_id !== null,
            'effective_from' => $rate?->effective_from?->toIso8601String(),
            'effective_to' => $rate?->effective_to?->toIso8601String(),
            'delivery_fee' => (int) $quote['delivery_fee'],
            'distance_km' => ($quote['distance_km'] ?? null) !== null
                ? round($quote['distance_km'], 2)
                : null,
            'distance_pricing_rule' => $quote['distance_pricing_rule'] ?? null,
            'computed_at' => now()->toIso8601String(),
        ];
    }

    /**
     * Tente d'attacher (si possible) la zone résolue à une adresse client.
     */
    public function resolveZoneId(array $address): ?string
    {
        return $this->resolveZone($address)?->id;
    }

    /**
     * Score total de correspondance d'une zone avec l'adresse (0 = pas de match).
     */
    private function matchScore(DeliveryZone $zone, array $address): int
    {
        return array_sum($this->scoreBreakdown($zone, $address));
    }

    /**
     * Décomposition du score d'une zone : par nom, termes ou distance.
     *
     * @return array{name: int, terms: int, distance: int}
     */
    private function scoreBreakdown(DeliveryZone $zone, array $address): array
    {
        $mode = $zone->identification_mode->value;

        $nameScore = 0;
        $termsScore = 0;
        $distanceScore = 0;

        // Mode "zone" : match sur le nom de zone (dans la ville).
        if (in_array($mode, ['zone', 'combination'], true)) {
            $city = $address['city'] ?? null;
            $addressText = $address['address_text'] ?? '';

            if ($city !== null && Str::lower($city) === Str::lower((string) $zone->city)) {
                $nameScore = 2;
            } elseif (Str::lower($zone->name) !== '' && Str::contains(Str::lower($addressText), Str::lower($zone->name))) {
                $nameScore = 1;
            }
        }

        // Modes "quarter"/"sector"/"combination" : match sur les termes.
        if (in_array($mode, ['quarter', 'sector', 'combination'], true)) {
            $terms = is_array($zone->terms) ? $zone->terms : [];

            if ($terms !== []) {
                foreach ($terms as $term) {
                    $term = Str::lower(trim((string) $term));

                    if ($term === '') {
                        continue;
                    }

                    $haystack = Str::lower((string) ($address['area'] ?? '').' '.($address['address_text'] ?? ''));

                    if ($haystack !== '' && Str::contains($haystack, $term)) {
                        $termsScore += 3;
                    }
                }
            }
        }

        // Mode "distance"/"combination" : ray autour du point central.
        if (in_array($mode, ['distance', 'combination'], true)) {
            $distanceKm = $this->distanceKm(
                $address['latitude'] ?? null,
                $address['longitude'] ?? null,
                $zone->center_latitude,
                $zone->center_longitude,
            );

            if ($distanceKm !== null && $zone->radius_km !== null && $distanceKm <= (float) $zone->radius_km) {
                $distanceScore = 5;
            }
        }

        return ['name' => $nameScore, 'terms' => $termsScore, 'distance' => $distanceScore];
    }

    /**
     * Distance en km entre deux points (haversine). null si coordonnées absentes.
     */
    public function distanceKm(mixed $lat1, mixed $lng1, mixed $lat2, mixed $lng2): ?float
    {
        if ($lat1 === null || $lng1 === null || $lat2 === null || $lng2 === null) {
            return null;
        }

        $latFrom = deg2rad((float) $lat1);
        $lngFrom = deg2rad((float) $lng1);
        $latTo = deg2rad((float) $lat2);
        $lngTo = deg2rad((float) $lng2);

        $dLat = $latTo - $latFrom;
        $dLng = $lngTo - $lngFrom;

        $a = sin($dLat / 2) ** 2 + cos($latFrom) * cos($latTo) * sin($dLng / 2) ** 2;

        return self::EARTH_RADIUS_KM * 2 * asin(sqrt($a));
    }
}
