<?php

namespace App\Services;

use App\Enums\JournalEntryType;
use App\Enums\WalletTransactionType;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

/**
 * Moteur financier (cahier de conception v1.0).
 *
 * Règle d'or : le client paie une seule fois vers la plateforme, puis le
 * système répartit vers les wallets internes. Les parts vendeur/livreur sont
 * d'abord créditées **en attente** (séquestre) puis libérées après livraison.
 */
class FinanceService
{
    public function __construct(private readonly FinancialJournalService $journal) {}

    /**
     * Barème en vigueur (taux en pourcentage, points de base pour la passerelle).
     *
     * @return array{service_fee_rate: int, delivery_commission_rate: int, gateway_fee_basis_points: int}
     */
    public function rates(): array
    {
        return [
            'service_fee_rate' => (int) config('beninfood.service_fee.rate', 5),
            'delivery_commission_rate' => (int) config('beninfood.delivery_commission.rate', 20),
            'gateway_fee_basis_points' => (int) config('beninfood.payment_gateway.fee_rate_basis_points', 120),
        ];
    }

    /**
     * Répartition financière d'une commande, calculée et figée côté serveur.
     *
     * @return array{
     *   subtotal:int, delivery_fee:int, service_fee:int, payment_fee:int,
     *   commission_base:int, commission_rate:int, commission_amount:int,
     *   vendor_amount:int, delivery_commission_rate:int, delivery_commission_amount:int,
     *   delivery_partner_amount:int, platform_amount:int, total_client:int
     * }
     */
    public function breakdown(int $subtotal, int $deliveryFee, int $vendorCommissionRate): array
    {
        $rates = $this->rates();

        $serviceFee = $this->percent($subtotal + $deliveryFee, $rates['service_fee_rate']);
        $totalClient = $subtotal + $deliveryFee + $serviceFee;

        $commissionAmount = $this->percent($subtotal, $vendorCommissionRate);
        $vendorAmount = $subtotal - $commissionAmount;

        $deliveryCommission = $this->percent($deliveryFee, $rates['delivery_commission_rate']);
        $deliveryPartnerAmount = $deliveryFee - $deliveryCommission;

        // Frais de passerelle : coût absorbé par la plateforme (1,2 % du payé).
        $paymentFee = (int) round($totalClient * $rates['gateway_fee_basis_points'] / 10000);

        return [
            'subtotal' => $subtotal,
            'delivery_fee' => $deliveryFee,
            'service_fee' => $serviceFee,
            'payment_fee' => $paymentFee,
            'commission_base' => $subtotal,
            'commission_rate' => $vendorCommissionRate,
            'commission_amount' => $commissionAmount,
            'vendor_amount' => $vendorAmount,
            'delivery_commission_rate' => $rates['delivery_commission_rate'],
            'delivery_commission_amount' => $deliveryCommission,
            'delivery_partner_amount' => $deliveryPartnerAmount,
            'platform_amount' => $commissionAmount + $deliveryCommission + $serviceFee,
            'total_client' => $totalClient,
        ];
    }

    // ------------------------------------------------------------------ Wallets

    /** Récupère (ou crée) le wallet d'un vendeur ou d'un livreur. */
    public function walletFor(Model $owner): Wallet
    {
        return Wallet::firstOrCreate(
            ['owner_type' => $owner->getMorphClass(), 'owner_id' => $owner->id],
            ['balance' => 0, 'pending_balance' => 0, 'available_balance' => 0],
        );
    }

    /** Crédite le séquestre (solde en attente) d'un wallet. */
    public function creditPending(Wallet $wallet, int $amount, string $refType, ?string $refId, string $description): ?WalletTransaction
    {
        if ($amount <= 0 || $this->alreadyRecorded($wallet, $refType, $refId)) {
            return null;
        }

        return DB::transaction(function () use ($wallet, $amount, $refType, $refId, $description) {
            $wallet->refresh();
            $wallet->pending_balance += $amount;
            $wallet->balance = $wallet->pending_balance + $wallet->available_balance;
            $wallet->save();

            return $this->writeTransaction($wallet, WalletTransactionType::Credit, $amount, $refType, $refId, $description);
        });
    }

