<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class RateLimitTest extends TestCase
{
    public function test_auth_endpoints_are_throttled(): void
    {
        Route::post('/api/v1/__rate_limit_test__', fn () => response()->json(['ok' => true]))
            ->middleware('throttle:auth');

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/__rate_limit_test__')->assertOk();
        }

        $this->postJson('/api/v1/__rate_limit_test__')
            ->assertStatus(429)
            ->assertJsonStructure(['errors' => [['code', 'message', 'field']]])
            ->assertJsonPath('errors.0.code', 'too_many_requests');
    }
}
