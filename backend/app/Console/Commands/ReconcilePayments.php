<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class ReconcilePayments extends Command
{
    protected $signature = 'payments:reconcile';

    protected $description = 'Rapproche les paiements avec l’agrégateur (J33, Phase 10-11).';

    public function handle(): int
    {
        // Implémenté avec PaymentGateway / Kkiapay en Phase 11 (J105).
        Log::channel('beninfood')->info('[scheduler] payments:reconcile — en attente de la Phase 10.');

        return self::SUCCESS;
    }
}
