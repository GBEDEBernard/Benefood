<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payouts', function (Blueprint $table): void {
            $table->string('destination', 40)->nullable()->after('method');
            $table->index('gateway_ref', 'payouts_gateway_ref_idx');
        });
    }

    public function down(): void
    {
        Schema::table('payouts', function (Blueprint $table): void {
            $table->dropIndex('payouts_gateway_ref_idx');
            $table->dropColumn('destination');
        });
    }
};
