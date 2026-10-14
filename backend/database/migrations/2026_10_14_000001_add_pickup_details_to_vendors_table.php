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
            $table->text('pickup_address')->nullable()->after('address');
            $table->string('pickup_landmark')->nullable()->after('pickup_address');
            $table->text('delivery_instructions')->nullable()->after('pickup_landmark');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('vendors', function (Blueprint $table) {
            $table->dropColumn([
                'pickup_address',
                'pickup_landmark',
                'delivery_instructions',
            ]);
        });
    }
};
