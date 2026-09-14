<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Livreurs, livraisons et journal d'activité (J29 §8).
     */
    public function up(): void
    {
        Schema::create('driver_profiles', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->unique()->constrained('users');
            $table->string('type', 30)->default('independent');
            $table->string('status', 20)->default('pending')->index();
            $table->string('vehicle')->nullable();
            $table->boolean('available')->default(false);
            $table->decimal('last_latitude', 10, 7)->nullable();
            $table->decimal('last_longitude', 10, 7)->nullable();
            $table->decimal('rating', 3, 2)->nullable();
            $table->timestamps();
            $table->index(['status', 'available']);
        });

        Schema::create('driver_documents', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('driver_profile_id')->constrained('driver_profiles');
            $table->string('type', 50);
            $table->string('file_path');
            $table->string('status', 20)->default('submitted');
            $table->foreignUuid('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->string('reason')->nullable();
            $table->timestamps();
        });

        Schema::create('driver_availability_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('driver_profile_id')->constrained('driver_profiles');
            $table->boolean('was_online')->default(false);
            $table->boolean('to_online')->default(false);
            $table->timestamp('changed_at')->useCurrent();
        });

        Schema::create('deliveries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('order_id')->unique()->constrained('orders');
            $table->foreignUuid('driver_profile_id')->nullable()->constrained('driver_profiles')->nullOnDelete();
            $table->foreignUuid('vendor_id')->nullable()->constrained('vendors')->nullOnDelete();
            $table->foreignUuid('zone_id')->nullable()->constrained('delivery_zones')->nullOnDelete();
            $table->string('status', 20)->default('assigned')->index();
            $table->unsignedInteger('fee')->default(0);
            $table->unsignedInteger('partner_amount')->default(0);
            $table->string('proof_code', 10)->nullable();
            $table->string('proof_photo_path')->nullable();
            $table->timestamp('assigned_at')->nullable();
            $table->timestamp('picked_up_at')->nullable();
            $table->timestamp('delivered_at')->nullable();
            $table->timestamps();
        });

        Schema::create('delivery_status_history', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('delivery_id')->constrained('deliveries');
            $table->string('from_status', 20)->nullable();
            $table->string('to_status', 20);
            $table->string('actor', 50)->nullable();
            $table->string('reason')->nullable();
            $table->timestamp('created_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('delivery_status_history');
        Schema::dropIfExists('deliveries');
        Schema::dropIfExists('driver_availability_logs');
        Schema::dropIfExists('driver_documents');
        Schema::dropIfExists('driver_profiles');
    }
};
