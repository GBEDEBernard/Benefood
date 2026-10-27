<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->unsignedInteger('approach_fee')->default(0)->after('delivery_fee');
            $table->decimal('approach_distance_km', 8, 3)->nullable()->after('approach_fee');
            $table->json('approach_pricing_snapshot')->nullable()->after('approach_distance_km');
        });

        Schema::table('order_financials', function (Blueprint $table) {
            $table->unsignedInteger('approach_fee')->default(0)->after('delivery_fee');
            $table->unsignedInteger('delivery_total')->default(0)->after('approach_fee');
            $table->unsignedInteger('base_partner_amount')->default(0)->after('delivery_partner_amount');
            $table->unsignedInteger('approach_partner_amount')->default(0)->after('base_partner_amount');
        });

        DB::table('order_financials')->update([
            'delivery_total' => DB::raw('delivery_fee'),
            'base_partner_amount' => DB::raw('delivery_partner_amount'),
        ]);
    }

    public function down(): void
    {
        Schema::table('order_financials', function (Blueprint $table) {
            $table->dropColumn(['approach_fee', 'delivery_total', 'base_partner_amount', 'approach_partner_amount']);
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['approach_fee', 'approach_distance_km', 'approach_pricing_snapshot']);
        });
    }
};
