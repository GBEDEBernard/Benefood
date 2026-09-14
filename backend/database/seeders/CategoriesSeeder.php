<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;

class CategoriesSeeder extends Seeder
{
    /**
     * Catégories initiales de la marketplace.
     */
    public function run(): void
    {
        $categories = [
            ['name' => 'Fruits et légumes', 'slug' => 'fruits-et-legumes'],
            ['name' => 'Viandes et poissons', 'slug' => 'viandes-et-poissons'],
            ['name' => 'Épicerie', 'slug' => 'epicerie'],
            ['name' => 'Boissons et frais', 'slug' => 'boissons-et-frais'],
            ['name' => 'Produits laitiers et œufs', 'slug' => 'produits-laitiers-et-oeufs'],
            ['name' => 'Boulangerie', 'slug' => 'boulangerie'],
            ['name' => 'Snacks et restauration', 'slug' => 'snacks-et-restauration'],
            ['name' => 'Ménage et hygiène', 'slug' => 'menage-et-hygiene'],
            ['name' => 'Autres', 'slug' => 'autres'],
        ];

        foreach ($categories as $position => $category) {
            Category::updateOrCreate(
                ['slug' => $category['slug']],
                [
                    'name' => $category['name'],
                    'sort_order' => $position + 1,
                    'is_active' => true,
                ],
            );
        }
    }
}
