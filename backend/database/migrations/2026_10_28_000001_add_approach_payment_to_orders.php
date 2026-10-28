<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->string('purpose', 30)->nullable()->after('parcel_id')->index();
        });

        DB::table('payments')->whereNotNull('order_id')->update(['purpose' => 'order']);
        DB::table('payments')->whereNotNull('parcel_id')->update(['purpose' => 'parcel']);
        DB::table('payments')
            ->whereNull('order_id')
            ->whereNull('parcel_id')
            ->update(['purpose' => 'float_topup']);

        Schema::table('orders', function (Blueprint $table) {
            $table->string('approach_payment_method', 20)->nullable()->after('approach_pricing_snapshot');
            $table->string('approach_payment_status', 20)->nullable()->after('approach_payment_method');
            $table->foreignUuid('approach_driver_profile_id')->nullable()->after('approach_payment_status')->constrained('driver_profiles')->nullOnDelete();
            $table->timestamp('approach_paid_at')->nullable()->after('approach_driver_profile_id');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropConstrainedForeignId('approach_driver_profile_id');
            $table->dropColumn(['approach_payment_method', 'approach_payment_status', 'approach_paid_at']);
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->dropColumn('purpose');
        });
    }
};
