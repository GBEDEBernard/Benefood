<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Métadonnées médias produits : variante thumbnail, mime et taille (J34).
     */
    public function up(): void
    {
        Schema::table('product_images', function (Blueprint $table) {
            $table->string('thumb_path')->nullable()->after('path');
            $table->string('mime', 50)->nullable()->after('thumb_path');
            $table->unsignedInteger('size')->nullable()->after('mime');
        });
    }

    public function down(): void
    {
        Schema::table('product_images', function (Blueprint $table) {
            $table->dropColumn(['thumb_path', 'mime', 'size']);
        });
    }
};
