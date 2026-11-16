<?php

namespace Tests\Feature;

use Tests\TestCase;

class LanguageApiTest extends TestCase
{
    public function test_languages_endpoint_lists_french_english_and_fon(): void
    {
        $this->getJson('/api/v1/languages')
            ->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('data.0.code', 'fr')
            ->assertJsonPath('data.0.is_default', true)
            ->assertJsonPath('data.1.code', 'en')
            ->assertJsonPath('data.2.code', 'fon')
            ->assertJsonPath('data.2.native_name', 'Fɔngbè');
    }
}
