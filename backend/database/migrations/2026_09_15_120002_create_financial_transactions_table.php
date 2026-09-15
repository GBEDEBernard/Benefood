<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('financial_transactions')) {
            Schema::create('financial_transactions', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->uuid('payment_id')->nullable()->index();
                $table->uuid('order_id')->nullable()->index();
                $table->string('type')->index(); // credit/debit
                $table->bigInteger('amount')->unsigned();
                $table->string('currency', 10)->default('XOF');
                $table->string('description')->nullable();
                $table->json('meta')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('financial_transactions');
    }
};
