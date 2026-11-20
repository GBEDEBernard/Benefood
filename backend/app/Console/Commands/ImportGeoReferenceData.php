<?php

namespace App\Console\Commands;

use App\Services\GeoReferenceImporter;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

#[Signature('geo:import-ign-benin')]
#[Description('Importe les géodonnées officielles IGN Bénin (12 départements, 77 communes, arrondissements et localités)')]
class ImportGeoReferenceData extends Command
{
    public function handle(GeoReferenceImporter $importer): int
    {
        $stats = $importer->import();

        $this->info('Référentiel géographique IGN Bénin importé.');
        $this->table(['Élément', 'Nombre'], [
            ['Départements', $stats['departments']],
            ['Communes', $stats['communes']],
            ['Arrondissements', $stats['arrondissements']],
            ['Localités', $stats['localities']],
            ['Localités rattachées par nom', $stats['localities_by_name']],
            ['Localités rattachées par géométrie', $stats['localities_by_geometry']],
            ['Localités non rattachées', $stats['localities_unresolved']],
        ]);

        return $stats['departments'] === 12
            && $stats['communes'] === 77
            && $stats['localities_unresolved'] === 0
            ? self::SUCCESS
            : self::FAILURE;
    }
}
