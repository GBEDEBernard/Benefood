<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Les colonnes `delivery_commission_rate/amount` et `delivery_partner_amount`
     * ont été ajoutées après coup : les commandes créées avant ont un taux à 0 et
     * une part livreur à 0. On recalcule la ventilation livraison à partir des
     * frais réellement facturés, puis on aligne la part stockée sur la course.
     */
    public function up(): void
    {
        $rate = (int) config('beninfood.delivery_commission.rate', 20);

        DB::table('order_financials')
            ->where('delivery_commission_rate', 0)
            ->where('delivery_fee', '>', 0)
            ->orderBy('order_id')
            ->get(['id', 'delivery_fee'])
            ->each(function (object $row) use ($rate): void {
                $commission = (int) round((int) $row->delivery_fee * $rate / 100);

                DB::table('order_financials')->where('id', $row->id)->update([
                    'delivery_commission_rate' => $rate,
                    'delivery_commission_amount' => $commission,
                    'delivery_partner_amount' => (int) $row->delivery_fee - $commission,
                ]);
            });

        DB::table('deliveries')
            ->join('order_financials', 'order_financials.order_id', '=', 'deliveries.order_id')
            ->where('deliveries.partner_amount', 0)
            ->where('deliveries.fee', '>', 0)
            ->update(['deliveries.partner_amount' => DB::raw('order_financials.delivery_partner_amount')]);
    }

    public function down(): void
    {
        // Rétro-remplissage : non réversible sans perdre la ventilation d'origine.
    }
};
