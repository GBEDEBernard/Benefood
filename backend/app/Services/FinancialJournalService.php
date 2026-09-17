<?php

namespace App\Services;

use App\Enums\JournalEntryType;
use App\Models\FinancialJournal;
use App\Models\Order;

/**
 * Journal financier immuable (append-only) — J14 §4, J123.
 *
 * On ne corrige jamais une écriture : on ajoute une écriture de correction.
 */
class FinancialJournalService
{
    /**
     * Enregistre une écriture dans le journal financier.
     *
     * @param  array{entry_type: JournalEntryType, reference_type?: string, reference_id?: string|null, debit?: int|null, credit?: int|null, participant?: string|null, balance_after?: int|null, actor?: string|null}  $entry
     */
    public function record(array $entry): FinancialJournal
    {
        return FinancialJournal::create([
            'entry_type' => $entry['entry_type'],
            'reference_type' => $entry['reference_type'] ?? 'order',
            'reference_id' => $entry['reference_id'] ?? null,
            'debit' => $entry['debit'] ?? null,
            'credit' => $entry['credit'] ?? null,
            'participant' => $entry['participant'] ?? null,
            'balance_after' => $entry['balance_after'] ?? null,
            'actor' => $entry['actor'] ?? null,
            'status' => 'posted',
        ]);
    }

    /**
     * Contre-passée financière d'une annulation sur commande payée
     * (J12 §5.1 — J14 §3.2) : la commission et les parts ne sont pas dues.
     */
    public function recordReversalForCancellation(Order $order, ?string $actor): void
    {
        $financials = $order->financials;

        if ($financials === null) {
            return;
        }

        if ($financials->commission_amount > 0) {
            $this->record([
                'entry_type' => JournalEntryType::Reversal,
                'reference_type' => 'order',
                'reference_id' => $order->id,
                'debit' => $financials->commission_amount,
                'participant' => $order->vendor?->user_id,
                'actor' => $actor,
                'balance_after' => 0,
            ]);
        }

        if ($financials->vendor_amount > 0) {
            $this->record([
                'entry_type' => JournalEntryType::Reversal,
                'reference_type' => 'order',
                'reference_id' => $order->id,
                'debit' => $financials->vendor_amount,
                'participant' => $order->vendor?->user_id,
                'actor' => $actor,
                'balance_after' => 0,
            ]);
        }
    }
}
