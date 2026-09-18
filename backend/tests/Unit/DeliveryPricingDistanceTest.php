<?php

namespace Tests\Unit;

use App\Services\DeliveryPricingService;
use PHPUnit\Framework\TestCase;

class DeliveryPricingDistanceTest extends TestCase
{
    private DeliveryPricingService $service;

    protected function setUp(): void
    {
        parent::setUp();

        $this->service = new DeliveryPricingService;
    }

    public function test_same_point_returns_zero(): void
    {
        $this->assertSame(0.0, $this->service->distanceKm(6.37, 2.39, 6.37, 2.39));
    }

    public function test_returns_expected_distance_for_known_pair(): void
    {
        // Cotonou (centre) → un point ~2 km à l'est, calculé indépendamment.
        $this->assertSame(2.0736, round($this->service->distanceKm(6.3702932, 2.3912362, 6.3702932, 2.410), 4));
    }

    public function test_paris_to_london_about_344km(): void
    {
        $km = $this->service->distanceKm(48.8566, 2.3522, 51.5074, -0.1278);

        $this->assertSame(343.6, round($km, 1));
    }

    public function test_distance_is_symmetric(): void
    {
        $a = $this->service->distanceKm(6.3702932, 2.3912362, 9.0192, 2.2025);
        $b = $this->service->distanceKm(9.0192, 2.2025, 6.3702932, 2.3912362);

        $this->assertSame($a, $b);
    }

    public function test_null_coordinates_return_null(): void
    {
        $this->assertNull($this->service->distanceKm(null, 2.39, 6.37, 2.39));
        $this->assertNull($this->service->distanceKm(6.37, null, 6.37, 2.39));
        $this->assertNull($this->service->distanceKm(6.37, 2.39, null, 2.39));
        $this->assertNull($this->service->distanceKm(6.37, 2.39, 6.37, null));
    }
}
