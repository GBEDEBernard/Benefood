# J21 — Maquette : Parcours Vendeur

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 03, J21

---

## 1. Structure de navigation (mode Vendeur)

```
Menu latéral (drawer) :
├── Tableau de bord
├── Boutique (infos, horaires, statut)
├── Produits
├── Commandes
├── Revenus
├── Profil / Paramètres
└── Bascule de mode (si multi-rôles) + Déconnexion
```
Header : nom boutique + badge statut (ouvert/fermé) + cloche notifications.

## 2. Flux d'activation du vendeur (J09 + Phase 07)

```
Onboarding (image texte) ➜ Infos légales ➜ Documents ➜ Config boutique
   ➜ Envoi validation ➜ État "En vérification" ➜ Validé ➜ Actif (boutique ouverte)
```
États visibles côté vendeur : `registered`, `pending_verification`, `verified`, `active`, `suspended`, `closed` — avec instructions à chaque étape.

## 3. Écrans détaillés

### 3.1 Tableau de bord
| Zone | Contenu |
|------|---------|
| KPIs cartes | Commandes du jour, en attente d'action, CA du jour, note moyenne |
| Actions rapides | Ajouter un produit / Modifier la boutique / Ouvrir-Fermer |
| Nouvelles commandes | Liste des commandes `paid` à traiter (boutons Accepter / Refuser) |
| Commandes récentes | Récap des derniers statuts |

### 3.2 Boutique
| Bloc | Contenu |
|------|---------|
| Infos | Nom, description, catégorie d'activité, images (logo + couverture) |
| Adresse | Localisation + villes/quarts desservis (zones — J56) |
| Horaires | Jours/plages horaires (ouvert/fermé), gestion des jours fériés (optionnel) |
| Statut | Toggle **Ouvert / Fermé temp** avec motif éventuel |
| Statut du compte | Badge (`suspended`, `pending_verification`, etc.) avec message |

### 3.3 Produits
- Liste produits : image, nom, prix, statut actif/inactif, stock, toggle dispo
- Bouton « Ajouter » et « Modifier »
- Formulaire produit : nom, description, catégorie, prix, unité (pièce/kg/pack), quantité/stock, photos (1 principale + secondaires), disponibilité, statut (actif/inactif)
- Plan d'édition : désactivation sans suppression ; changement de prix avec versioning pour gel commandes (J65/J66)
- État vide : « Aucun produit — Ajoutez votre premier produit »

### 3.4 Commandes
- Onglets : Nouvelles (`paid`) / En préparation (`preparing`) / Prêtes (`ready`) / Terminées (`delivered`) / Annulées (`cancelled`)
- **Détail commande** :
  - Lignes produits (snapshot)
  - Note client
  - Adresse de livraison + zone + frais
  - Montants (sous-total, TVA éventuelle, total) — lecture seule
  - Statut courant + boutons d'action du contexte
- **Actions vendeur** (selon J11) : Accepter (`paid`→`accept`), Refuser (`paid`→`cancelled`, motif obligatoire), Démarrer préparation (`accepted`→`preparing`), Marquer prête (`preparing`→`ready`)
- Minuterie de non-réponse : signal visuel si délai d'acceptation proche de la limite
- Bouton « Signaler un problème » (incident) vers la porteuse

### 3.5 Revenus
| Bloc | Contenu |
|------|---------|
| KPIs | Solde wallet, ventes validées, commission prélevée, en attente |
| Historique | Liste des écritures (type, commande, montant, date) |
| Reversements | Liste des payouts (statut, montant, date, référence) |
| Détail commande | Breakdown : base, taux commission, part vendeur, livraison (J13/J14) |
| Extras | Export CSV (mois) |

### 3.6 Profil / Paramètres
- Infos de contact (téléphone, email), mode de paiement de reversement (bank/MM)
- Mot de passe, langue, notifications (préférences : nouvelles commandes, annulations, paiements)
- Bascule de mode (si multi-rôles), déconnexion

## 4. Notifications reçues (vendeur)
- Nouvelle commande payée (`paid`) → push haute priorité + deep-link détail commande (J24/J166)
- Annulation par client / porteuse
- Remboursement
- Suspension de compte
- Rapprochement / payout effectué

## 5. Règles UX transversales
- Vivid highlight sur les commandes à traiter (badge « À traiter »)
- Cœurs « ouvert/fermé » visibles en continu
- Blocage clair des actions non autorisées (ex. un vendeur suspendu ne peut pas éditer)
- Confirmations pour indésirables : fermeture temporaire, refus commande, désactivation produit (J24)

## 6. Critères de validation (J25)
- [ ] Jeu complet d'activation (inscription → active) fiche roadmap
- [ ] Gestion produits & photos complète
- [ ] Traitement complet des commandes (accepter/refuser/préparer/prêt)
- [ ] Revenus affichés selon J13/J14 (breakdown clair)
- [ ] États suspendus / fermés bloquants correctement spécifiés