<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('parcels', function (Blueprint $table): void {
            $table->unsignedTinyInteger('reassignment_count')->default(0)->after('targeted_driver_profile_id');
        });

        Schema::create('parcel_assignments', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('parcel_id')->constrained('parcels')->cascadeOnDelete();
            $table->foreignUuid('driver_profile_id')->constrained('driver_profiles')->cascadeOnDelete();
            $table->unsignedTinyInteger('sequence')->default(1);
            $table->string('status', 30)->default('active');
            $table->unsignedInteger('base_fee')->default(0);
            $table->unsignedInteger('approach_fee')->default(0);
            $table->unsignedInteger('gross_amount')->default(0);
            $table->unsignedInteger('commission_amount')->default(0);
            $table->unsignedInteger('partner_amount')->default(0);
            $table->unsignedInteger('base_partner_amount')->default(0);
            $table->unsignedInteger('approach_partner_amount')->default(0);
            $table->decimal('base_distance_km', 8, 3)->nullable();
            $table->decimal('approach_distance_km', 8, 3)->nullable();
            $table->decimal('handover_latitude', 10, 7)->nullable();
            $table->decimal('handover_longitude', 10, 7)->nullable();
            $table->string('handover_code', 12)->nullable();
            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('handover_confirmed_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index(['parcel_id', 'status']);
            $table->index(['driver_profile_id', 'status']);
        });

        Schema::create('parcel_incidents', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('parcel_id')->constrained('parcels')->cascadeOnDelete();
            $table->foreignUuid('reported_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignUuid('driver_profile_id')->nullable()->constrained('driver_profiles')->nullOnDelete();
            $table->string('type', 40)->default('other');
            $table->text('message');
            $table->string('status', 30)->default('open');
            $table->json('metadata')->nullable();
            $table->timestamps();

            $table->index(['parcel_id', 'status']);
        });

        Schema::create('parcel_reassignment_requests', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('parcel_id')->constrained('parcels')->cascadeOnDelete();
            $table->foreignUuid('incident_id')->nullable()->constrained('parcel_incidents')->nullOnDelete();
            $table->foreignUuid('client_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('old_driver_profile_id')->nullable()->constrained('driver_profiles')->nullOnDelete();
            $table->foreignUuid('new_driver_profile_id')->nullable()->constrained('driver_profiles')->nullOnDelete();
            $table->string('status', 30)->default('pending');
            $table->string('reason', 500);
            $table->decimal('handover_latitude', 10, 7)->nullable();
            $table->decimal('handover_longitude', 10, 7)->nullable();
            $table->string('handover_code', 12)->nullable();
            $table->timestamp('responded_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['parcel_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('parcel_reassignment_requests');
        Schema::dropIfExists('parcel_incidents');
        Schema::dropIfExists('parcel_assignments');

        Schema::table('parcels', function (Blueprint $table): void {
            $table->dropColumn('reassignment_count');
        });
    }
};