    /** Libère le séquestre : en attente → disponible. */
    public function releasePending(Wallet $wallet, int $amount, string $refType, ?string $refId, string $description): ?WalletTransaction
    {
        if ($amount <= 0) {
            return null;
        }

        return DB::transaction(function () use ($wallet, $amount, $refType, $refId, $description) {
            $wallet->refresh();
            $release = min($amount, $wallet->pending_balance);
            $wallet->pending_balance -= $release;
            $wallet->available_balance += $release;
            $wallet->balance = $wallet->pending_balance + $wallet->available_balance;
            $wallet->save();

            return $this->writeTransaction($wallet, WalletTransactionType::Credit, $release, $refType, $refId, $description);
        });
    }

    /** Débite le séquestre (contre-passation d'annulation). */
    public function debitPending(Wallet $wallet, int $amount, string $refType, ?string $refId, string $description): ?WalletTransaction
    {
        if ($amount <= 0) {
            return null;
        }

        return DB::transaction(function () use ($wallet, $amount, $refType, $refId, $description) {
            $wallet->refresh();
            $debit = min($amount, $wallet->pending_balance);
            $wallet->pending_balance -= $debit;
            $wallet->balance = $wallet->pending_balance + $wallet->available_balance;
            $wallet->save();

            return $this->writeTransaction($wallet, WalletTransactionType::Debit, $debit, $refType, $refId, $description);
        });
    }

    /** Crédite le solde disponible (re-crédit après échec de retrait, etc.). */
    public function creditAvailable(Wallet $wallet, int $amount, string $refType, ?string $refId, string $description): ?WalletTransaction
    {
        if ($amount <= 0) {
            return null;
        }

        return DB::transaction(function () use ($wallet, $amount, $refType, $refId, $description) {
            $wallet->refresh();
            $wallet->available_balance += $amount;
            $wallet->balance = $wallet->pending_balance + $wallet->available_balance;
            $wallet->save();

            return $this->writeTransaction($wallet, WalletTransactionType::Credit, $amount, $refType, $refId, $description);
        });
    }

    /** Débite le solde disponible (retrait validé). */
    public function debitAvailable(Wallet $wallet, int $amount, string $refType, ?string $refId, string $description): ?WalletTransaction
    {
        if ($amount <= 0 || $amount > $wallet->available_balance) {
            return null;
        }

        return DB::transaction(function () use ($wallet, $amount, $refType, $refId, $description) {
            $wallet->refresh();
            $wallet->available_balance -= $amount;
            $wallet->balance = $wallet->pending_balance + $wallet->available_balance;
            $wallet->save();

            return $this->writeTransaction($wallet, WalletTransactionType::Debit, $amount, $refType, $refId, $description);
        });
    }

    // ------------------------------------------------------- Part livreur

    /**
     * Libère le séquestre du livreur (montant brut = prix de livraison) puis
     * prélève la commission plateforme : le disponible augmente du net. La ligne
     * de débit « Commission » apparaît dans les mouvements du wallet.
     */
    public function releaseDriverEarning(Wallet $wallet, int $gross, int $commission, string $refType, ?string $refId, string $reference): ?WalletTransaction
    {
        if ($gross <= 0) {
            return null;
        }

        return DB::transaction(function () use ($wallet, $gross, $commission, $refId, $reference) {
            $wallet->refresh();
            $release = min($gross, $wallet->pending_balance);
            $wallet->pending_balance -= $release;
            $wallet->available_balance += max(0, $release - $commission);
            $wallet->balance = $wallet->pending_balance + $wallet->available_balance;
            $wallet->save();

            return $this->recordDriverCommission($wallet, $commission, $refId, $reference);
        });
    }

