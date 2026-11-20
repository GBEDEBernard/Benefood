<?php

namespace Database\Seeders;

use App\Services\GeoReferenceImporter;
use Illuminate\Database\Seeder;

class GeoReferenceSeeder extends Seeder
{
    public function run(GeoReferenceImporter $importer): void
    {
        $stats = $importer->import();

        $this->command?->info(sprintf(
            'Référentiel IGN importé : %d départements, %d communes, %d arrondissements, %d localités.',
            $stats['departments'],
            $stats['communes'],
            $stats['arrondissements'],
            $stats['localities'],
        ));
    }
}
