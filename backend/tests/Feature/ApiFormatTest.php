<?php

namespace Tests\Feature;

use App\Support\Api;
use Tests\TestCase;

class ApiFormatTest extends TestCase
{
    public function test_ok_payload_with_meta(): void
    {
        $response = Api::ok(['id' => 1], ['page' => 1]);

        $this->assertSame(200, $response->getStatusCode());
        $this->assertSame(['data' => ['id' => 1], 'meta' => ['page' => 1]], $response->getData(true));
    }

    public function test_created_returns_201(): void
    {
        $this->assertSame(201, Api::created(['id' => 1])->getStatusCode());
    }

    public function test_error_envelope_is_standardized(): void
    {
        $response = Api::error('Erreur interne.', 'server_error', 500);

        $this->assertSame(500, $response->getStatusCode());
        $this->assertSame(
            ['errors' => [['code' => 'server_error', 'message' => 'Erreur interne.', 'field' => null]]],
            $response->getData(true),
        );
    }

    public function test_validation_errors_are_mapped_with_fields(): void
    {
        $response = Api::error('La validation a échoué.', 'validation_error', 422, [
            'email' => ['Le champ email est requis.'],
        ]);

        $errors = $response->getData(true)['errors'];
        $this->assertSame('validation_error.email', $errors[0]['code']);
        $this->assertSame('email', $errors[0]['field']);
    }
}
