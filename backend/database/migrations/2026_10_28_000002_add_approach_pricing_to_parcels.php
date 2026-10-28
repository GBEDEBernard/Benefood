<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('parcels', function (Blueprint $table) {
            $table->unsignedInteger('approach_fee')->default(0)->after('delivery_fee');
            $table->decimal('approach_distance_km', 8, 3)->nullable()->after('approach_fee');
            $table->json('approach_pricing_snapshot')->nullable()->after('approach_distance_km');
            $table->unsignedInteger('approach_commission_amount')->default(0)->after('commission_amount');
            $table->unsignedInteger('approach_partner_amount')->default(0)->after('partner_amount');
            $table->string('approach_payment_method', 20)->nullable()->after('approach_pricing_snapshot');
            $table->string('approach_payment_status', 20)->nullable()->after('approach_payment_method');
            $table->foreignUuid('approach_driver_profile_id')->nullable()->after('approach_payment_status')->constrained('driver_profiles')->nullOnDelete();
            $table->timestamp('approach_paid_at')->nullable()->after('approach_driver_profile_id');
        });
    }

    public function down(): void
    {
        Schema::table('parcels', function (Blueprint $table) {
            $table->dropConstrainedForeignId('approach_driver_profile_id');
            $table->dropColumn([
                'approach_fee',
                'approach_distance_km',
                'approach_pricing_snapshot',
                'approach_commission_amount',
                'approach_partner_amount',
                'approach_payment_method',
                'approach_payment_status',
                'approach_paid_at',
            ]);
        });
    }
};
