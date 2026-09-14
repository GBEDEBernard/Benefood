# J14 — Répartition financière

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** Validé — **Source :** Plan directeur V1.2, Phase 02, J14

---

## 1. Objet

Définir la répartition de chaque paiement entre les acteurs : part vendeur, commission Béninfood, frais de livraison (part livreur), frais de paiement, remboursements et ajustements.

## 2. Équation fondamentale d'une commande

```
total_client = subtotal(articles) + delivery_fee + payment_fee (if any) - discounts
```

Répartition de la valeur :
```
vente_marchandise = subtotal - discount        → base de commission
commission_béninfood = commission_base × taux  → part Béninfood
part_vendeur = commission_base - commission_béninfood
frais_livraison     = delivery_fee             → part livreur (selon modèle ci-dessous)
frais_paiement      = payment_fee (si applicable, à la charge de qui ? → section 4)
```

> **Recommandation V1.2** : les **frais de paiement** (frais prélevés par l'agrégateur Kkiapay) peuvent être soit inclus dans la commission Béninfood, soit refacturés au client/vendeur selon le modèle validé. Par défaut : **Béninfood absorbe les frais d'agrégateur**, ils sont internalisés dans la commission. (À préciser dans J17 après obtention de la grille tarifaire réelle.)

## 3. Répartition par type de commande

### 3.1 Commande livrée (flux nominal)
| Poste | Qui reçoit | Mécanisme |
|-------|-----------|-----------|
| Paiement client (total) | Béninfood (compte collecteur Kkiapay) | encaissé via l'agrégateur |
| - commission Béninfood | Béninfood | déduite du flux |
| - part vendeur | Vendeur | crédit wallet vendeur (J103) / reversement |
| - part livreur (frais livraison) | Livreur | crédit compte livreur selon modèle (J115) |
| - frais agrégateur éventuels | (Béninfood) | internalisés si retenu |

### 3.2 Parts par statut de livraison
| Cas | Part vendeur | Commission Béninfood | Part livreur | Remboursement |
|-----|--------------|----------------------|--------------|---------------|
| Livré | ✅ pleine | ✅ pleine | ✅ pleine | — |
| Annulé avant paiement | — | — | — | — |
| Annulé après paiement (J12) | annulée/ajustée | contre-passée (si comptabilisée) | annulée / partielle selon cas | total/partiel |

### 3.3 Modèle de rémunération livreur
| Type livreur | Modèle retenu V1.2 |
|--------------|--------------------|
| Livreur indépendant | **À la course** : il perçoit tout ou partie du `delivery_fee` (selon modèle : 100 % du fee, ou revenue partage Béninfood). Valeur par défaut : **100 % du delivery_fee** au livreur indépendant. |
| Livreur Béninfood | **Salarié/contractuel** : rémunéré par Béninfood (salaire). Les `delivery_fee` encaissés restent à Béninfood ; le livreur Béninfood n'a pas de part « course » calculée dans le ledger (ou une part indicative tracée selon décision). |

> À valider par la porteuse : exactement le partage indépendant pour le livraison (100 / 80 / 70 %) et le comportement du livreur Béninfood.

## 4. Comptabilisation : journal financier immuable

Tous les mouvements sont enregistrés dans un **journal financier immuable** (append-only) :

| Événement | Débit | Crédit |
|-----------|-------|--------|
| Paiement client reçu | Encaissement (Béninfood) | — |
| Commission Béninfood due | — | Recette Béninfood |
| Part vendeur créditée | — | Compte vendeur |
| Part livreur créditée | — | Compte livreur |
| Remboursement | — | Client |
| Contre-passée commission (annulation) | Recette Béninfood (-) | — |
| Ajustement manuel (porteuse) | selon cas | — |

Règles :
1. Le journal est **append-only** ; on ne corrige jamais par UPDATE, on ajoute une écriture de correction.
2. Chaque écriture a : type, référence (commande/paiement/remboursement), montant, devise, sens, date, auteur/acteur système, statut.
3. Le **rapprochement** (J105) vérifie que la somme des mouvements concorde avec les flux de la passerelle.

## 5. Wallets / reversements

### 5.1 Wallet vendeur
- Chaque vendeur possède un **wallet** interne (solde courant).
- Les parts vendeur sont créditées sur le wallet.
- Le **reversement** (payout) est déclenché par la porteuse (ou selon un cycle configurable) ; opéré via le canal retenu (agrégateur si disponible, sinon virement bancaire/MM tracé manuellement).
- Chaque reversement est enregistré (`payouts`) et soustrait du wallet.

### 5.2 Wallet livreur
- Même principe pour les gains du livreur indépendant (J115).

> Si le modèle de reversement retenu ne nécessite pas de wallet (reversement direct à chaque commande), cette partie est simplifiée. Le **journal** reste toujours présent.

## 6. Reversements / remboursements / ajustements

### 6.1 Remboursement
1. Initié via le workflow J12.
2. Si Kkiapay supporte le refund : exécuté via l'API, référence de remboursement conservée.
3. Sinon : remboursement manuel (virement/MM) tracé dans le journal avec statut `pending` → `executed`.

### 6.2 Ajustement
- Saisi uniquement par la porteuse, motivé et audité (ex. erreur de calcul, litige).
- Enregistré comme écriture d'ajustement.

## 7. Snapshot dans `order_financials`

Voir J13 section 6 — la commande payée fige : subtotal, discount, delivery_fee, payment_fee, commission_base, commission_rate, commission_amount, vendor_amount, delivery_partner_amount, platform_amount, total_client, currency, payment_reference.

## 8. Rapprochement (J105)

Comparaison régulière :
- Flux côté agrégateur (relevés Kkiapay) ↔ paiements enregistrés ↔ écritures journal ↔ commandes.

## 9. Critères d'acceptation

- [ ] Équation §2 vérifiée pour chaque commande livrée (total = somme des parts)
- [ ] Journal financier immuable et complet
- [ ] Contre-passée correcte sur annulation/remboursement
- [ ] Wallet vendeur + reversements tracés (ou reversement direct selon modèle)
- [ ] Remboursements et ajustements audités
- [ ] Tests financiers (J106) : normaux, arrondis, remboursements, changements de taux