    /**
     * Crédite un gain livreur sans séquestre (colis/commande espèces) : le prix
     * de livraison brut est crédité puis la commission est débitée.
     */
    public function creditDriverEarning(Wallet $wallet, int $gross, int $commission, string $refType, ?string $refId, string $reference): ?WalletTransaction
    {
        if ($gross <= 0) {
            return null;
        }

        return DB::transaction(function () use ($wallet, $gross, $commission, $refType, $refId, $reference) {
            $wallet->refresh();
            $wallet->available_balance += max(0, $gross - $commission);
            $wallet->balance = $wallet->pending_balance + $wallet->available_balance;
            $wallet->save();

            $this->writeTransaction(
                $wallet,
                WalletTransactionType::Credit,
                $gross,
                $refType,
                $refId,
                'Prix de livraison — '.$reference,
            );

            return $this->recordDriverCommission($wallet, $commission, $refId, $reference);
        });
    }

    /** Ligne de débit « Commission » prélevée au livreur (idempotent par référence). */
    private function recordDriverCommission(Wallet $wallet, int $commission, ?string $refId, string $reference): ?WalletTransaction
    {
        if ($commission <= 0 || $this->alreadyRecorded($wallet, 'driver_commission', $refId)) {
            return null;
        }

        return $this->writeTransaction(
            $wallet,
            WalletTransactionType::Debit,
            $commission,
            'driver_commission',
            $refId,
            'Commission Béninfood — '.$reference,
        );
    }

    // ------------------------------------------------------- Cycle de commande

    /**
     * Après confirmation du paiement : crédite la part vendeur en attente et
     * journalise la vente, la commission et le revenu plateforme.
     */
    public function distributeOrderPayment(Order $order): void
    {
        $order->loadMissing('financials', 'vendor');

        $financials = $order->financials;
        $vendor = $order->vendor;

        if ($financials === null || $vendor === null) {
            return;
        }

        $wallet = $this->walletFor($vendor);

        $this->creditPending(
            $wallet,
            (int) $financials->vendor_amount,
            'order_vendor_credit',
            $order->id,
            'Part vendeur (en attente) — '.$order->reference,
        );

        $this->journal->record([
            'entry_type' => JournalEntryType::Payment,
            'reference_type' => 'order',
            'reference_id' => $order->id,
            'credit' => (int) $financials->total_client,
            'participant' => $order->user_id,
            'balance_after' => (int) $financials->total_client,
            'actor' => 'system',
        ]);

        $this->journal->record([
            'entry_type' => JournalEntryType::Commission,
            'reference_type' => 'order',
            'reference_id' => $order->id,
            'credit' => (int) $financials->platform_amount,
            'debit' => (int) $financials->payment_fee,
            'participant' => null,
            'actor' => 'system',
        ]);
    }

    /**
     * À l'assignation d'un livreur : crédite sa part en attente (le livreur
     * n'est connu qu'à ce moment-là, contrairement au vendeur).
     */
    public function creditDriverForDelivery(Order $order, DriverProfile $driver): void
    {
        $order->loadMissing('financials');

        $amount = (int) ($order->financials->delivery_fee ?? 0);

        if ($amount <= 0) {
            return;
        }

        $this->creditPending(
            $this->walletFor($driver),
            $amount,
            'order_driver_credit',
            $order->id,
            'Prix de livraison (en attente) — '.$order->reference,
        );
    }

