<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('platform_settings', function (Blueprint $table) {
            $table->string('key')->primary();
            $table->json('value');
            $table->foreignUuid('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('distance_pricing_rules', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('service_type', 20)->index();
            $table->decimal('max_km', 8, 3)->nullable();
            $table->unsignedInteger('base_fee');
            $table->unsignedInteger('per_km')->default(0);
            $table->unsignedTinyInteger('discount_percentage')->default(0);
            $table->unsignedInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
            $table->index(['service_type', 'is_active', 'sort_order']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('distance_pricing_rules');
        Schema::dropIfExists('platform_settings');
    }
};
