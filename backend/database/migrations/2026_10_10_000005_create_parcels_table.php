<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cahier de conception v1.0 — service d'envoi de colis (phase 3).
 *
 * Un client envoie un colis d'un point A à un point B ; le prix dépend de la
 * distance (500 / 1 000 / 2 000 F), le livreur reçoit 80 % et la plateforme 20 %.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('parcels', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('reference')->unique();
            $table->foreignUuid('user_id')->constrained('users');
            $table->foreignUuid('driver_profile_id')->nullable()->constrained('driver_profiles')->nullOnDelete();
            $table->string('status', 20)->default('awaiting_payment')->index();
            $table->string('payment_status', 20)->default('initiated')->index();
            $table->string('currency', 3)->default('XOF');
            $table->string('description')->nullable();
            $table->json('pickup_snapshot');
            $table->json('dropoff_snapshot');
            $table->decimal('distance_km', 6, 2)->nullable();
            $table->unsignedInteger('delivery_fee')->default(0);
            $table->unsignedInteger('commission_rate')->default(20);
            $table->unsignedInteger('commission_amount')->default(0);
            $table->unsignedInteger('partner_amount')->default(0);
            $table->unsignedInteger('platform_amount')->default(0);
            $table->string('proof_code', 10)->nullable();
            $table->timestamp('payment_deadline_at')->nullable();
            $table->timestamp('assigned_at')->nullable();
            $table->timestamp('picked_up_at')->nullable();
            $table->timestamp('delivered_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->string('cancellation_reason')->nullable();
            $table->timestamps();
            $table->index('created_at');
        });

        Schema::create('parcel_status_histories', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('parcel_id')->constrained('parcels');
            $table->string('from_status', 20)->nullable();
            $table->string('to_status', 20);
            $table->string('actor_type', 30)->nullable();
            $table->uuid('actor_id')->nullable();
            $table->string('reason')->nullable();
            $table->timestamp('created_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('parcel_status_histories');
        Schema::dropIfExists('parcels');
    }
};
