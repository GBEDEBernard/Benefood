<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('payments')) {
            Schema::create('payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('order_id')->nullable()->index();
            $table->string('provider')->index();
            $table->string('provider_transaction_id')->nullable()->index();
            $table->bigInteger('amount')->unsigned();
            $table->string('currency', 10)->default('XOF');
            $table->string('status')->index();
            $table->json('metadata')->nullable();
            $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('payments');
    }
};
