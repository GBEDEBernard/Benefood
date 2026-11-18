<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->decimal('latitude', 10, 7)->nullable()->after('locale');
            $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            $table->text('adresse_texte')->nullable()->after('longitude');
            $table->text('address_text')->nullable()->after('adresse_texte');
        });

        Schema::table('vendors', function (Blueprint $table) {
            if (! Schema::hasColumn('vendors', 'adresse_texte')) {
                $table->text('adresse_texte')->nullable()->after('address');
            }
            if (! Schema::hasColumn('vendors', 'address_text')) {
                $table->text('address_text')->nullable()->after('adresse_texte');
            }
            if (! Schema::hasColumn('vendors', 'latitude')) {
                $table->decimal('latitude', 10, 7)->nullable()->after('address_text');
            }
            if (! Schema::hasColumn('vendors', 'longitude')) {
                $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            }
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['latitude', 'longitude', 'adresse_texte', 'address_text']);
        });

        Schema::table('vendors', function (Blueprint $table) {
            $columns = [];
            foreach (['adresse_texte', 'address_text'] as $column) {
                if (Schema::hasColumn('vendors', $column)) {
                    $columns[] = $column;
                }
            }
            if ($columns !== []) {
                $table->dropColumn($columns);
            }
        });
    }
};
