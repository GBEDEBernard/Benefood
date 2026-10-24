<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('vendors', function (Blueprint $table) {
            $table->decimal('pickup_latitude', 10, 7)->nullable()->after('pickup_landmark');
            $table->decimal('pickup_longitude', 10, 7)->nullable()->after('pickup_latitude');
        });

        DB::table('vendors')
            ->whereNull('pickup_latitude')
            ->whereNotNull('latitude')
            ->update([
                'pickup_latitude' => DB::raw('latitude'),
                'pickup_longitude' => DB::raw('longitude'),
            ]);

        Schema::table('addresses', function (Blueprint $table) {
            $table->string('contact_phone', 20)->nullable()->after('landmark');
        });

        Schema::table('deliveries', function (Blueprint $table) {
            $table->decimal('pickup_latitude', 10, 7)->nullable()->after('zone_id');
            $table->decimal('pickup_longitude', 10, 7)->nullable()->after('pickup_latitude');
            $table->decimal('dropoff_latitude', 10, 7)->nullable()->after('pickup_longitude');
            $table->decimal('dropoff_longitude', 10, 7)->nullable()->after('dropoff_latitude');
            $table->string('dropoff_landmark')->nullable()->after('dropoff_longitude');
            $table->string('dropoff_phone', 20)->nullable()->after('dropoff_landmark');
        });
    }

    public function down(): void
    {
        Schema::table('deliveries', function (Blueprint $table) {
            $table->dropColumn([
                'pickup_latitude',
                'pickup_longitude',
                'dropoff_latitude',
                'dropoff_longitude',
                'dropoff_landmark',
                'dropoff_phone',
            ]);
        });

        Schema::table('addresses', function (Blueprint $table) {
            $table->dropColumn('contact_phone');
        });

        Schema::table('vendors', function (Blueprint $table) {
            $table->dropColumn(['pickup_latitude', 'pickup_longitude']);
        });
    }
};
