# J08 — Formalisation des acteurs

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** Validé — **Source :** Plan directeur V1.2, Phase 02, J08

---

## 1. Axe d'application

Une seule application Flutter multi-rôles (Client / Vendeur / Livreur) + API Laravel `/api/v1` + back-office web pour la porteuse.

## 2. Liste des acteurs

| # | Acteur | Description | Expérience mobile | Back-office web |
|---|--------|-------------|-------------------|-----------------|
| A1 | **Porteuse** | Propriétaire de la plateforme Béninfood. Définit les règles métier (commissions, zones, tarifs), valide les vendeurs et livreurs, gère les remboursements et litiges. | Aucune (gère via back-office) | ✅ Accès complet métier |
| A2 | **Administrateur technique** | Super admin technique Béninfood. Gère les accès, la technique, les exceptions et le support de niveau 2. | Aucune | ✅ Accès technique + métier |
| A3 | **Vendeur** | Commerçant (boutique) qui propose des produits à la vente sur la plateforme. | ✅ Mode Vendeur | ❌ |
| A4 | **Client** | Consommateur qui parcourt, commande et paie. | ✅ Mode Client | ❌ |
| A5 | **Livreur indépendant** | Prestataire externe (hors Béninfood) qui effectue des livraisons en tant que prestataire. | ✅ Mode Livreur | ❌ |
| A6 | **Livreur Béninfood** | Travailleur salarié/contractuel de Béninfood qui effectue des livraisons. | ✅ Mode Livreur | ❌ |

## 3. Règles transversales

1. **Un utilisateur peut cumuler plusieurs rôles** (ex : Client + Vendeur). Il conserve un compte et une session uniques.
2. Le mobile active un **contexte actif** (Client, Vendeur ou Livreur) qui ne constitue **jamais** une autorisation de sécurité. Les droits sont vérifiés côté serveur via RBAC + policies.
3. La **porteuse** n'a **aucun accès direct à la base de données**. Tout passe par le back-office.
4. L'**administrateur technique** peut accéder aux logs, aux exceptions et à la supervision, mais les actions métier sensibles sont auditées.

## 4. Droits et permissions par acteur

### A1 — Porteuse (back-office)
- Dashboard KPI (commandes, CA, commissions, vendeurs, livreurs, remboursements)
- Gestion des vendeurs : consulter, valider, suspendre, modifier
- Gestion des produits et boutiques
- Gestion des clients et livreurs
- Gestion des commandes (filtres + actions autorisées)
- Gestion des taux de commission et historique
- Gestion des zones et tarifs de livraison
- Gestion des paiements, transactions, remboursements et rapprochement
- Gestion des réclamations et litiges
- Export des rapports
- **Interdit :** accès direct à la DB, modification de code, accès aux secrets techniques

### A2 — Administrateur technique
- Tous les droits de la porteuse
- Gestion des comptes administrateurs
- Gestion des configurations techniques (stockage, emails, FCM, paiement)
- Accès aux logs / audit / monitoring
- Support niveau 2

### A3 — Vendeur
- Créer et gérer sa boutique (nom, description, images, adresse, horaires, statut ouvert/fermé)
- Créer, modifier, activer/désactiver son catalogue
- Gérer son stock / disponibilité
- Recevoir les commandes, accepter/refuser, marquer en préparation, marquer prête
- Consulter son historique et ses revenus
- Voir les annulations et leurs motifs
- **Interdit :** voir les données des autres vendeurs, modifier les montants d'une commande, voir les données financières détaillées des autres acteurs

### A4 — Client
- Parcourir, rechercher, filtrer
- Créer son panier (mono-vendeur par commande)
- Commander et payer
- Suivre sa commande
- Consulter son historique
- Déposer une réclamation / avis
- **Interdit :** modifier un montant, annuler après les délais autorisés sans conséquence financière, accéder aux données d'autres clients

### A5 — Livreur indépendant
- Candidater avec documents
- Passer en disponibilité online/offline
- Recevoir des affectations de course
- Accepter/refuser une course
- Réaliser collecte + livraison + preuve
- Déclarer un incident
- Consulter son historique et ses gains

### A6 — Livreur Béninfood
- Mêmes droits fonctionnels que A5, mais l'activité (disponibilité, affectation) est gérée par Béninfood
- Modèle de rémunération différent (voir J14)

## 5. Matrice d'accès

| Matrice | Porteuse | Admin tech | Vendeur | Client | Livreur indép. | Livreur Béninfood |
|---------|----------|------------|---------|--------|----------------|-------------------|
| App Flutter | — | — | ✅ | ✅ | ✅ | ✅ |
| Back-office | ✅ | ✅ | — | — | — | — |
| API `/api/v1` | ✅ (via back-office) | ✅ | ✅ (mobile) | ✅ (mobile) | ✅ (mobile) | ✅ (mobile) |

## 6. Critères d'acceptation

- [ ] Chaque acteur a des droits distincts et limités
- [ ] Les règles transversales (contextes, cumul de rôles, RBAC) sont écrites
- [ ] La porteuse n'a pas d'accès direct à la DB
- [ ] Le document est validé et versionné