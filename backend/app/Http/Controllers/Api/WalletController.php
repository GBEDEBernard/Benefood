<?php

namespace App\Http\Controllers\Api;

use App\Enums\PayoutStatus;
use App\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Models\DriverProfile;
use App\Models\Payout;
use App\Models\Vendor;
use App\Models\Wallet;
use App\Services\FinanceService;
use App\Services\PayoutService;
use App\Services\PlatformPricingSettings;
use App\Support\Api;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Wallets & retraits (cahier de conception v1.0) — vendeur et livreur.
 */
class WalletController extends Controller
{
    public function __construct(
        private readonly FinanceService $finance,
        private readonly PayoutService $payouts,
    ) {}

    // --------------------------------------------------------------- Vendeur

    public function vendorWallet(Request $request): JsonResponse
    {
        $vendor = $this->vendorFor($request);

        return Api::ok($this->summary($this->finance->walletFor($vendor), $vendor->phone));
    }

    public function vendorPayouts(Request $request): JsonResponse
    {
        $vendor = $this->vendorFor($request);

        return Api::ok($this->payoutsFor($this->finance->walletFor($vendor)));
    }

    public function requestVendorPayout(Request $request): JsonResponse
    {
        $vendor = $this->vendorFor($request);

        $data = $this->validatePayout($request);

        $payout = $this->payouts->request(
            $vendor,
            (int) $data['amount'],
            $data['method'] ?? null,
            $data['destination'] ?? null,
        );

        return Api::created($this->payoutPayload($payout));
    }

    // --------------------------------------------------------------- Livreur

    public function driverWallet(Request $request): JsonResponse
    {
        $driver = $this->driverFor($request);

        return Api::ok($this->summary($this->finance->walletFor($driver), $driver->user?->phone, true));
    }

    public function driverPayouts(Request $request): JsonResponse
    {
        $driver = $this->driverFor($request);

        return Api::ok($this->payoutsFor($this->finance->walletFor($driver)));
    }

    public function requestDriverPayout(Request $request): JsonResponse
    {
        $driver = $this->driverFor($request);

        $data = $this->validatePayout($request);

        $payout = $this->payouts->request(
            $driver,
            (int) $data['amount'],
            $data['method'] ?? null,
            $data['destination'] ?? null,
        );

        return Api::created($this->payoutPayload($payout));
    }

    // --------------------------------------------------------------- Helpers

    /**
     * @return array<string, mixed>
     */
    private function validatePayout(Request $request): array
    {
        return $request->validate([
            'amount' => ['required', 'integer', 'min:1'],
            'method' => ['sometimes', 'nullable', 'string', 'in:'.implode(',', PayoutService::NETWORKS)],
            'destination' => ['sometimes', 'nullable', 'string', 'max:40', 'regex:/^(?:\+?229)?0?\d{8}$/'],
        ]);
    }

    // --------------------------------------------------------------- Helpers

    private function vendorFor(Request $request): Vendor
    {
        $vendor = $request->user()->vendor()->first();

        if ($vendor === null) {
            throw new DomainException('wallet.no_vendor_profile', 'Aucun profil vendeur associé à ce compte.', 404);
        }

        return $vendor;
    }

    private function driverFor(Request $request): DriverProfile
    {
        $driver = DriverProfile::query()->where('user_id', $request->user()->id)->first();

        if ($driver === null) {
            throw new DomainException('wallet.no_driver_profile', 'Profil livreur introuvable.', 404);
        }

        return $driver;
    }

    /** @return array<string, mixed> */
    private function summary(Wallet $wallet, ?string $phone = null, bool $withCommissions = false): array
    {
        $payouts = $wallet->payouts();

        $withdrawn = (int) (clone $payouts)
            ->where('status', PayoutStatus::Executed->value)
            ->sum('amount');

        $pendingPayouts = (int) (clone $payouts)
            ->whereIn('status', [
                PayoutStatus::Pending->value,
                PayoutStatus::Processing->value,
            ])
            ->sum('amount');

        $payload = [
            'pending_balance' => (int) $wallet->pending_balance,
            'available_balance' => (int) $wallet->available_balance,
            'balance' => (int) $wallet->balance,
            // Gains réellement crédités au wallet (net de commissions et de
            // retraits), y compris ceux déjà versés ou en cours de retrait.
            'earnings_total' => (int) $wallet->pending_balance
                + (int) $wallet->available_balance
                + $withdrawn
                + $pendingPayouts,
            'withdrawn_total' => $withdrawn,
            'pending_payout_total' => $pendingPayouts,
            'currency' => config('beninfood.currency', 'XOF'),
            'min_payout' => app(PlatformPricingSettings::class)->get('minimum_payout'),
            'phone' => $phone,
            'transactions' => $wallet->transactions()
                ->orderByDesc('created_at')
                ->limit(50)
                ->get()
                ->map(fn ($transaction) => [
                    'id' => $transaction->id,
                    'type' => $transaction->type->value,
                    'amount' => (int) $transaction->amount,
                    'description' => $transaction->description,
                    'balance_after' => (int) $transaction->balance_after,
                    'created_at' => $transaction->created_at?->toIso8601String(),
                ])->values(),
        ];

        if ($withCommissions) {
            $commissions = $wallet->transactions()
                ->where('reference_type', 'driver_commission')
                ->where('type', 'debit');

            $payload['commission_rate'] = app(PlatformPricingSettings::class)->get('delivery_commission_rate');
            $payload['commission_total'] = (int) (clone $commissions)->sum('amount');
            $payload['commission_count'] = (int) (clone $commissions)->distinct()->count('reference_id');
        }

        return $payload;
    }

    /** @return list<array<string, mixed>> */
    private function payoutsFor(Wallet $wallet): array
    {
        return $wallet->payouts()
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (Payout $payout) => $this->payoutPayload($payout))
            ->values()
            ->all();
    }

    /** @return array<string, mixed> */
    private function payoutPayload(Payout $payout): array
    {
        return [
            'id' => $payout->id,
            'amount' => (int) $payout->amount,
            'method' => $payout->method,
            'destination' => $payout->destination,
            'status' => $payout->status->value,
            'failed_reason' => $payout->failed_reason,
            'gateway_ref' => $payout->gateway_ref,
            'executed_at' => $payout->executed_at?->toIso8601String(),
            'created_at' => $payout->created_at?->toIso8601String(),
        ];
    }
}
