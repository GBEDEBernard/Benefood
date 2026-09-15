<?php

namespace App\Console\Commands;

use App\Services\OrderService;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

#[Signature('orders:expire-unpaid')]
#[Description('Expire les commandes dont le paiement n\'a pas été reçu avant le délai (J85).')]
class OrderExpireUnpaidCommand extends Command
{
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
