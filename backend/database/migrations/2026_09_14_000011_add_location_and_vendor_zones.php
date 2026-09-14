<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('vendors', function (Blueprint $table) {
            $table->decimal('latitude', 10, 7)->nullable()->after('address');
            $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
        });

        Schema::create('vendor_zones', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('vendor_id')->constrained('vendors');
            $table->foreignUuid('zone_id')->constrained('delivery_zones');
            $table->timestamps();
            $table->unique(['vendor_id', 'zone_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vendor_zones');
        Schema::table('vendors', function (Blueprint $table) {
            $table->dropColumn(['latitude', 'longitude']);
        });
    }
};
