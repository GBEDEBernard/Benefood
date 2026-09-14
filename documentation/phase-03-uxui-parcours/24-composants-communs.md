# J24 — Composants communs, erreurs, états vides et deep-links

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 03, J24

---

## 1. Design system (mobile unique)

| Token | Valeur (référence) |
|-------|--------------------|
| Couleur primaire | Vert Béninfood `#2E7D32` (déjà seed du thème) |
| Couleur secondaire / accent | Déjà dans `app_theme.dart` |
| Couleur erreur | Material `error` |
| Arrondis | Inputs 12 px, boutons 12 px, cartes 16 |
| Typographie | Material 3 standard |
| Icones | Material icons (coherent partout) |

## 2. Composants communs (réutilisables, `shared/`)

| Composant | Usage | Variantes / états |
|-----------|-------|-------------------|
| `AppButton` | Actions principales / secondaires | primary, secondary, danger, disabled, loading (spinner), plein largeur |
| `AppTextField` | Saisies | label flottant, icône, erreur inline, obligatoire (*), password reveal |
| `AppStepper` | Quantité / étape | − valeur +, disable aux bornes |
| `ProductCard` | Produit | image, nom, prix, badge dispo/épuisé, bouton + |
| `VendorCard` | Boutique | image, nom, note, distances, badge ouvert/fermé |
| `OrderCard` | Commande | n° , date, vendeur, total, statut badge |
| `StatusBadge` | Statuts (vendeur/livreur/commande) | palette par statut (définie en §3) |
| `EmptyState` | États vides | icône + titre + sous-texte + CTA optionnel |
| `ErrorState` | Erreur bloquante | icône + message + bouton réessayer |
| `SkeletonLoader` | Chargement liste | blocs gris animés |
| `ConfirmDialog` | Confirmation | titre, message, action destructive (rouge), btn Annuler |
| `Toast` | Retour global | succès / erreur / info (haut ou bas, court) |
| `BottomSheet` | Actions contextuelles | choix d'option, partage, tri |
| `ModeSwitcher` | Bascule de contexte | icônes Client/Vendeur/Livreur (menu latéral) |
| `NetworkBanner` | Hors-ligne | bannière + « Réessayer » |
| `MapEmbed` | Livraison | carte mini + repères (Phase 18) |
| `AmountText` | Montants | format XOF (ex. 1 500 FCFA), devise |

## 3. Paliers de statuts (badges couleurs)

| Type | Statut | Couleur badge |
|------|--------|---------------|
| Commande | draft/awaiting_payment | gris |
| Commande | paid/accepted/preparing/ready | jaune/ambre sur l'action en cours |
| Commande | assigned/picked_up/in_delivery | indigo (livraison) |
| Commande | delivered/refunded | vert |
| Commande | cancelled | rouge |
| Vendeur | registered/pending/verified/active | gris/ambre/gris/vert |
| Vendeur | suspended/closed | rouge |
| Livreur | candidate/pending/validated/active | gris/ambre/gris/vert |
| Livreur | suspended/closed | rouge |
| Livreur | online/offline | vert chef/ gris |

## 4. Messages d'erreur — conventions

| Cas | Comportement |
|-----|--------------|
| 400 validation | Erreurs inline sur les champs (l'API renvoie les clés `field` + `message`) |
| 401 | Déconnexion + redirection login (sauf si simple token expiré → refresh) |
| 403 | Écran « Accès refusé » avec bouton « changer de mode » ou contact support (J170) |
| 404 | Écran « Introuvable » + retour |
| 422 | Mapping inline des erreurs de fond |
| 429 rate limit | Message « Trop de requêtes, réessayez dans X s » |
| 5xx / réseau | `ErrorState` + « Réessayer » ; si réseau coupé : `NetworkBanner` |
| Timeout | Message clair + réessayer |

- Les messages d'erreur API (standardisé) sont affichés traduits en français.
- Jamais d'erreur technique brute affichée à l'utilisateur.

## 5. États vides (par écran)

| Écran | Texte | CTA |
|-------|-------|-----|
| Panier | « Votre panier est vide » | Explorer |
| Recherche | « Aucun résultat pour “X” » | Effacer filtres |
| Commandes | « Aucune commande pour le moment » | Commander |
| Produits (vendeur) | « Aucun produit » | Ajouter un produit |
| Commandes (vendeur) | « Aucune commande » | — |
| Missions (livreur) | « Aucune course disponible en ce moment » | Actualiser |
| Historique livreur | « Aucune mission » | — |
| Réclamations | « Aucune réclamation » | — |
| Notifications | « Aucune notification » | — |

## 6. Confirmations (actions irréversibles)

Obligatoires pour :
- Refuser une commande (vendeur) — motif requis
- Annuler une commande (client — si frais possibles → afficher la conséquence financière)
- Marquer livré (livreur)
- Déclarer un incident
- Passer hors ligne pendant une course (interdit/avec avertissement)
- Fermeture temporaire boutique / désactivation produit
- Tout changement de taux de commission (back-office)

## 7. Notifications & deep-links

### 7.1 Type d'événement → deep-link (schéma)

Chaque notification porte un **type d'événement** et un **deep-link** :

| Événement | Contexte | Deep-link |
|-----------|----------|-----------|
| `order.new_paid` | Vendeur | `/vendor/orders/{id}` |
| `order.accepted` | Client | `/client/orders/{id}` |
| `order.preparing` | Client | `/client/orders/{id}` |
| `order.ready` | Client | `/client/orders/{id}` |
| `order.assigned` | Client | `/client/orders/{id}` |
| `order.delivered` | Client | `/client/orders/{id}` |
| `delivery.new_offer` | Livreur | `/driver/missions/{id}` |
| `order.cancelled` | Client/Vendeur | `/client/orders/{id}` ou `/vendor/orders/{id}` |
| `order.refunded` | Client | `/client/orders/{id}` |
| `payment.failed` | Client | `/client/orders/{id}` |
| `incident.open` | Livreur/Porteuse | `/driver/missions/{id}` |
| `vendor.suspended` | Vendeur | `/vendor/profile` |
| `driver.suspended` | Livreur | `/driver/profile` |

### 7.2 Règles de navigation par deep-link
1. Si non connecté → rediriger vers login puis revenir au deep-link.
2. Si le deep-link est pour un **autre contexte** que l'actif → proposer la bascule de mode puis exécuter si autorisé (sinon 403 propre).
3. Les états "loading" doivent être gérés à l'arrivée.

### 7.3 Côté notification
- Push (FCM) : titre + corps + `data` (type + id)
- In-app : liste dans écran Notifications
- Email/SMS : seulement pour les cas retenus (J130)

## 8. Critères de validation (J25)
- [ ] Bibliothèque de composants partagés définie (noms réutilisables)
- [ ] Conventions d'erreur + états vides appliquées à tous les écrans
- [ ] Table des badges couleurs exhaustive
- [ ] Table des deep-links complète (tous les événements J128)
- [ ] Confirmations requises identifiées pour les actions irréversibles