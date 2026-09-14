<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class ExpirePendingOrders extends Command
{
    protected $signature = 'orders:expire-payments';

    protected $description = 'Fait passer les commandes en attente de paiement expirées à annulées (J33, T5).';

    public function handle(): int
    {
        // Implémenté avec OrderService + PaymentService en Phase 11 (J87-J96).
        Log::channel('beninfood')->info('[scheduler] orders:expire-payments — en attente de la Phase 11.');

        return self::SUCCESS;
    }
}