    /**
     * Après livraison : libère les séquestres vendeur et livreur.
     */
    public function releaseOrderFunds(Order $order): void
    {
        $order->loadMissing('financials', 'vendor', 'delivery.driverProfile');

        $financials = $order->financials;

        if ($financials === null) {
            return;
        }

        if ($order->vendor !== null) {
            $vendorWallet = $this->walletFor($order->vendor);

            $this->releasePending(
                $vendorWallet,
                (int) $financials->vendor_amount,
                'order_vendor_release',
                $order->id,
                'Libération part vendeur — '.$order->reference,
            );

            $this->journal->record([
                'entry_type' => JournalEntryType::Transfer,
                'reference_type' => 'order',
                'reference_id' => $order->id,
                'credit' => (int) $financials->vendor_amount,
                'participant' => $order->vendor->user_id,
                'balance_after' => (int) $vendorWallet->fresh()->available_balance,
                'actor' => 'system',
            ]);
        }

        $driver = $order->delivery?->driverProfile;

        if ($driver !== null) {
            $driverWallet = $this->walletFor($driver);

            $this->releaseDriverEarning(
                $driverWallet,
                (int) $financials->delivery_fee,
                (int) $financials->delivery_commission_amount,
                'order_driver_release',
                $order->id,
                $order->reference,
            );

            $this->journal->record([
                'entry_type' => JournalEntryType::Transfer,
                'reference_type' => 'order',
                'reference_id' => $order->id,
                'credit' => (int) $financials->delivery_partner_amount,
                'participant' => $driver->user_id,
                'balance_after' => (int) $driverWallet->fresh()->available_balance,
                'actor' => 'system',
            ]);
        }
    }

    /**
     * Annulation d'une commande payée : contre-passe les séquestres non encore
     * libérés (vendeur et, le cas échéant, livreur).
     */
    public function reverseOrderDistribution(Order $order, ?string $actor = null): void
    {
        $order->loadMissing('financials', 'vendor', 'delivery.driverProfile');

        $financials = $order->financials;

        if ($financials === null) {
            return;
        }

        if ($order->vendor !== null && $financials->vendor_amount > 0) {
            $this->debitPending(
                $this->walletFor($order->vendor),
                (int) $financials->vendor_amount,
                'order_vendor_reversal',
                $order->id,
                'Annulation part vendeur — '.$order->reference,
            );
        }

        $driver = $order->delivery?->driverProfile;

        if ($driver !== null && $financials->delivery_fee > 0) {
            $this->debitPending(
                $this->walletFor($driver),
                (int) $financials->delivery_fee,
                'order_driver_reversal',
                $order->id,
                'Annulation part livreur — '.$order->reference,
            );
        }
    }

    // ------------------------------------------------------------- Cycle colis

    /**
     * Encaissement en ligne d'un colis : journalise le paiement client et la
     * commission retenue par la plateforme (part livreur séquestrée à part).
     */
    public function recordParcelPayment(Parcel $parcel): void
    {
        $this->journal->record([
            'entry_type' => JournalEntryType::Payment,
            'reference_type' => 'parcel',
            'reference_id' => $parcel->id,
            'credit' => (int) $parcel->delivery_fee,
            'participant' => $parcel->user_id,
            'balance_after' => (int) $parcel->delivery_fee,
            'actor' => 'system',
        ]);

        if ((int) $parcel->platform_amount > 0) {
            $this->journal->record([
                'entry_type' => JournalEntryType::Commission,
                'reference_type' => 'parcel',
                'reference_id' => $parcel->id,
                'credit' => (int) $parcel->platform_amount,
                'participant' => null,
                'actor' => 'system',
            ]);
        }
    }

    /**
     * Livraison d'un colis : journalise la commission plateforme lorsqu'elle est
     * retenue en espèces (sur le flottant) et le gain livreur devenu retirable.
     */
    public function recordParcelDelivery(Parcel $parcel, DriverProfile $driver): void
    {
        if ($parcel->isCash() && (int) $parcel->platform_amount > 0) {
            $this->journal->record([
                'entry_type' => JournalEntryType::Commission,
                'reference_type' => 'parcel',
                'reference_id' => $parcel->id,
                'credit' => (int) $parcel->platform_amount,
                'participant' => null,
                'actor' => 'system',
            ]);
        }

        if ((int) $parcel->partner_amount > 0) {
            $this->journal->record([
                'entry_type' => JournalEntryType::Transfer,
                'reference_type' => 'parcel',
                'reference_id' => $parcel->id,
                'credit' => (int) $parcel->partner_amount,
                'participant' => $driver->user_id,
                'balance_after' => (int) $this->walletFor($driver)->fresh()->available_balance,
                'actor' => 'system',
            ]);
        }
    }

