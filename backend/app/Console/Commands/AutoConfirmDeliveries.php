<?php

namespace App\Console\Commands;

use App\Services\OrderService;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

#[Signature('orders:auto-confirm-deliveries')]
#[Description('Confirme automatiquement les livraisons non validées par le client (cahier v1.0).')]
class AutoConfirmDeliveries extends Command
{
    public function __construct(private readonly OrderService $orders)
    {
        parent::__construct();
    }

    public function handle(): int
    {
        $count = $this->orders->autoConfirmDeliveries();

        $this->info("{$count} livraison(s) confirmée(s) automatiquement.");

        return Command::SUCCESS;
    }
}
