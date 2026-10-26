<?php

namespace App\Console\Commands;

use App\Services\DriverSelectionService;
use Illuminate\Console\Command;

class ExpireDriverAssignmentRequests extends Command
{
    protected $signature = 'driver-assignments:expire';

    protected $description = 'Expire les demandes de livreur sans réponse et libère la course.';

    public function handle(DriverSelectionService $selection): int
    {
        $count = $selection->expireStale();

        $this->info("{$count} demande(s) de livreur expirée(s).");

        return Command::SUCCESS;
    }
}
