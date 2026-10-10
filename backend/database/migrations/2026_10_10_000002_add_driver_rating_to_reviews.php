<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cahier de conception v1.0 — avis client sur le vendeur **et** le livreur.
 * `reviews.rating` reste la note du vendeur ; on ajoute la note du livreur et
 * le lien direct vers son profil pour recalculer sa note moyenne.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reviews', function (Blueprint $table) {
            $table->foreignUuid('driver_profile_id')->nullable()->after('user_id')->constrained('driver_profiles')->nullOnDelete();
            $table->unsignedTinyInteger('driver_rating')->nullable()->after('rating');
        });
    }

    public function down(): void
    {
        Schema::table('reviews', function (Blueprint $table) {
            $table->dropConstrainedForeignId('driver_profile_id');
            $table->dropColumn('driver_rating');
        });
    }
};
