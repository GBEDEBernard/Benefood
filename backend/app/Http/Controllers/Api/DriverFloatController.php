<?php

namespace App\Http\Controllers\Api;

use App\Enums\PaymentStatus;
use App\Http\Controllers\Controller;
use App\Models\DriverProfile;
use App\Models\Payment;
use App\Services\CashService;
use App\Services\Payments\PaymentGateway;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * Flottant prépayé du livreur pour les commandes payées en espèces
 * (cahier de conception v1.0).
 */
class DriverFloatController extends Controller
{
    public function __construct(
        private readonly CashService $cash,
        private readonly PaymentGateway $gateway,
    ) {}

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

        $currency = (string) config('beninfood.currency', 'XOF');
        $amount = (int) $data['amount'];

        if (! $this->gateway->configured()) {
            $driver = $this->cash->topUp($driver, $amount, $request->user()->id, 'float_topup');

            return Api::ok([
                'status' => 'credited',
                'prepaid_balance' => (int) $driver->prepaid_balance,
                'amount' => $amount,
                'currency' => $currency,
            ]);
        }

        $payment = Payment::create([
            'reference' => 'FLOAT-'.Str::upper(Str::random(10)),
            'gateway' => 'fedapay',
            'amount' => $amount,
            'currency' => $currency,
            'status' => PaymentStatus::Initiated->value,
        ]);

        $payload = $this->gateway->createFloatTopUp($driver, $payment);

        if (($payload['status'] ?? null) === 'failed') {
            $payment->update(['status' => PaymentStatus::Failed->value, 'payload' => $payload]);

            return Api::error(
                (string) ($payload['message'] ?? 'La recharge n\'a pas pu être préparée. Réessayez.'),
                'payment.gateway_error',
                422,
            );
        }

        $payment->update([
            'gateway_txn_id' => $payload['transaction_id'] ?? null,
            'payload' => $payload,
        ]);

        return Api::ok($payload + [
            'status' => $payload['status'] ?? 'pending',
            'payment_id' => $payment->id,
            'prepaid_balance' => (int) $driver->prepaid_balance,
            'currency' => $currency,
        ]);
    }

    private function driver(Request $request): ?DriverProfile
    {
        return $request->user()->driverProfile ?? null;
    }
}
