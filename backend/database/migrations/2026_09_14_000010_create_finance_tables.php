<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Finance : commissions, répartition, wallets, reversements, journal (J29 §7).
     */
    public function up(): void
    {
        Schema::create('commission_rates', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->unsignedInteger('rate');
            $table->timestamp('effective_from')->useCurrent();
            $table->timestamp('effective_to')->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->text('notes')->nullable();
            $table->foreignUuid('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->index('effective_from');
        });

        Schema::create('order_financials', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('order_id')->unique()->constrained('orders');
            $table->unsignedInteger('subtotal')->default(0);
            $table->unsignedInteger('discount')->default(0);
            $table->unsignedInteger('delivery_fee')->default(0);
            $table->unsignedInteger('payment_fee')->default(0);
            $table->unsignedInteger('commission_base')->default(0);
            $table->unsignedInteger('commission_rate')->default(0);
            $table->unsignedInteger('commission_amount')->default(0);
            $table->unsignedInteger('vendor_amount')->default(0);
            $table->unsignedInteger('delivery_partner_amount')->default(0);
            $table->unsignedInteger('platform_amount')->default(0);
            $table->unsignedInteger('total_client')->default(0);
            $table->string('currency', 3)->default('XOF');
            $table->string('payment_reference')->nullable();
            $table->timestamps();
        });

        Schema::create('wallets', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('owner_type', 30);
            $table->uuid('owner_id');
            $table->unsignedInteger('balance')->default(0);
            $table->timestamps();
            $table->unique(['owner_type', 'owner_id']);
        });

        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('wallet_id')->constrained('wallets');
            $table->string('type', 10);
            $table->unsignedInteger('amount');
            $table->string('reference_type', 50)->nullable();
            $table->uuid('reference_id')->nullable();
            $table->string('description')->nullable();
            $table->unsignedInteger('balance_after');
            $table->timestamps();
            $table->index(['reference_type', 'reference_id']);
        });

        Schema::create('payouts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('wallet_id')->constrained('wallets');
            $table->unsignedInteger('amount');
            $table->string('method', 20)->default('kkiapay');
            $table->string('status', 20)->default('pending')->index();
            $table->timestamp('executed_at')->nullable();
            $table->foreignUuid('executed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('gateway_ref')->nullable();
            $table->timestamps();
        });

        Schema::create('financial_journal', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->timestamp('occurred_at')->useCurrent();
            $table->string('reference_type', 50);
            $table->uuid('reference_id')->nullable();
            $table->string('entry_type', 30);
            $table->unsignedInteger('debit')->nullable();
            $table->unsignedInteger('credit')->nullable();
            $table->uuid('participant')->nullable();
            $table->unsignedInteger('balance_after')->nullable();
            $table->string('actor')->nullable();
            $table->string('status', 20)->default('posted');
            $table->timestamps();
            $table->index(['reference_type', 'reference_id']);
            $table->index('occurred_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('financial_journal');
        Schema::dropIfExists('payouts');
        Schema::dropIfExists('wallet_transactions');
        Schema::dropIfExists('wallets');
        Schema::dropIfExists('order_financials');
        Schema::dropIfExists('commission_rates');
    }
};
