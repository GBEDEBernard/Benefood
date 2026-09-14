# J12 — Droits d'annulation

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** Validé — **Source :** Plan directeur V1.2, Phase 02, J12

---

## 1. Objet

Définir les conditions, acteurs autorisés, délais, conséquences financières et notifications pour les annulations de commande.

## 2. Principes généraux

1. **Une annulation est toujours motivée** (motif obligatoire avant exécution).
2. Une annulation laisse une trace complète : auteur, date, motif, décision, conséquence financière, notifications.
3. Toute annulation **après paiement** passe par la détermination automatique du remboursement (total / partiel / nul) selon les règles ci-dessous.
4. Le statut `cancelled` est un état terminal (sauf passage à `refunded` si remboursement exécuté).

## 3. Matrice des annulations par acteur et par statut

| Statut commande | Client | Vendeur | Porteuse | Livreur |
|-----------------|--------|---------|----------|---------|
| `draft` | ✅ libre | ❌ | ❌ | ❌ |
| `awaiting_payment` | ✅ libre | ❌ | ✅ | ❌ |
| `paid` | ✅ (avant préparation) | ✅ (avec motif) | ✅ | ❌ |
| `accepted` | ✅ (avec frais potentiels) | ✅ (avec motif) | ✅ | ❌ |
| `preparing` | ✅ (avec frais) | ✅ (avec motif) | ✅ | ❌ |
| `ready` | ✅ (avec frais) | ✅ (avec motif) | ✅ | ❌ |
| `assigned` | ✅ (avec frais) | ❌ | ✅ | ❌ |
| `picked_up` | ❌ (sauf incident) | ❌ | ✅ (incident) | ❌ |
| `in_delivery` | ❌ (sauf incident) | ❌ | ✅ (incident) | ❌ |
| `delivered` | ❌ (→ réclamation/rétractation) | ❌ | ✅ (exception qualité) | ❌ |

## 4. Conditions par acteur

### 4.1 Annulation par le client

| Cas | Condition | Remboursement | Frais |
|-----|-----------|---------------|-------|
| Avant paiement (`draft`, `awaiting_payment`) | Aucune | Aucun (rien payé) | — |
| Après paiement, avant `accepted` | Aucune | **Total** | Aucun |
| Entre `accepted` et `ready` | Motif obligatoire | **Total** si préparation non débutée ; **partiel** si préparation avancée (frais de préparation, valeur configurable) | Coupe : frais de préparation éventuels |
| Après `assigned` | Motif obligatoire | **Total / partiel** selon avancement ; **frais d'annulation** possibles (configurable) | Frais d'annulation possibles |
| Après `picked_up` | Uniquement incident déclaré | Partiel (selon règles incident) | Selon règles incident |

> Valeurs par défaut à verrouiller : **frais de préparation = X**, **frais d'annulation après affectation = Y**, **durée de rétraction = Z minutes** (à valider par la porteuse dans le back-office).

### 4.2 Annulation par le vendeur

| Cas | Condition | Remboursement |
|-----|-----------|---------------|
| Refus de commande (`paid`) | Motif obligatoire (article indisponible, vendeur fermé, erreur de tarif…) | **Total** (100 % au client) |
| Annulation en cours de préparation | Motif obligatoire (rupture stock, impossibilité de livrer…) | **Total** (100 %) |
| Annulation après affectation | Non autorisé (sauf incident validé par porteuse) | — |

### 4.3 Annulation par la porteuse

- Autorise l'annulation à tous les statuts (en tout cas d'incident ou de non-respect des règles métier).
- Décide du taux de remboursement : total, partiel ou nul.
- Motif obligatoire.

### 4.4 Livreur

- Le livreur **ne peut pas annuler** une commande. Il peut **décliner** une course non acceptée et déclarer un **incident** après acceptation (impossible à livrer, vendeur indisponible…) qui déclenche une gestion par la porteuse (réaffectation ou annulation).

## 5. Conséquences financières d'une annulation

### 5.1 Si la commande était **payée**
1. **Remboursement client** : total ou partiel selon la matrice du point 4.
2. **Commission Béninfood** : la commission n'est pas due si la commande est annulée avant le service final. Si la commission était déjà comptabilisée, elle est **contre-passée** (écriture négative) dans le journal financier.
3. **Part vendeur** : la part vendeur dégagée est annulée/ajustée sur les ventes réellement livrées.
4. **Livraison** : si la livraison a été facturée et n'a pas eu lieu, la part livreur n'est pas due ; s'il y a eu course partielle, une dédommagement éventuel est décidé par la porteuse.

### 5.2 Si la commande était **non payée**
- Rien à rembourser. Libération des stocks réservés.

### 5.3 Remboursement partiel
- Le montant réellement remboursé est calculé côté serveur (jamais côté mobile).
- Un remboursement partiel est appliqué par la passerelle (Kkiapay) si techniquement supporté, sinon par virement manuel tracé.

## 6. Workflow d'annulation

```
1. Événement déclencheur (client / vendeur / porteuse) + motif obligatoire
2. Validation des règles par un Service métier (state machine + policy)
3. Enregistrement statut 'cancelled' + motif + auteur + date (historique)
4. Détermination automatique du remboursement (total / partiel / nul)
5. Si remboursement :
     - création d'une demande de remboursement
     - exécution (Kkiapay si dispo, sinon manuel tracé)
     - passage à 'refunded' si succès
6. Contre-passée commission / parts le cas échéant (J14)
7. Libération des stocks réservés
8. Notifications à toutes les parties
9. Audit complet
```

## 7. Notifications obligatoires

| Événement | Destinataires |
|-----------|---------------|
| Annulation demandée | Client + Vendeur (+ Livreur si impliqué) |
| Remboursement initié | Client |
| Remboursement effectué | Client + Vendeur (+ Porteuse si partiel/exception) |
| Incident déclaré par livreur | Porteuse + Client |

## 8. Critères d'acceptation

- [ ] `cancelled` / `refunded` accessibles uniquement depuis les statuts autorisés (policy serveur)
- [ ] Motif obligatoire pour toute annulation
- [ ] Remboursement déterminé automatiquement (total/partial/none) et audité
- [ ] Contre-passées commission/parts correctes au journal financier
- [ ] Test des scénarios : avant paiement, après paiement, préparation, après affectation
- [ ] Notifications envoyées à toutes les parties