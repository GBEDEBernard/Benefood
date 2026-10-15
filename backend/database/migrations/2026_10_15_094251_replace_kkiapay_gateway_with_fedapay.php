<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('payments')->where('gateway', 'kkiapay')->update(['gateway' => 'fedapay']);
        DB::table('payment_events')->where('provider', 'kkiapay')->update(['provider' => 'fedapay']);
        DB::table('payouts')->where('method', 'kkiapay')->update(['method' => 'mobile_money']);

        Schema::table('payments', function (Blueprint $table): void {
            $table->string('gateway', 30)->default('fedapay')->change();
        });

        Schema::table('payment_events', function (Blueprint $table): void {
            $table->string('provider', 30)->default('fedapay')->change();
        });

        Schema::table('payouts', function (Blueprint $table): void {
            $table->string('method', 20)->default('mobile_money')->change();
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table): void {
            $table->string('gateway', 30)->default('kkiapay')->change();
        });

        Schema::table('payment_events', function (Blueprint $table): void {
            $table->string('provider', 30)->default('kkiapay')->change();
        });

        Schema::table('payouts', function (Blueprint $table): void {
            $table->string('method', 20)->default('kkiapay')->change();
        });
    }
};
