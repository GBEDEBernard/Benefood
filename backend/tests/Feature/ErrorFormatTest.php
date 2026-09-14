<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ErrorFormatTest extends TestCase
{
    use RefreshDatabase;

    public function test_unknown_route_returns_404_envelope(): void
    {
        $this->getJson('/api/v1/does-not-exist')
            ->assertNotFound()
            ->assertJsonStructure(['errors' => [['code', 'message', 'field']]])
            ->assertJsonPath('errors.0.code', 'not_found');
    }

    public function test_method_not_allowed_returns_405_envelope(): void
    {
        $this->postJson('/api/v1/health')
            ->assertStatus(405)
            ->assertJsonStructure(['errors' => [['code', 'message', 'field']]])
            ->assertJsonPath('errors.0.code', 'method_not_allowed');
    }
}
