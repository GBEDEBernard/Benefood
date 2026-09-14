# J20 — Maquette : Parcours Client

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 03, J20

---

## 1. Structure de navigation (mode Client)

```
BottomNavigation (5 onglets)
├── Accueil
├── Recherche
├── Panier (badge quantité)
├── Commandes
└── Profil
```
Header commun : barre de recherche (Accueil), notifications (cloche), sélecteur de mode (si multi-rôles).

## 2. Flux global du parcours

```
Accueil ──▶ Recherche / Catégories ➜ Boutique ➜ Produit ➜ Panier
   └──────────▶ Adresse ➜ Livraison (zone) ➜ Récap + Paiement ➜ Paiement Kkiapay
                                                                   │
        Suivi (statuts) ◀── Confirmation ─────────────────────────┘
        Historique ➜ Réclamation / avis
```

## 3. Écrans détaillés

### 3.1 Accueil
| Zone | Contenu |
|------|---------|
| Header | Logo, barre de recherche (je push), panier, notifications |
| Bannières | Promotionnelles (manageables par la porteuse, optionnel) |
| Catégories | Grille horizontale de catégories (icônes) |
| Sélection ville/zone | Chip ville actuelle + adapter delivery (accès au changement) |
| Vendeurs en vedette | Cartes horizontal scroll (boutique, note, temps estimé) |
| Produits populaires | Liste verticale |

### 3.2 Recherche / Filtres
- Champ de recherche plein écran (dans le header)
- Résultats : produits + vendeurs mélangés ou onglets (« Produits » / « Boutiques »)
- Filtres : catégorie, tranche de prix, livraison dispo, distance/zone
- États vides : « Aucun résultat », suggestions, historique de recherche récent

### 3.3 Catégories
- Grille 2 colonnes (icône + nom)
- Tap → liste produits de la catégorie (avec filtres)
- Sous-catégories si implémentées (selon Phase 08 / J61)

### 3.4 Fiche Boutique
| Bloc | Contenu |
|------|---------|
| Hero | Image de couverture, nom, note, badges (ouvert/fermé, distance, temps) |
| Info | Description, horaires, adresse, zones desservies |
| Produits | Liste produits (image, nom, prix, badge dispo/épuisé, bouton +) |
| CTA | Bouton flottant « Voir le panier » si panier actif pour ce vendeur |

Règles panier (J15/J80) : **panier mono-vendeur** — ajouter un produit d'un autre vendeur déclenche un dialogue « Quel est votre panier ? » (réinitialiser / rejoindre l’autre vendeur / annuler).

### 3.5 Fiche Produit
| Bloc | Contenu |
|------|---------|
| Galerie | 1 image principale (zoom) + miniatures |
| Infos | Nom, description, prix, unité, disponibilité + stock (épuisé → bouton désactivé) |
| Quantité | Stepper − / + , valeur maxi = stock/vitrine |
| CTA | « Ajouter au panier » (primaire) ; « Commander » (accès rapide au checkout) |
| Boutique | Lien retour fiche boutique |

### 3.6 Panier
- Liste des lignes : image, nom, prix unitaire, quantité, sous-total ligne, suppression
- Récap basal : sous-total
- Note / instruction pour le vendeur (optionnel)
- CTA « Passer au paiement » (dim/sub) → checkout
- État vide : « Votre panier est vide » + CTA « Explorer »
- Règles : mise à jour des quantités en temps réel, recalcul serveur (quote) à chaque changement

### 3.7 Adresse de livraison
- Listes : mes adresses enregistrées + « Ajouter »
- Nouvelle adresse : libellé (ex. Maison/Bureau), quartier (sélecteur de zone), ville, adresse détaillée, repère, coords GPS (optionnel via géoloc, J173+)
- Sélection zone → tarif de livraison (J15)
- Blocage si zone non desservie/inactive : message + suggestion autre zone

### 3.8 Livraison (choix)
| Composant | Détail |
|-----------|--------|
| Mode livraison | « Livraison par coursier » (défaut V1.2) |
| Récepteur | Client / Autre personne (nom + téléphone) |
| Créneau | Estimé (temps de préparation + livraison) — optionnel V1 |
| Récap livraison | Quartier, frais, référence zone |

### 3.9 Récapitulatif + Quote
- Lignes produits (snapshot à confirmer)
- Sous-total
- Frais de livraison (zone)
- Total client
- **Aucun calcul client** : montants récupérés via `POST /checkout/quote` (serveur)
- CTA « Payer » → ouvre le paiement

### 3.10 Paiement (Kkiapay)
- Webview/flow Kkiapay (lien serveur — J16/J17)
- États : pending, succès, échec, expiration, annulation
- Succès → écran confirmation + push
- Échec → retour récap, possibilité de réessayer (deadline 15 min)

### 3.11 Suivi de commande
- Timeline verticale des statuts (J11) avec date/heure
- Statut courant + prochaines étapes
- Boutons contextuels : « Annuler la commande » (si autorisé — J12), « Déclarer un incident/problème »
- Infos livreur (nom, téléphone) une fois affecté
- Preuve de livraison (code) quand livrée
- CTA final : « Noter la commande » / « Laisser un avis »

### 3.12 Historique
- Liste commandes (n° , date, vendeur, total, statut)
- Filtres : tous / en cours / livrées / annulées / remboursées
- Tap → détail commande

### 3.13 Réclamation / Avis (Phase 14/15)
- Formulaire réclamation : type (problème produit, livraison, paiement, divers), motif, description, photos
- Suivi de la réponse de la porteuse
- Avis produit : note (1-5) + commentaire
- Un avis n'est possible que sur une commande livrée

## 4. Règles UX transversales
- **États vides** (J24) partout : panier, recherche, historique
- **Loading** : skeletons (liste) et spinners (actions)
- **Erreurs réseau** : bannière retry + mode hors-ligne minimal (J24)
- **Badge panier** : somme des quantités
- **Retour** : navigation Android back cohérente

## 5. Critères de validation (J25)
- [ ] Parcours complet Accueil → Paid → Suivi → Livré testé sur maquette
- [ ] Cas zone non desservie / vendeur fermé / stock 0 / multi-vendeur gérés
- [ ] Snapshot des montants 100 % serveur (aucun calcul client)
- [ ] États vides et machine paiement (succès/échec/expiration) spécifiés