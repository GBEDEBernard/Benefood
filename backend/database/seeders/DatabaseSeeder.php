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
    }
}
