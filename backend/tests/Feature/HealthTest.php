<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class HealthTest extends TestCase
{
    use RefreshDatabase;

    public function test_health_endpoint_returns_ok(): void
    {
        $this->getJson('/api/v1/health')
            ->assertOk()
            ->assertHeader('X-Request-Id')
            ->assertJsonStructure([
                'data' => ['status', 'service', 'version', 'env', 'db', 'cache', 'queue', 'time'],
            ])
            ->assertJsonPath('data.status', 'ok')
            ->assertJsonPath('data.service', 'beninfood-api')
            ->assertJsonPath('data.db', true);
    }
}