    /**
     * Annulation d'un colis en ligne déjà payé : contre-passe la commission
     * plateforme et la part livreur (J12 §5.1 — J14 §3.2).
     */
    public function recordParcelCancellation(Parcel $parcel, ?DriverProfile $driver, ?string $actor = null): void
    {
        if ((int) $parcel->platform_amount > 0) {
            $this->journal->record([
                'entry_type' => JournalEntryType::Reversal,
                'reference_type' => 'parcel',
                'reference_id' => $parcel->id,
                'debit' => (int) $parcel->platform_amount,
                'participant' => $parcel->user_id,
                'actor' => $actor,
            ]);
        }

        if ($driver !== null && (int) $parcel->partner_amount > 0) {
            $this->journal->record([
                'entry_type' => JournalEntryType::Reversal,
                'reference_type' => 'parcel',
                'reference_id' => $parcel->id,
                'debit' => (int) $parcel->partner_amount,
                'participant' => $driver->user_id,
                'actor' => $actor,
            ]);
        }
    }

    // ------------------------------------------------------- Cycle espèces

    /**
     * Règlement d'une commande encaissée en espèces par le livreur : journalise
     * les parts vendeur et livreur ainsi que la commission plateforme.
     */
    public function recordCashOrderSettlement(Order $order, DriverProfile $driver): void
    {
        $order->loadMissing('financials', 'vendor');

        $financials = $order->financials;

        if ($financials === null) {
            return;
        }

        if ($order->vendor !== null && (int) $financials->vendor_amount > 0) {
            $this->journal->record([
                'entry_type' => JournalEntryType::Transfer,
                'reference_type' => 'order',
                'reference_id' => $order->id,
                'credit' => (int) $financials->vendor_amount,
                'participant' => $order->vendor->user_id,
                'balance_after' => (int) $this->walletFor($order->vendor)->fresh()->available_balance,
                'actor' => 'system',
            ]);
        }

        if ((int) $financials->delivery_partner_amount > 0) {
            $this->journal->record([
                'entry_type' => JournalEntryType::Transfer,
                'reference_type' => 'order',
                'reference_id' => $order->id,
                'credit' => (int) $financials->delivery_partner_amount,
                'participant' => $driver->user_id,
                'balance_after' => (int) $this->walletFor($driver)->fresh()->available_balance,
                'actor' => 'system',
            ]);
        }

        if ((int) $financials->platform_amount > 0) {
            $this->journal->record([
                'entry_type' => JournalEntryType::Commission,
                'reference_type' => 'order',
                'reference_id' => $order->id,
                'credit' => (int) $financials->platform_amount,
                'participant' => null,
                'actor' => 'system',
            ]);
        }
    }

    // ----------------------------------------------------------------- helpers

    private function percent(int $amount, int $rate): int
    {
        return (int) round($amount * $rate / 100);
    }

    private function alreadyRecorded(Wallet $wallet, string $refType, ?string $refId): bool
    {
        return WalletTransaction::query()
            ->where('wallet_id', $wallet->id)
            ->where('reference_type', $refType)
            ->where('reference_id', $refId)
            ->exists();
    }

    private function writeTransaction(
        Wallet $wallet,
        WalletTransactionType $type,
        int $amount,
        string $refType,
        ?string $refId,
        string $description,
    ): WalletTransaction {
        return WalletTransaction::create([
            'wallet_id' => $wallet->id,
            'type' => $type->value,
            'amount' => $amount,
            'reference_type' => $refType,
            'reference_id' => $refId,
            'description' => $description,
            'balance_after' => $wallet->available_balance,
        ]);
    }
}
