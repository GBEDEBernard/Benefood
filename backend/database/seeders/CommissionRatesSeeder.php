<?php

namespace Database\Seeders;

use App\Models\CommissionRate;
use Illuminate\Database\Seeder;

class CommissionRatesSeeder extends Seeder
{
    /**
     * Commission porteuse par défaut (config/beninfood.php).
     */
    public function run(): void
    {
        CommissionRate::updateOrCreate(
            ['is_active' => true],
            [
                'rate' => (int) config('beninfood.commission.default_rate'),
                'effective_from' => now(),
                'effective_to' => null,
                'notes' => 'Taux par défaut de la porteuse.',
            ],
        );
    }
}
