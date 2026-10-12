<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cahier de conception v1.0 — retraits groupés (Mode B).
 *
 * L'admin regroupe plusieurs demandes de retrait en attente dans un lot
 * (payout_batch) puis exécute le lot : tous les retraits sont marqués versés
 * en une seule opération. Chaque retrait reste individuellement suivi (échec
 * possible, montant re-crédité au wallet).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payout_batches', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('reference', 40)->unique();
            $table->string('label')->nullable();
            $table->string('status', 20)->default('processing')->index();
            $table->unsignedInteger('total_amount')->default(0);
            $table->unsignedInteger('payouts_count')->default(0);
            $table->unsignedInteger('executed_count')->default(0);
            $table->unsignedInteger('failed_count')->default(0);
            $table->foreignUuid('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('gateway_ref')->nullable();
            $table->timestamp('executed_at')->nullable();
            $table->timestamps();
        });

        Schema::table('payouts', function (Blueprint $table) {
            $table->foreignUuid('batch_id')->nullable()->after('wallet_id')->constrained('payout_batches')->nullOnDelete();
            $table->string('failed_reason')->nullable()->after('gateway_ref');
            $table->index('batch_id', 'payouts_batch_idx');
        });
    }

    public function down(): void
    {
        Schema::table('payouts', function (Blueprint $table) {
            $table->dropIndex(['batch_id']);
            $table->dropColumn(['batch_id', 'failed_reason']);
        });

        Schema::dropIfExists('payout_batches');
    }
};
