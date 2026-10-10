<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('vendors', function (Blueprint $table) {
            $table->string('closed_reason')->nullable()->after('closed_at');
        });

        Schema::table('vendor_settings', function (Blueprint $table) {
            $table->string('payout_method', 30)->nullable()->after('auto_accept');
            $table->string('payout_details')->nullable()->after('payout_method');
            $table->boolean('notify_new_orders')->default(true)->after('payout_details');
            $table->boolean('notify_cancellations')->default(true)->after('notify_new_orders');
            $table->boolean('notify_payments')->default(true)->after('notify_cancellations');
            $table->string('locale', 5)->default('fr')->after('notify_payments');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('vendors', function (Blueprint $table) {
            $table->dropColumn('closed_reason');
        });

        Schema::table('vendor_settings', function (Blueprint $table) {
            $table->dropColumn([
                'payout_method',
                'payout_details',
                'notify_new_orders',
                'notify_cancellations',
                'notify_payments',
                'locale',
            ]);
        });
    }
};
