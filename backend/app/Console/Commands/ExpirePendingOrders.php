<?php

namespace App\Console\Commands;

use App\Services\OrderService;
use Illuminate\Console\Command;

class ExpirePendingOrders extends Command
{
    protected $signature = 'orders:expire-payments';

    protected $description = 'Fait passer les commandes en attente de paiement expirées à annulées (J85).';

    public function __construct(private readonly OrderService $orders)
    {
        parent::__construct();
    }

    public function handle(): int
    {
        $count = $this->orders->expireUnpaidOrders();

        $this->info("{$count} commande(s) expirée(s) pour paiement manquant.");

        return Command::SUCCESS;
    }
}
