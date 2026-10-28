<?php

namespace App\Services;

use App\Enums\JournalEntryType;
use App\Enums\WalletTransactionType;
use App\Models\DeliveryAssignment;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\ParcelAssignment;
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
 *
 * Commissions : client sur le sous-total produits, vendeur sur le sous-total
 * de chaque vente, livreur sur les frais de livraison, colis sur les frais.
 */
class FinanceService
{
    /** Identifiant fixe du wallet interne Béninfood (commissions et frais). */
    public const PLATFORM_WALLET_ID = '00000000-0000-0000-0000-000000000001';

    public function __construct(private readonly FinancialJournalService $journal) {}

    /**
     * Barème en vigueur (taux en pourcentage, points de base pour la passerelle).
     *
     * @return array{service_fee_rate: int, delivery_commission_rate: int, gateway_fee_basis_points: int}
     */
    public function rates(): array
    {
        $settings = app(PlatformPricingSettings::class);

        return [
            'service_fee_rate' => $settings->get('service_fee_rate'),
            'delivery_commission_rate' => $settings->get('delivery_commission_rate'),
            'gateway_fee_basis_points' => $settings->get('gateway_fee_basis_points'),
        ];
    }

    /**
     * Répartition financière d'une commande, calculée et figée côté serveur.
     *
     * @return array{
     *   subtotal:int, delivery_fee:int, approach_fee:int, delivery_total:int,
     *   service_fee:int, payment_fee:int,
     *   commission_base:int, commission_rate:int, commission_amount:int,
     *   vendor_amount:int, delivery_commission_rate:int, delivery_commission_amount:int,
     *   delivery_partner_amount:int, base_partner_amount:int, approach_partner_amount:int,
     *   platform_amount:int, total_client:int
     * }
     */
    public function breakdown(int $subtotal, int $deliveryFee, int $vendorCommissionRate, int $approachFee = 0): array
    {
        $rates = $this->rates();

        $approachFee = max(0, $approachFee);
        $deliveryTotal = $deliveryFee + $approachFee;

        // Commission client : uniquement sur la valeur des produits (hors livraison).
        $serviceFee = $this->percent($subtotal, $rates['service_fee_rate']);
        $totalClient = $subtotal + $deliveryTotal + $serviceFee;

        $commissionAmount = $this->percent($subtotal, $vendorCommissionRate);
        $vendorAmount = $subtotal - $commissionAmount;

        // La commission livreur s'applique au total livraison (base + approche).
        $deliveryCommission = $this->percent($deliveryTotal, $rates['delivery_commission_rate']);
        $deliveryPartnerAmount = $deliveryTotal - $deliveryCommission;

        // Ventilation de la part livreur entre trajet de base et approche.
        $basePartnerAmount = $deliveryTotal > 0
            ? (int) round($deliveryPartnerAmount * $deliveryFee / $deliveryTotal)
            : 0;
        $approachPartnerAmount = $deliveryPartnerAmount - $basePartnerAmount;

        // Frais de passerelle : coût absorbé par la plateforme (1,2 % du payé).
        $paymentFee = (int) round($totalClient * $rates['gateway_fee_basis_points'] / 10000);

        return [
            'subtotal' => $subtotal,
            'delivery_fee' => $deliveryFee,
            'approach_fee' => $approachFee,
            'delivery_total' => $deliveryTotal,
            'service_fee' => $serviceFee,
            'payment_fee' => $paymentFee,
            'commission_base' => $subtotal,
            'commission_rate' => $vendorCommissionRate,
            'commission_amount' => $commissionAmount,
            'vendor_amount' => $vendorAmount,
            'delivery_commission_rate' => $rates['delivery_commission_rate'],
            'delivery_commission_amount' => $deliveryCommission,
            'delivery_partner_amount' => $deliveryPartnerAmount,
            'base_partner_amount' => $basePartnerAmount,
            'approach_partner_amount' => $approachPartnerAmount,
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

    /** Wallet interne Béninfood : commissions, frais de service et de livraison. */
    public function platformWallet(): Wallet
    {
        return Wallet::firstOrCreate(
            ['owner_type' => 'platform', 'owner_id' => self::PLATFORM_WALLET_ID],
            ['balance' => 0, 'pending_balance' => 0, 'available_balance' => 0],
        );
    }

    /**
     * Crédite la part plateforme (idempotent par référence) au moment de la
     * libération des fonds, c'est-à-dire après confirmation de la livraison.
     */
    public function creditPlatform(int $amount, string $refType, ?string $refId, string $description): ?WalletTransaction
    {
        if ($amount <= 0) {
            return null;
        }

        $wallet = $this->platformWallet();

        if ($this->alreadyRecorded($wallet, $refType, $refId)) {
            return null;
        }

        return $this->creditAvailable($wallet, $amount, $refType, $refId, $description);
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

    /** Journalise l'encaissement d'un supplément d'approche payé en ligne. */
    public function recordApproachPayment(Order $order, int $amount): void
    {
        if ($amount <= 0) {
            return;
        }

        $this->journal->record([
            'entry_type' => JournalEntryType::Payment,
            'reference_type' => 'order',
            'reference_id' => $order->id,
            'credit' => $amount,
            'participant' => $order->user_id,
            'balance_after' => $amount,
            'actor' => 'system',
        ]);
    }

    /**
     * À l'assignation d'un livreur : crédite sa part en attente (le livreur
     * n'est connu qu'à ce moment-là, contrairement au vendeur).
     */
    public function creditDriverForDelivery(Order $order, DriverProfile $driver): void
    {
        $order->loadMissing('financials', 'delivery.assignments');

        $assignment = $order->delivery?->assignments
            ?->first(fn (DeliveryAssignment $item) => $item->driver_profile_id === $driver->id
                && in_array($item->status, [DeliveryAssignment::STATUS_ACTIVE, DeliveryAssignment::STATUS_PENDING_HANDOVER], true));

        $amount = (int) ($assignment?->gross_amount
            ?? $order->financials?->delivery_total
            ?? $order->financials?->delivery_fee
            ?? 0);

        if ($amount <= 0) {
            return;
        }

        $this->creditPending(
            $this->walletFor($driver),
            $amount,
            'order_driver_credit',
            $assignment?->id ?? $order->id,
            'Prix de livraison (en attente) — '.$order->reference,
        );
    }

    /**
     * Après livraison : libère les séquestres vendeur et livreur.
     */
    public function releaseOrderFunds(Order $order): void
    {
        $order->loadMissing('financials', 'vendor', 'delivery.assignments.driverProfile', 'delivery.driverProfile');

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

        $this->releaseDriverAssignments($order);

        $this->creditPlatform(
            (int) $financials->platform_amount,
            'order_platform_credit',
            $order->id,
            'Commissions et frais plateforme — '.$order->reference,
        );
    }

    /**
     * Libère le séquestre de chaque segment de livraison (livreur initial et
     * remplaçants). Chaque segment porte sa propre commission, calculée au
     * prorata de sa part livreur.
     */
    public function releaseDriverAssignments(Order $order): void
    {
        $order->loadMissing('financials', 'delivery.assignments.driverProfile', 'delivery.driverProfile');

        $financials = $order->financials;
        $delivery = $order->delivery;

        if ($financials === null) {
            return;
        }

        $assignments = $delivery?->assignments ?? collect();

        if ($assignments->isNotEmpty()) {
            foreach ($assignments as $assignment) {
                $driver = $assignment->driverProfile;

                if ($driver === null || (int) $assignment->gross_amount <= 0) {
                    continue;
                }

                $driverWallet = $this->walletFor($driver);

                $this->releaseDriverEarning(
                    $driverWallet,
                    (int) $assignment->gross_amount,
                    (int) $assignment->commission_amount,
                    'order_driver_release',
                    $assignment->id,
                    $order->reference.' · segment '.$assignment->sequence,
                );

                $this->journal->record([
                    'entry_type' => JournalEntryType::Transfer,
                    'reference_type' => 'order',
                    'reference_id' => $order->id,
                    'credit' => (int) $assignment->partner_amount,
                    'participant' => $driver->user_id,
                    'balance_after' => (int) $driverWallet->fresh()->available_balance,
                    'actor' => 'system',
                ]);
            }

            return;
        }

        $driver = $delivery?->driverProfile;

        if ($driver !== null) {
            $driverWallet = $this->walletFor($driver);

            $this->releaseDriverEarning(
                $driverWallet,
                (int) ($financials->delivery_total ?? $financials->delivery_fee),
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
     * Crédite en attente la part d'un segment colis (au moment de la remise).
     */
    public function creditParcelAssignment(ParcelAssignment $assignment): void
    {
        $driver = $assignment->driverProfile;
        $parcel = $assignment->parcel;

        if ($driver === null || $parcel === null || (int) $assignment->gross_amount <= 0) {
            return;
        }

        $this->creditPending(
            $this->walletFor($driver),
            (int) $assignment->gross_amount,
            'parcel_assignment_credit',
            $assignment->id,
            'Prix de livraison colis (en attente) — '.$parcel->reference.' · segment '.$assignment->sequence,
        );
    }

    /**
     * Libère les parts de chaque segment colis (livreur initial + remplaçants).
     */
    public function releaseParcelAssignments(Parcel $parcel): void
    {
        $parcel->loadMissing('assignments.driverProfile');

        foreach ($parcel->assignments as $assignment) {
            $driver = $assignment->driverProfile;

            if ($driver === null || (int) $assignment->gross_amount <= 0) {
                continue;
            }

            $wallet = $this->walletFor($driver);

            if ($parcel->isCash()) {
                $this->creditDriverEarning(
                    $wallet,
                    (int) $assignment->gross_amount,
                    (int) $assignment->commission_amount,
                    'parcel_assignment_earning',
                    $assignment->id,
                    $parcel->reference.' · segment '.$assignment->sequence,
                );
            } else {
                if (in_array($assignment->status, [
                    ParcelAssignment::STATUS_ACTIVE,
                    ParcelAssignment::STATUS_PENDING_HANDOVER,
                ], true)) {
                    $this->creditParcelAssignment($assignment);
                }

                $this->releaseDriverEarning(
                    $wallet,
                    (int) $assignment->gross_amount,
                    (int) $assignment->commission_amount,
                    'parcel_assignment_release',
                    $assignment->id,
                    $parcel->reference.' · segment '.$assignment->sequence,
                );
            }

            $this->journal->record([
                'entry_type' => JournalEntryType::Transfer,
                'reference_type' => 'parcel',
                'reference_id' => $parcel->id,
                'credit' => (int) $assignment->partner_amount,
                'participant' => $driver->user_id,
                'balance_after' => (int) $wallet->fresh()->available_balance,
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
        $order->loadMissing('financials', 'vendor', 'delivery.assignments.driverProfile', 'delivery.driverProfile');

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

        $assignments = $order->delivery?->assignments ?? collect();

        if ($assignments->isNotEmpty()) {
            foreach ($assignments as $assignment) {
                if ($assignment->driverProfile === null || (int) $assignment->gross_amount <= 0) {
                    continue;
                }

                $this->debitPending(
                    $this->walletFor($assignment->driverProfile),
                    (int) $assignment->gross_amount,
                    'order_driver_reversal',
                    $assignment->id,
                    'Annulation part livreur — '.$order->reference.' · segment '.$assignment->sequence,
                );
            }

            return;
        }

        $driver = $order->delivery?->driverProfile;

        if ($driver !== null && (int) ($financials->delivery_total ?? $financials->delivery_fee) > 0) {
            $this->debitPending(
                $this->walletFor($driver),
                (int) ($financials->delivery_total ?? $financials->delivery_fee),
                'order_driver_reversal',
                $order->id,
                'Annulation part livreur — '.$order->reference,
            );
        }
    }

    // ------------------------------------------------------------- Cycle colis

    /**
     * Encaissement en ligne d'un colis : journalise le paiement client, la
     * commission retenue par la plateforme (part livreur séquestrée à part) et
     * les frais fixes de création payés par l'expéditeur.
     */
    public function recordParcelPayment(Parcel $parcel): void
    {
        $total = $parcel->totalAmount();

        $this->journal->record([
            'entry_type' => JournalEntryType::Payment,
            'reference_type' => 'parcel',
            'reference_id' => $parcel->id,
            'credit' => $total,
            'participant' => $parcel->user_id,
            'balance_after' => $total,
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

        if ((int) $parcel->creation_fee > 0) {
            $this->journal->record([
                'entry_type' => JournalEntryType::Fee,
                'reference_type' => 'parcel',
                'reference_id' => $parcel->id,
                'credit' => (int) $parcel->creation_fee,
                'participant' => $parcel->user_id,
                'actor' => 'system',
            ]);
        }
    }

    /** Journalise l'encaissement en ligne des frais d'approche d'un colis. */
    public function recordParcelApproachPayment(Parcel $parcel, int $amount): void
    {
        if ($amount <= 0) {
            return;
        }

        $this->journal->record([
            'entry_type' => JournalEntryType::Payment,
            'reference_type' => 'parcel',
            'reference_id' => $parcel->id,
            'credit' => $amount,
            'participant' => $parcel->user_id,
            'balance_after' => $amount,
            'actor' => 'system',
        ]);
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

        if ($parcel->isCash() && (int) $parcel->creation_fee > 0) {
            $this->journal->record([
                'entry_type' => JournalEntryType::Fee,
                'reference_type' => 'parcel',
                'reference_id' => $parcel->id,
                'credit' => (int) $parcel->creation_fee,
                'participant' => $parcel->user_id,
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

        if ((int) $parcel->creation_fee > 0) {
            $this->journal->record([
                'entry_type' => JournalEntryType::Reversal,
                'reference_type' => 'parcel',
                'reference_id' => $parcel->id,
                'debit' => (int) $parcel->creation_fee,
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
