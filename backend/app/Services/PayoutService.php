<?php

namespace App\Services;

use App\Enums\PayoutBatchStatus;
use App\Enums\PayoutStatus;
use App\Exceptions\DomainException;
use App\Models\DriverProfile;
use App\Models\Payout;
use App\Models\PayoutBatch;
use App\Models\Vendor;
use App\Services\Payments\PaymentGateway;
use App\Support\Phone;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Retraits des wallets (cahier de conception v1.0, J21 §8).
 *
 * Le solde disponible est débité au moment de la demande (mise de côté) puis
 * le virement est exécuté vers le Mobile Money du vendeur/livreur — via FedaPay
 * lorsque la passerelle est configurée, sinon manuellement en back-office.
 */
class PayoutService
{
    /** Réseaux Mobile Money Bénin acceptés par FedaPay. */
    public const NETWORKS = ['mtn_open', 'moov', 'sbin'];

    public function __construct(
        private readonly FinanceService $finance,
        private readonly PaymentGateway $gateway,
    ) {}

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

        $network = $this->resolveNetwork($owner, $method);
        $destination = $this->resolveDestination($owner, $details);

        return DB::transaction(function () use ($wallet, $amount, $network, $destination): Payout {
            $payout = Payout::create([
                'wallet_id' => $wallet->id,
                'amount' => $amount,
                'method' => $network,
                'destination' => $destination,
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

    /**
     * Envoie le retrait vers la passerelle (FedaPay) puis marque le statut.
     *
     * Sans passerelle configurée (ou sans destinataire), on retombe sur la
     * validation manuelle afin de ne jamais bloquer le back-office.
     */
    public function sendToGateway(Payout $payout, ?string $actorId = null): Payout
    {
        if ($payout->status === PayoutStatus::Executed) {
            return $payout->fresh();
        }

        if (! $this->gateway->configured() || ! $payout->destination) {
            return $this->execute($payout, $actorId);
        }

        if (! Phone::isValid((string) $payout->destination)) {
            return $this->fail($payout, 'Numéro Mobile Money du bénéficiaire invalide.');
        }

        $result = $this->gateway->sendPayout($payout, Phone::normalize((string) $payout->destination), (string) $payout->method);

        if ($result['ok'] ?? false) {
            return $this->execute($payout, $actorId, $result['payout_id'] ?? $result['reference'] ?? null);
        }

        return $this->fail($payout, $result['message'] ?? 'Échec du virement FedaPay.');
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

    private function resolveNetwork(Model $owner, ?string $method): string
    {
        $candidates = [$method];

        if ($owner instanceof Vendor) {
            $candidates[] = $owner->settings?->payout_method;
        }

        foreach ($candidates as $candidate) {
            if (is_string($candidate) && in_array($candidate, self::NETWORKS, true)) {
                return $candidate;
            }
        }

        return (string) config('fedapay.default_payout_mode', 'mtn_open');
    }

    private function resolveDestination(Model $owner, ?string $details): ?string
    {
        if (is_string($details) && trim($details) !== '') {
            return trim($details);
        }

        if ($owner instanceof Vendor) {
            return $owner->phone ?: null;
        }

        if ($owner instanceof DriverProfile) {
            return $owner->user?->phone ?: null;
        }

        return null;
    }

    // ------------------------------------------------------------------- B
    // Retraits groupés (Mode B) : l'admin regroupe des demandes en attente
    // dans un lot puis exécute l'ensemble en une seule opération.

    /**
     * Regroupe des retraits en attente dans un lot (Mode B).
     *
     * @param  array<int, string>  $payoutIds
     */
    public function createBatch(array $payoutIds, ?string $actorId = null, ?string $label = null): PayoutBatch
    {
        if ($payoutIds === []) {
            throw new DomainException('payout_batch.empty', 'Sélectionnez au moins un retrait.', 422);
        }

        $payouts = Payout::whereIn('id', $payoutIds)->get();

        if ($payouts->count() !== count(array_unique($payoutIds))) {
            throw new DomainException('payout_batch.invalid', 'Certains retraits sélectionnés sont introuvables.', 422);
        }

        foreach ($payouts as $payout) {
            if ($payout->status !== PayoutStatus::Pending) {
                throw new DomainException('payout_batch.not_pending', 'Un retrait sélectionné n\'est plus en attente.', 409);
            }
        }

        return DB::transaction(function () use ($payouts, $actorId, $label): PayoutBatch {
            $batch = PayoutBatch::create([
                'reference' => 'BATCH-'.Str::upper(Str::random(10)),
                'label' => $label,
                'status' => PayoutBatchStatus::Processing->value,
                'total_amount' => (int) $payouts->sum('amount'),
                'payouts_count' => $payouts->count(),
                'created_by' => $actorId,
            ]);

            foreach ($payouts as $payout) {
                $payout->update([
                    'batch_id' => $batch->id,
                    'status' => PayoutStatus::Processing->value,
                ]);
            }

            return $batch->fresh('payouts');
        });
    }

    /**
     * Exécute tous les retraits d'un lot (Mode B) : chacun est marqué versé
     * d'un coup et le lot passe à executed (ou partially_failed).
     */
    public function executeBatch(PayoutBatch $batch, ?string $actorId = null, ?string $gatewayRef = null): PayoutBatch
    {
        if ($batch->status === PayoutBatchStatus::Executed) {
            return $batch->fresh('payouts');
        }

        $affected = 0;

        return DB::transaction(function () use ($batch, $actorId, $gatewayRef, &$affected): PayoutBatch {
            foreach ($batch->payouts as $payout) {
                if (in_array($payout->status, [PayoutStatus::Pending, PayoutStatus::Processing], true)) {
                    $this->execute($payout, $actorId, $gatewayRef);
                    $affected++;
                }
            }

            $batch->refresh();

            $executedCount = $batch->payouts()->where('status', PayoutStatus::Executed->value)->count();
            $failedCount = $batch->payouts()->where('status', PayoutStatus::Failed->value)->count();

            $batch->update([
                'executed_count' => $executedCount,
                'failed_count' => $failedCount,
                'status' => $this->resolveBatchStatus($executedCount, $failedCount, $batch->payouts_count),
                'gateway_ref' => $gatewayRef,
                'executed_at' => now(),
            ]);

            return $batch->fresh('payouts');
        });
    }

    /** Marque un retrait d'un lot en échec : le montant est re-crédité. */
    public function failBatchPayout(PayoutBatch $batch, Payout $payout, ?string $reason = null, ?string $actorId = null): Payout
    {
        $payout->refresh();

        if ($payout->batch_id !== $batch->id) {
            throw new DomainException('payout_batch.mismatch', 'Ce retrait ne fait pas partie du lot.', 409);
        }

        $payout = $this->fail($payout, $reason);

        if ($reason !== null) {
            $payout->update(['failed_reason' => $reason]);
        }

        $batch->refresh();

        $executedCount = $batch->payouts()->where('status', PayoutStatus::Executed->value)->count();
        $failedCount = $batch->payouts()->where('status', PayoutStatus::Failed->value)->count();

        $batch->update([
            'executed_count' => $executedCount,
            'failed_count' => $failedCount,
            'status' => $this->resolveBatchStatus($executedCount, $failedCount, $batch->payouts_count),
        ]);

        return $payout->fresh();
    }

    private function resolveBatchStatus(int $executedCount, int $failedCount, int $total): string
    {
        if ($failedCount === $total && $total > 0) {
            return PayoutBatchStatus::Failed->value;
        }

        if ($executedCount > 0 && $failedCount > 0 && $executedCount + $failedCount >= $total) {
            return PayoutBatchStatus::PartiallyFailed->value;
        }

        if ($executedCount === $total && $total > 0) {
            return PayoutBatchStatus::Executed->value;
        }

        return PayoutBatchStatus::Processing->value;
    }
}
