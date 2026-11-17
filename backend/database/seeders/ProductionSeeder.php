<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\CommissionRate;
use App\Models\DeliveryZone;
use App\Models\DistancePricingRule;
use App\Models\Neighborhood;
use App\Models\NotificationTemplate;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Données indispensables en production : référentiels et compte administrateur.
 *
 * Exécuté à chaque déploiement par entrypoint.sh. Un référentiel n'est chargé
 * que s'il est vide, afin de ne pas écraser les réglages faits depuis le
 * back-office. Le mot de passe admin vient uniquement de l'environnement.
 */
class ProductionSeeder extends Seeder
{
    public function run(): void
    {
        if (! Role::query()->exists()) {
            $this->call(RolesAndPermissionsSeeder::class);
        }

        if (! CommissionRate::query()->exists()) {
            $this->call(CommissionRatesSeeder::class);
        }

        if (! DeliveryZone::query()->exists()) {
            $this->call(DeliveryZonesSeeder::class);
        }

        if (! Neighborhood::query()->exists()) {
            $this->call(NeighborhoodSeeder::class);
        }

        if (! DistancePricingRule::query()->exists()) {
            $this->call(DistancePricingRulesSeeder::class);
        }

        if (! Category::query()->exists()) {
            $this->call(CategoriesSeeder::class);
        }

        // Une migration insère déjà le modèle « delivery.cancelled » : tester
        // seulement si la table est vide empêcherait de charger les autres.
        if (! NotificationTemplate::query()->where('event', 'order.paid')->exists()) {
            $this->call(NotificationTemplatesSeeder::class);
        }

        $this->seedAdmin();
    }

    private function seedAdmin(): void
    {
        $email = (string) config('beninfood.admin_seed.email');
        $password = config('beninfood.admin_seed.password');

        if (! is_string($password) || $password === '') {
            $this->command?->warn('ADMIN_PASSWORD is not set: no admin account was created.');

            return;
        }

        $admin = User::query()->firstOrCreate(
            ['email' => $email],
            [
                'name' => 'Administrateur',
                'phone' => '00000000',
                'password' => $password,
                'status' => 'active',
            ],
        );

        $role = Role::query()->where('slug', 'admin-technique')->first();

        if ($role !== null) {
            $admin->roles()->syncWithoutDetaching([$role->id => ['is_active' => true]]);
        }
    }
}
