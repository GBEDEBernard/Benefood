# J23 — Maquette : Back-office Porteuse

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 03, J23

> Web (responsive 1200px+), consomme la même API `/api/v1`. La porteuse **n'a pas d'accès direct à la DB**.

## 1. Navigation principale (sidebar gauche)

```
Dashboard
Vendeurs
Clients
Livreurs
Commandes
Produits & Boutiques
Commissions
Livraison (Zones & Tarifs)
Paiements (Transaction + Remboursements)
Réclamations & Litiges
Paramètres (règles métier)
Audit & Rapports
```

## 2. Écrans détaillés

### 2.1 Dashboard (KPIs)
| Zone | Contenu |
|------|---------|
| Cartes KPI | Commandes (jour/mois), CA (jour/mois), commissions, vendeurs actifs, livreurs en ligne, remboursements en attente |
| Trend | Graphique CA / commandes (7j / 30j) |
| Alertes | Commandes en attente d'action, incidents livreurs, réclamations ouvertes, échecs de payouts |
| Table | Dernières commandes (n° , client, vendeur, total, statut) |

### 2.2 Vendeurs
- Table : nom, IFU, boutique, statut, CA, note, date de création
- Filtres : statut, recherche
- **Détail vendeur** : infos, documents (visualisables), boutique, produits, commandes, reversements
- **Actions** : approuver, vérifier, activer, suspendre (motif obligatoire), fermer, modifier
- Historique des statuts (J09) + audit

### 2.3 Clients
- Table : nom, téléphone, email, nb commandes, total dépensé, date inscription
- Détail : profil, adresses, commandes, réclamations
- Actions : suspends éventuellement (limitée à la sécurité), READ mostly

### 2.4 Livreurs
- Table : nom, type (indépendant/Béninfood), statut, disponibilité (en ligne), nb courses, note
- **Détail** : documents, courses, gains, incidents
- **Actions** : valider dossier, activer, suspendre, fermer, changement de type

### 2.5 Commandes
- Table : n° , date, client, vendeur, zone, total, statut, paiement
- Filtres : statut (tous, J11), période, vendeur, zone, montant
- **Détail commande** : snapshot produit, adresse, breakdown financier (J14), timeline statuts + auteur, paiement/refund associés
- **Actions autorisées** : annuler (motif + décision remboursement — J12), valider un remboursement

### 2.6 Produits & Boutiques
- Boutiques : table (vendeur, statut ouvert/fermé, catégorie, note)
- Produits : recherche globale, vue approbation/modération (hashélé), désactiver produit, inspection photos
- La porteuse **ne modifie pas** les prix directement (sauf exception tracée)

### 2.7 Commissions
- **Taux actuel** : affiché + historique (`commission_rates`)
- Action : créer un nouveau taux avec **date d'effet** (J13), exceptions par vendeur (J13)
- Table des exceptions : vendeur, taux, période
- Prévisualisation : « si taux X, commission sur commande type »

### 2.8 Livraison (Zones & Tarifs)
- Liste zones : nom, ville, actif/inactif
- Créer/modifier/activer/désactiver une zone + géojeton (quartiers)
- **Tarifs** : par zone (global) + par vendeur (spécifique) avec dates d'effet (J15)
- Indicateur : « zones sans tarif » (vendeurs sans couverture de livraison)

### 2.9 Paiements
- Transactions : référence, commande, montant, statut (J16), agrégateur, webhooks reçus
- **Remboursements** : liste (commande, montant, statut, canal) + action « initier », « confirmer », « manuel »
- **Rapprochement** (J105) : tableau comparatif paiements système vs agrégateur, identifiants d'écart
- Bouton « Exporter » (CSV/Excel)

### 2.10 Réclamations & Litiges
- File d'attente : réclamations ouvertes (client/livreur)
- **Détail** : type, description, photos, commande, décision
- Actions : répondre, classer sans suite, annuler (↔ J12), rembourser partiellement, escalate
- Statuts : ouvert / en cours / clos

### 2.11 Paramètres (règles métier)
| Paramètre | Entrée | Référence |
|-----------|--------|-----------|
| Taux de commission global | % + date d'effet | J13 |
| Deadline de paiement | minutes | J16 |
| Délai de réponse vendeur | minutes | J11 |
| Délai de réponse livreur | secondes | J10 |
| Frais de préparation / d'annulation | montant | J12 (section G J18) |
| Durée rétraction client | minutes | J12 |
| Part livreur indépendant | % du delivery_fee | J14 |

### 2.12 Audit & Rapports
- **Audit** : filtres sur `audit_logs` (acteur, action, entité, date) — lecture seule
- **Rapports** : CA par vendeur, commissions par période, livraisons par zone, remboursements
- Export PDF/CSV ; programmation éventuelle (cron)

## 3. Règles UX transversales
- Chaque **action sensible** (suspendre, fermer, rembourser, modifier taux) : modal de confirmation + motif obligatoire + reçu d'audit
- Tables : pagination + recherche + filtres ; dense, en-têtes fixes
- Les statuts sont des badges colorés codés (vert actif, orange en attente, rouge suspendu/fermé)
- L'interface est **lecture seule pour la plupart des champs métier** (la porteuse pilote, elle n'édite pas les prix ni les montants directement)
- Responsive : sidebar rétractable sur tablettes

## 4. Critères de validation (J25)
- [ ] Dashboard KPI cohérent avec J14 (CA, commissions)
- [ ] Actions vendeurs/livreurs (valider, suspendre) avec motifs + audit
- [ ] Gestion commissions/zones sans code (J13/J15/J74)
- [ ] Remboursements + rapprochement tracés
- [ ] Aucun accès direct DB ; rapports exportables