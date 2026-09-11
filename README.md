# Béninfood

Plateforme de marketplace transactionnelle : commande, paiement mobile money, livraison et commissions.
**Béninfood** centralise le savoir-faire dans une API Laravel unique consommée par une seule application Flutter multi-rôles (Client, Vendeur, Livreur) et par un back-office web pour la porteuse.

## Architecture

```
Bénéfood/
├── backend/          → API Laravel (lumen de toute la logique métier, /api/v1)
├── mobile/           → Application Flutter unique multi-rôles
├── back-office/      → Back-office web de la porteuse
└── docs/             → Documentation (cahier des charges, plan, tâches)
```

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
| Administration | Back-office web ; aucun accès direct à la base de données |

## Conventions Git

- Branches : `main`, `develop`, `feature/*`, `hotfix/*`
- Une tâche = une branche courte = une Pull Request revue
- Toute tâche doit être testée, documentée et versionnée avant clôture