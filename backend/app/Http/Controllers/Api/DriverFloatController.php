<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DriverProfile;
use App\Services\CashService;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Flottant prépayé du livreur pour les commandes payées en espèces
 * (cahier de conception v1.0).
 */
class DriverFloatController extends Controller
{
    public function __construct(private readonly CashService $cash) {}

    public function show(Request $request): JsonResponse
    {
        $driver = $this->driver($request);

        $profile = ($driver?->prepaid_balance ?? 0) ? $driver : null;
        $balance = (int) ($driver?->prepaid_balance ?? 0);

        $offers = $request->get('for_total')
            ? ['covered' => $balance >= (int) $request->integer('for_total')]
            : null;

        return Api::ok([
            'prepaid_balance' => $balance,
            'currency' => config('beninfood.currency', 'XOF'),
            'coverage' => $offers,
            'transactions' => $profile
                ? $this->cash->history($profile)->map(fn ($t) => [
                    'id' => $t->id,
                    'type' => $t->type,
                    'amount' => $t->amount,
                    'description' => $t->description,
                    'reference_type' => $t->reference_type,
                    'reference_id' => $t->reference_id,
                    'created_at' => $t->created_at?->toIso8601String(),
                ])->values()
                : [],
        ]);
    }

    public function topUp(Request $request): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:100', 'max:1000000'],
        ]);

        $driver = $this->driver($request);
        if ($driver === null) {
            return Api::error('Profil livreur introuvable.', 'not_found', 404);
        }

        $driver = $this->cash->topUp($driver, (int) $data['amount'], $request->user()->id);

        return Api::ok([
            'prepaid_balance' => (int) $driver->prepaid_balance,
            'currency' => config('beninfood.currency', 'XOF'),
        ]);
    }

    private function driver(Request $request): ?DriverProfile
    {
        return $request->user()->driverProfile ?? null;
    }
}
