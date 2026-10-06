# Béninfood

Plateforme de marketplace transactionnelle : commande, paiement mobile money, livraison et commissions.
**Béninfood** centralise le savoir-faire dans une API Laravel unique consommée par une seule application Flutter multi-rôles (Client, Vendeur, Livreur) et par un back-office web pour la porteuse.

## Architecture

```
Béninfood/
├── backend/          → API Laravel (/api/v1) + back-office web admin (Blade + template Mentor)
├── mobile/           → Application Flutter unique multi-rôles
└── documentation/    → Livrables des phases (cadrage métier, UX, conception technique)
```

Le back-office de la porteuse est intégré au backend Laravel : mêmes services métier,
mêmes permissions, aucun accès direct à la base de données. Accessible sur `/admin`.

## Démarrage rapide

### Backend (Laravel)

Prérequis : PHP 8.4+, Composer, MySQL/MariaDB.

```bash
cd backend
cp .env.example .env       # configurer la base données
composer install
php artisan key:generate
php artisan migrate
php artisan serve
```

L'API répond sur `http://localhost:8000/api/v1`.

### Mobile (Flutter)

Prérequis : Flutter 3.44+ (stable), Dart 3.12+.

```bash
cd mobile
flutter pub get
flutter run
```

## Décisions d'architecture V1.2

| Élément | Décision retenue |
| --- | --- |
| Architecture mobile | Une seule application Flutter multi-rôles, packages isolés par feature |
| Backend | Laravel API-first `/api/v1`, logique métier côté serveur |
| Rôles | Un utilisateur peut cumuler plusieurs rôles ; contexte actif côté mobile |
| Sécurité | RBAC + policies. Le rôle déclaré par le mobile n'est jamais une autorisation |
| Paiement | FedaPay ou Kkiapay via abstraction `PaymentGateway` |
| Commission | Taux configurable par la porteuse, historisé et figé par commande |
| Livraison | Livreur indépendant ou Béninfood, zones et tarifs configurables |
| Administration | Back-office web intégré au backend (Blade + template Mentor) sur `/admin` ; aucun accès direct à la base de données |

## Avancement

| Phase | Périmètre | Statut |
| --- | --- | --- |
| 5-15 | Socle Laravel, auth multi-rôles, marketplace, paiements, finance, livraison, notifications | ✅ Terminé |
| 16 | Back-office porteuse (J133-J143) | ✅ Terminé |
| 17 | Application Flutter multi-rôles (J144-J172) | 🔄 En cours |
| 18 | Géolocalisation et adresses (J173-J179) | ✅ Terminé |
| 19 | Qualité, tests et recette (J180-J189) | 🔄 Partiel (J180) |
| 20-21 | Déploiement, formation, Go-Live | ⏳ À venir |

## Conventions Git

- Branches : `main`, `develop`, `feature/*`, `hotfix/*`
- Une tâche = une branche courte = une Pull Request revue
- Toute tâche doit être testée, documentée et versionnée avant clôture