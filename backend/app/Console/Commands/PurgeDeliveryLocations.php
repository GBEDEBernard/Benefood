<?php

namespace App\Console\Commands;

use App\Models\DeliveryLocation;
use Illuminate\Console\Command;

class PurgeDeliveryLocations extends Command
{
    protected $signature = 'deliveries:purge-locations';

    protected $description = 'Purger les relevés GPS de livraison au-delà de la durée de conservation.';

    public function handle(): int
    {
        $days = max(1, (int) config('beninfood.tracking.history_retention_days', 30));

        $deleted = DeliveryLocation::query()
            ->where('recorded_at', '<', now()->subDays($days))
            ->delete();

        $this->info("{$deleted} relevé(s) GPS de plus de {$days} jour(s) supprimé(s).");

        return self::SUCCESS;
    }
}
