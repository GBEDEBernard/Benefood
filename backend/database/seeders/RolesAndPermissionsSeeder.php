<?php

namespace Database\Seeders;

use App\Models\Permission;
use App\Models\Role;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class RolesAndPermissionsSeeder extends Seeder
{
    /**
     * Rôles et permissions (J32 §2 et §3).
     */
    public function run(): void
    {
        $roles = [
            'porteuse' => ['name' => 'Porteuse', 'description' => 'Maîtrise d’ouvrage — accès back-office complet.'],
            'admin-technique' => ['name' => 'Administrateur technique', 'description' => 'Supervision technique et pilotage.'],
            'vendor' => ['name' => 'Vendeur', 'description' => 'Gère sa boutique, son catalogue et ses commandes.'],
            'client' => ['name' => 'Client', 'description' => 'Parcours, panier et commandes.'],
            'driver-independent' => ['name' => 'Livreur indépendant', 'description' => 'Livraison en freelance.'],
            'driver-beninfood' => ['name' => 'Livreur Béninfood', 'description' => 'Livraison interne Béninfood.'],
        ];

        foreach ($roles as $slug => $data) {
            Role::updateOrCreate(['slug' => $slug], [
                'name' => $data['name'],
                'description' => $data['description'],
            ]);
        }

        $permissions = [
            'auth.login' => ['name' => 'Se connecter', 'module' => 'auth'],
            'auth.register' => ['name' => 'S’inscrire', 'module' => 'auth'],
            'auth.profile.read' => ['name' => 'Lire son profil', 'module' => 'auth'],
            'auth.profile.update' => ['name' => 'Mettre à jour son profil', 'module' => 'auth'],
            'admin.dashboard' => ['name' => 'Consulter le dashboard', 'module' => 'admin'],
            'admin.vendors.approve' => ['name' => 'Valider des vendeurs', 'module' => 'admin'],
            'admin.vendors.suspend' => ['name' => 'Suspendre des vendeurs', 'module' => 'admin'],
            'admin.finance.view' => ['name' => 'Consulter la finance', 'module' => 'admin'],
            'admin.delivery.manage' => ['name' => 'Piloter les livraisons', 'module' => 'admin'],
            'admin.audit.view' => ['name' => 'Consulter l’audit', 'module' => 'admin'],
            'admin.support.resolve' => ['name' => 'Résoudre les réclamations', 'module' => 'admin'],
            'admin.orders.cancel' => ['name' => 'Annuler des commandes', 'module' => 'admin'],
            'payments.refund' => ['name' => 'Exécuter des remboursements', 'module' => 'payments'],
            'vendor.profile.manage' => ['name' => 'Gérer son profil vendeur', 'module' => 'vendor'],
            'vendor.documents.manage' => ['name' => 'Gérer ses documents', 'module' => 'vendor'],
            'vendor.products.manage' => ['name' => 'Gérer son catalogue', 'module' => 'vendor'],
            'vendor.orders.accept' => ['name' => 'Accepter/refuser des commandes', 'module' => 'vendor'],
            'vendor.orders.manage' => ['name' => 'Suivre ses commandes', 'module' => 'vendor'],
            'vendor.finance.earnings' => ['name' => 'Consulter ses gains', 'module' => 'vendor'],
            'vendor.delivery.rates.manage' => ['name' => 'Gérer ses tarifs de livraison', 'module' => 'vendor'],
            'client.cart.manage' => ['name' => 'Gérer son panier', 'module' => 'client'],
            'client.orders.manage' => ['name' => 'Gérer ses commandes', 'module' => 'client'],
            'client.reviews.create' => ['name' => 'Laisser des avis', 'module' => 'client'],
            'driver.availability.manage' => ['name' => 'Gérer sa disponibilité', 'module' => 'driver'],
            'driver.deliveries.manage' => ['name' => 'Gérer ses courses', 'module' => 'driver'],
            'driver.documents.manage' => ['name' => 'Gérer ses documents', 'module' => 'driver'],
            'driver.finance.earnings' => ['name' => 'Consulter ses gains', 'module' => 'driver'],
        ];

        foreach ($permissions as $slug => $meta) {
            Permission::updateOrCreate(['slug' => $slug], [
                'name' => $meta['name'],
                'module' => $meta['module'],
            ]);
        }

        $assignments = [
            'client' => ['auth.', 'client.'],
            'vendor' => ['auth.', 'vendor.'],
            'driver-independent' => ['auth.', 'driver.'],
            'driver-beninfood' => ['auth.', 'driver.'],
            'admin-technique' => ['auth.', 'admin.', 'payments.refund'],
            'porteuse' => ['auth.', 'admin.', 'payments.refund'],
        ];

        foreach ($assignments as $slug => $prefixes) {
            $role = Role::where('slug', $slug)->firstOrFail();
            $permissionIds = Permission::all()
                ->filter(fn (Permission $permission) => Str::startsWith($permission->slug, $prefixes))
                ->pluck('id');

            $role->permissions()->sync($permissionIds);
        }
    }
}
