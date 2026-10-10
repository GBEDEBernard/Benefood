<?php

namespace App\Services;

use App\Enums\PayoutStatus;
use App\Exceptions\DomainException;
use App\Models\Payout;
use App\Models\Vendor;
use App\Models\Wallet;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

/**
 * Retraits des wallets (cahier de conception v1.0, J21 §8).
 *
 * Le solde disponible est débité au moment de la demande (mise de côté) puis
 * le virement est exécuté vers le Mobile Money du vendeur/livreur.
 */
class PayoutService
{
    public function __construct(private readonly FinanceService $finance) {}

    /**
     * Crée une demande de retrait depuis le solde disponible.
     */
    public function request(Model $owner, int $amount, ?string $method = null, ?string $details = null): Payout
    {
        $minPayout = (int) config('beninfood.wallet.min_payout', 1000);

        if ($amount < $minPayout) {
            throw new DomainException(
                'payout.below_minimum',
                'Le montant minimum de retrait est de '.$minPayout.' F CFA.',
                422,
            );
        }

        $wallet = $this->finance->walletFor($owner);

        if ($amount > $wallet->available_balance) {
            throw new DomainException('payout.insufficient_funds', 'Solde disponible insuffisant.', 422);
        }

        return DB::transaction(function () use ($wallet, $amount, $method, $details): Payout {
            $payout = Payout::create([
                'wallet_id' => $wallet->id,
                'amount' => $amount,
                'method' => $method ?? $this->defaultMethod($wallet, $details),
                'status' => PayoutStatus::Pending->value,
            ]);

            $this->finance->debitAvailable(
                $wallet,
                $amount,
                'payout_hold',
                $payout->id,
                'Demande de retrait',
            );

            return $payout;
        });
    }

    /** Exécute un retrait (validation porteuse / virement). */
    public function execute(Payout $payout, ?string $actorId = null, ?string $gatewayRef = null): Payout
    {
        if ($payout->status === PayoutStatus::Executed) {
            return $payout->fresh();
        }

        $payout->update([
            'status' => PayoutStatus::Executed->value,
            'executed_at' => now(),
            'executed_by' => $actorId,
            'gateway_ref' => $gatewayRef,
        ]);

        return $payout->fresh();
    }

    /** Marque un retrait en échec et re-crédite le solde disponible. */
    public function fail(Payout $payout, ?string $reason = null): Payout
    {
        if ($payout->status === PayoutStatus::Failed) {
            return $payout->fresh();
        }

        return DB::transaction(function () use ($payout): Payout {
            $wallet = $payout->wallet;

            if ($wallet !== null) {
                $this->finance->creditAvailable(
                    $wallet,
                    (int) $payout->amount,
                    'payout_refund',
                    $payout->id,
                    'Retrait échoué — montant re-crédité',
                );
            }

            $payout->update(['status' => PayoutStatus::Failed->value]);

            return $payout->fresh();
        });
    }

    private function defaultMethod(Wallet $wallet, ?string $details): string
    {
        $owner = $wallet->owner;

        if ($owner instanceof Vendor && $owner->settings?->payout_method !== null) {
            return $owner->settings->payout_method;
        }

        return $details !== null && $details !== '' ? 'mobile_money' : 'mobile_money';
    }
}
