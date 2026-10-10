<?php

namespace App\Console\Commands;

use App\Services\ParcelService;
use Illuminate\Console\Command;

class ExpireUnpaidParcels extends Command
{
    protected $signature = 'parcels:expire-unpaid';

    protected $description = 'Annule les colis dont le paiement n\'a pas été confirmé avant la date limite.';

    public function handle(ParcelService $parcels): int
    {
        $count = $parcels->expireUnpaidParcels();

        $this->info("{$count} colis non payés expiré(s).");

        return Command::SUCCESS;
    }
}
