<?php

namespace App\Support;

use App\Exceptions\DomainException;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\MethodNotAllowedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\ThrottleRequestsException;
use Throwable;

/**
 * Enveloppe de réponse API standardisée (J31).
 */
final class Api
{
    public static function ok(mixed $data = null, array $meta = [], int $status = 200): JsonResponse
    {
        return response()->json(self::payload($data, $meta), $status);
    }

    public static function created(mixed $data = null, array $meta = []): JsonResponse
    {
        return self::ok($data, $meta, 201);
    }

    public static function accepted(mixed $data = null, array $meta = []): JsonResponse
    {
        return self::ok($data, $meta, 202);
    }

    public static function noContent(): JsonResponse
    {
        return response()->json(null, 204);
    }

    /**
     * Renvoie une erreur au format {@errors: [{code, message, field}]}.
     *
     * @param  array<string, string|array<int, string>>  $fields
     */
    public static function error(
        string $message,
        string $code = 'error',
        int $status = 400,
        array $fields = [],
    ): JsonResponse {
        $errors = [];

        if ($fields !== []) {
            foreach ($fields as $field => $messages) {
                foreach ((array) $messages as $messageItem) {
                    $errors[] = [
                        'code' => "{$code}.{$field}",
                        'message' => (string) $messageItem,
                        'field' => $field,
                    ];
                }
            }
        } else {
            $errors[] = [
                'code' => $code,
                'message' => $message,
                'field' => null,
            ];
        }

        return response()->json(['errors' => $errors], $status);
    }

    public static function renderException(Throwable $e): JsonResponse
    {
        if ($e instanceof DomainException) {
            return self::error($e->getMessage(), $e->errorCode, $e->status);
        }

        if ($e instanceof ValidationException) {
            return self::error('La validation a échoué.', 'validation_error', 422, $e->errors());
        }

        if ($e instanceof AuthenticationException) {
            return self::error('Vous devez être authentifié.', 'unauthenticated', 401);
        }

        if ($e instanceof AuthorizationException) {
            return self::error('Accès refusé.', 'forbidden', 403);
        }

        if ($e instanceof AccessDeniedHttpException) {
            return self::error('Accès refusé.', 'forbidden', 403);
        }

        if ($e instanceof NotFoundHttpException) {
            return self::error('Ressource introuvable.', 'not_found', 404);
        }

        if ($e instanceof MethodNotAllowedHttpException) {
            return self::error('Méthode non autorisée.', 'method_not_allowed', 405);
        }

        if ($e instanceof ThrottleRequestsException) {
            return self::error('Trop de requêtes, veuillez réessayer plus tard.', 'too_many_requests', 429);
        }

        if ($e instanceof HttpExceptionInterface) {
            if ($e->getStatusCode() === 429) {
                return self::error('Trop de requêtes, veuillez réessayer plus tard.', 'too_many_requests', 429);
            }

            $message = $e->getMessage() ?: 'Erreur.';

            return self::error($message, 'http_error', $e->getStatusCode());
        }

        $status = 500;
        $message = 'Une erreur interne est survenue.';

        if (config('app.debug')) {
            $message .= ' '.$e->getMessage();
        }

        return self::error($message, 'server_error', $status);
    }

    /**
     * Construit l'enveloppe succès {@data: ..., meta: ...}.
     */
    public static function payload(mixed $data = null, array $meta = []): array
    {
        $payload = ['data' => $data];

        if ($meta !== []) {
            $payload['meta'] = $meta;
        }

        return $payload;
    }
}
