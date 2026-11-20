<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Référentiel administratif partagé par toutes les fonctionnalités géo.
     *
     * Les divisions forment un arbre (pays → niveau 1 → … → dernier niveau)
     * afin de ne pas imposer le découpage béninois aux autres pays. Les
     * coordonnées sont stockées en WGS84 (EPSG:4326).
     */
    public function up(): void
    {
        Schema::create('geo_countries', function (Blueprint $table): void {
            $table->id();
            $table->string('code', 2)->unique()->comment('ISO 3166-1 alpha-2');
            $table->string('name');
            $table->string('official_name')->nullable();
            $table->json('levels')->comment('Niveaux administratifs configurables du pays');
            $table->string('locality_label')->default('Localité')->comment('Libellé du dernier niveau (village, quartier…)');
            $table->string('source')->nullable();
            $table->string('source_url')->nullable();
            $table->date('data_updated_at')->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
        });

        Schema::create('geo_divisions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('country_id')->constrained('geo_countries')->cascadeOnDelete();
            $table->foreignId('parent_id')->nullable()->constrained('geo_divisions')->nullOnDelete();
            $table->string('level', 50)->comment('department, commune, arrondissement, region…');
            $table->string('source_key')->comment('Identifiant stable fourni par la source, ou clé normalisée');
            $table->string('code', 64)->nullable()->comment('Code géographique officiel quand il existe');
            $table->string('name');
            $table->string('name_normalized');
            $table->decimal('center_latitude', 10, 7)->nullable();
            $table->decimal('center_longitude', 10, 7)->nullable();
            $table->decimal('bbox_min_latitude', 10, 7)->nullable();
            $table->decimal('bbox_max_latitude', 10, 7)->nullable();
            $table->decimal('bbox_min_longitude', 10, 7)->nullable();
            $table->decimal('bbox_max_longitude', 10, 7)->nullable();
            $table->longText('geometry_json')->nullable()->comment('Polygone WGS84 simplifié, pour la localisation par point');
            $table->string('source')->nullable();
            $table->string('source_url')->nullable();
            $table->date('data_updated_at')->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();

            $table->unique(['country_id', 'level', 'source_key']);
            $table->index(['country_id', 'level', 'is_active']);
            $table->index(['parent_id', 'is_active']);
            $table->index('name_normalized');
        });

        Schema::create('geo_localities', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('country_id')->constrained('geo_countries')->cascadeOnDelete();
            $table->foreignId('division_id')->constrained('geo_divisions')->cascadeOnDelete();
            $table->string('source_key')->comment('Code géographique officiel ou clé stable calculée');
            $table->string('code', 64)->nullable();
            $table->string('name');
            $table->string('name_normalized');
            $table->string('kind', 30)->default('unknown')->comment('village, quartier, hameau, ville…');
            $table->string('administrative_status')->nullable()->comment('Statut_ADM brut de la source');
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);
            $table->string('source')->nullable();
            $table->string('source_url')->nullable();
            $table->date('data_updated_at')->nullable();
            $table->boolean('is_verified')->default(true)->comment('false pour un ajout manuel à vérifier');
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();

            $table->unique(['country_id', 'source_key']);
            $table->index(['division_id', 'is_active']);
            $table->index('name_normalized');
            $table->index(['latitude', 'longitude']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('geo_localities');
        Schema::dropIfExists('geo_divisions');
        Schema::dropIfExists('geo_countries');
    }
};
