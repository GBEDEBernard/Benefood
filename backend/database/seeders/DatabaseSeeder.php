<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            RolesAndPermissionsSeeder::class,
            CommissionRatesSeeder::class,
            DeliveryZonesSeeder::class,
            CategoriesSeeder::class,
            NotificationTemplatesSeeder::class,
            AdminDashboardSeeder::class,

        ]);

        // Données de démonstration marketplace (dev uniquement) : vendeurs avec
        // boutique + produits, clients, livreurs et commandes réelles.
        $this->call([
            ShopDataSeeder::class,
        ]);
    }
}
