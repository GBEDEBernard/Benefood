<?php

namespace App\Services\Payments;

use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\Payment;
use App\Models\Payout;

interface PaymentGateway
{
    /**
     * Indique si la passerelle possède les identifiants nécessaires pour un
     * appel réel (sinon l'implémentation bascule en mode simulé).
     */
    public function configured(): bool;

    /**
     * Crée une session/lien de paiement pour une commande et renvoie la
     * charge utile du prestataire (dont l'URL de paiement).
     *
     * @return array<string, mixed>
     */
    public function createPayment(Order $order): array;

    /**
     * Crée une session/lien de paiement pour un colis.
     *
     * @return array<string, mixed>
     */
    public function createPaymentForParcel(Parcel $parcel): array;

    /**
     * Crée une session/lien de paiement pour les frais d'approche d'une
     * commande ou d'un colis.
     *
     * @return array<string, mixed>
     */
    public function createApproachPayment(Order|Parcel $assignable, Payment $payment): array;

    /**
     * Crée une session/lien de paiement pour la recharge du flottant d'un
     * livreur (le montant et la référence proviennent du paiement interne).
     *
     * @return array<string, mixed>
     */
    public function createFloatTopUp(DriverProfile $driver, Payment $payment): array;

    /**
     * Envoie un retrait vers un compte Mobile Money (payout).
     *
     * @return array<string, mixed>
     */
    public function sendPayout(Payout $payout, string $destination, string $mode): array;

    /**
     * Vérifie une transaction auprès du fournisseur.
     *
     * @return array<string, mixed>
     */
    public function verifyTransaction(string $transactionId): array;

    /**
     * Vérifie la signature d'un webhook entrant.
     */
    public function verifyWebhookSignature(string $payload, ?string $signature): bool;

    /**
     * Handle incoming webhook payload and return standardized result.
     *
     * @return array<string, mixed>
     */
    public function handleWebhook(array $payload): array;

    /**
     * Request a refund from the provider. Return provider result payload.
     *
     * @return array<string, mixed>
     */
    public function refund(Payment $payment, int $amount, ?string $reason = null): array;
}
