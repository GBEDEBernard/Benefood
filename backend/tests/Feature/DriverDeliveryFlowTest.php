<?php

namespace Tests\Feature;

use Tests\TestCase;

class DriverDeliveryFlowTest extends TestCase
{
    public function test_driver_delivery_endpoints_require_authentication(): void
    {
        $this->getJson('/api/v1/driver/me/deliveries')->assertUnauthorized();
        $this->getJson('/api/v1/driver/me/deliveries/offers')->assertUnauthorized();
        $this->patchJson('/api/v1/driver/me/availability/location', [
            'latitude' => 6.37,
            'longitude' => 2.39,
        ])->assertUnauthorized();
    }
}
