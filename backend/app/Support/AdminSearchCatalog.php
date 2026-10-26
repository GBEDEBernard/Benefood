<?php

namespace App\Support;

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;

final class AdminSearchCatalog
{
    /**
     * @return array<int, array{label: string, description: string, route: string, icon: string, keywords: string}>
     */
    public static function pages(): array
    {
        $pages = [
            [
                'label' => 'Tableau de bord',
                'description' => 'Vue d’ensemble, KPI et activité récente',
                'route' => 'admin.dashboard',
                'icon' => 'ti-dashboard',
                'keywords' => 'accueil home statistiques dashboard',
            ],
            [
                'label' => 'Commandes',
                'description' => 'Suivre et gérer toutes les commandes',
                'route' => 'admin.orders.index',
                'icon' => 'ti-shopping-cart',
                'keywords' => 'orders achats transactions',
            ],
            [
                'label' => 'Clients',
                'description' => 'Comptes clients, profils et historique',
                'route' => 'admin.clients.index',
                'icon' => 'ti-user',
                'keywords' => 'clients utilisateurs acheteurs',
            ],
            [
                'label' => 'Vendeurs',
                'description' => 'Boutiques, statuts et documents',
                'route' => 'admin.vendors.index',
                'icon' => 'ti-briefcase',
                'keywords' => 'vendors boutiques commerçants partenaires',
            ],
            [
                'label' => 'Livreurs',
                'description' => 'Profils, documents et disponibilité',
                'route' => 'admin.drivers.index',
                'icon' => 'ti-truck',
                'keywords' => 'drivers chauffeurs livraison',
            ],
            [
                'label' => 'Produits',
                'description' => 'Catalogue, prix et disponibilités',
                'route' => 'admin.products.index',
                'icon' => 'ti-package',
                'keywords' => 'products articles catalogue',
            ],
            [
                'label' => 'Catégories',
                'description' => 'Organisation du catalogue produits',
                'route' => 'admin.categories.index',
                'icon' => 'ti-view-list',
                'keywords' => 'categories catalogue rayon',
            ],
            [
                'label' => 'Colis',
                'description' => 'Expéditions, suivi et livraisons',
                'route' => 'admin.parcels.index',
                'icon' => 'ti-package',
                'keywords' => 'parcels colis expeditions',
            ],
            [
                'label' => 'Paiements',
                'description' => 'Transactions et statuts de paiement',
                'route' => 'admin.payments.index',
                'icon' => 'ti-wallet',
                'keywords' => 'payments transactions fedapay',
            ],
            [
                'label' => 'Remboursements',
                'description' => 'Demandes et exécution des remboursements',
                'route' => 'admin.refunds.index',
                'icon' => 'ti-reload',
                'keywords' => 'refunds remboursements litiges',
            ],
            [
                'label' => 'Wallets & retraits',
                'description' => 'Portefeuilles vendeurs et livreurs',
                'route' => 'admin.payouts.index',
                'icon' => 'ti-wallet',
                'keywords' => 'payouts retraits wallet vendeurs livreurs',
            ],
            [
                'label' => 'Wallet plateforme',
                'description' => 'Solde et mouvements de la plateforme',
                'route' => 'admin.platform-wallet.index',
                'icon' => 'ti-wallet',
                'keywords' => 'wallet plateforme solde commission',
            ],
            [
                'label' => 'Commissions',
                'description' => 'Taux et répartition des commissions',
                'route' => 'admin.commissions.index',
                'icon' => 'ti-pie-chart',
                'keywords' => 'commissions taux pourcentage',
            ],
            [
                'label' => 'Réclamations',
                'description' => 'Litiges et support client',
                'route' => 'admin.complaints.index',
                'icon' => 'ti-comments',
                'keywords' => 'complaints reclamations litiges support',
            ],
            [
                'label' => 'Zones de livraison',
                'description' => 'Découpage géographique des livraisons',
                'route' => 'admin.zones.index',
                'icon' => 'ti-direction',
                'keywords' => 'zones livraison geo',
            ],
            [
                'label' => 'Villes & quartiers',
                'description' => 'Référentiel des localités desservies',
                'route' => 'admin.locations.index',
                'icon' => 'ti-location-pin',
                'keywords' => 'locations villes quartiers localites',
            ],
            [
                'label' => 'Tarifs de livraison',
                'description' => 'Grilles tarifaires par zone',
                'route' => 'admin.rates.index',
                'icon' => 'ti-truck',
                'keywords' => 'rates tarifs livraison',
            ],
            [
                'label' => 'Tarifs par distance',
                'description' => 'Barèmes distance et frais plateforme',
                'route' => 'admin.pricing.index',
                'icon' => 'ti-direction',
                'keywords' => 'pricing distance bareme frais',
            ],
            [
                'label' => 'Utilisateurs',
                'description' => 'Comptes du back-office et rôles',
                'route' => 'admin.users.index',
                'icon' => 'ti-user',
                'keywords' => 'users utilisateurs comptes',
            ],
            [
                'label' => 'Rôles & permissions',
                'description' => 'Droits d’accès et habilitations',
                'route' => 'admin.roles.index',
                'icon' => 'ti-shield',
                'keywords' => 'roles permissions droits acces',
            ],
            [
                'label' => 'Audit',
                'description' => 'Journal des actions sensibles',
                'route' => 'admin.audit.index',
                'icon' => 'ti-stats-up',
                'keywords' => 'audit journal logs securite',
            ],
            [
                'label' => 'Rapports',
                'description' => 'Rapports et exports d’activité',
                'route' => 'admin.reports.index',
                'icon' => 'ti-bar-chart',
                'keywords' => 'reports rapports exports statistiques',
            ],
            [
                'label' => 'Paramètres',
                'description' => 'Configuration générale de la plateforme',
                'route' => 'admin.settings.index',
                'icon' => 'ti-settings',
                'keywords' => 'settings parametres configuration',
            ],
            [
                'label' => 'Nouveau produit',
                'description' => 'Ajouter un article au catalogue',
                'route' => 'admin.products.create',
                'icon' => 'ti-plus',
                'keywords' => 'creer ajouter nouveau produit article',
            ],
            [
                'label' => 'Nouveau livreur',
                'description' => 'Créer un profil livreur',
                'route' => 'admin.drivers.create',
                'icon' => 'ti-plus',
                'keywords' => 'creer ajouter nouveau livreur chauffeur',
            ],
            [
                'label' => 'Nouvelle catégorie',
                'description' => 'Créer une catégorie de produits',
                'route' => 'admin.categories.create',
                'icon' => 'ti-plus',
                'keywords' => 'creer ajouter nouvelle categorie',
            ],
            [
                'label' => 'Nouvelle zone',
                'description' => 'Créer une zone de livraison',
                'route' => 'admin.zones.create',
                'icon' => 'ti-plus',
                'keywords' => 'creer ajouter nouvelle zone livraison',
            ],
            [
                'label' => 'Nouvelle ville / quartier',
                'description' => 'Ajouter une localité desservie',
                'route' => 'admin.locations.create',
                'icon' => 'ti-plus',
                'keywords' => 'creer ajouter nouvelle ville quartier localite',
            ],
            [
                'label' => 'Nouveau tarif',
                'description' => 'Créer une grille tarifaire de livraison',
                'route' => 'admin.rates.create',
                'icon' => 'ti-plus',
                'keywords' => 'creer ajouter nouveau tarif livraison',
            ],
        ];

        return array_values(array_filter(
            $pages,
            static fn (array $page): bool => Route::has($page['route']),
        ));
    }

    /**
     * @return array<int, array{label: string, description: string, route: string, icon: string, keywords: string}>
     */
    public static function search(string $query): array
    {
        $needle = self::normalize($query);

        if ($needle === '') {
            return [];
        }

        return array_values(array_filter(
            self::pages(),
            static fn (array $page): bool => str_contains(
                self::normalize($page['label'].' '.$page['description'].' '.$page['route'].' '.$page['keywords']),
                $needle,
            ),
        ));
    }

    /**
     * @param  array<int, array{label: string, description: string, route: string, icon: string, keywords: string}>  $pages
     * @return array<int, array{label: string, description: string, url: string, icon: string}>
     */
    public static function items(array $pages): array
    {
        return array_map(static fn (array $page): array => [
            'label' => $page['label'],
            'description' => $page['description'],
            'url' => route($page['route']),
            'icon' => $page['icon'],
        ], $pages);
    }

    private static function normalize(string $value): string
    {
        return trim(Str::ascii(Str::lower($value)));
    }
}
