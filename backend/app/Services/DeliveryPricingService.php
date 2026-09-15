<?php

namespace App\Services;

use App\Exceptions\DomainException;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
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
     * Calcule les frais de livraison pour une zone donnée.
     *
     * @return array{zone: DeliveryZone, rate: DeliveryRate, delivery_fee: int}
     */
    public function quoteForVendor(Vendor $vendor, array $address): array
    {
        $zone = $this->resolveZone($address);

        if ($zone === null) {
            throw new DomainException('delivery.zone_not_found', 'Aucune zone de livraison ne correspond à cette adresse.', 422);
        }

        $rate = $this->rateForZone($zone, $vendor->id);

        if ($rate === null) {
            throw new DomainException('delivery.rate_not_configured', 'Aucun tarif de livraison n\'est configuré pour cette zone.', 422);
        }

        return [
            'zone' => $zone,
            'rate' => $rate,
            'delivery_fee' => (int) $rate->price,
        ];
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
            'rate_id' => $rate->id,
            'vendor_id' => $rate->vendor_id,
            'price' => $rate->price,
            'is_vendor_specific' => $rate->vendor_id !== null,
            'effective_from' => $rate->effective_from?->toIso8601String(),
            'effective_to' => $rate->effective_to?->toIso8601String(),
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
     * Score de correspondance d'une zone avec l'adresse (0 = pas de match).
     */
    private function matchScore(DeliveryZone $zone, array $address): int
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

        return $nameScore + $termsScore + $distanceScore;
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
