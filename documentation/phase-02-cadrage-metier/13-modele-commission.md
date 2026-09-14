# J13 — Modèle de commission

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** Validé — **Source :** Plan directeur V1.2, Phase 02, J13

---

## 1. Objet

Définir le modèle de commission de la plateforme : taux, base de calcul, activation, historique et exceptions.

## 2. Principe fondamental

> **RÈGLE FINANCIÈRE CLÉ :** la commission est calculée, appliquée et **figée côté serveur**. Chaque commande stocke **le taux appliqué** et **le montant de commission** dans son snapshot financier. Les changements de taux ultérieurs n'affectent jamais les commandes déjà payées.

## 3. Paramètre global

- La porteuse définit un **taux de commission global** (%). Exemple de valeur de référence : **10 %** (à valider par la porteuse).
- Le taux est géré depuis le back-office (pas de code à déployer pour le modifier).
- Le taux peut être **neutre ou activé** avec une **date d'effet**.

## 4. Base de calcul de la commission

| Élément | Règle |
|---------|-------|
| Base de calcul | **Sous-total HT des articles éligibles** (montant commande hors frais de livraison et hors frais de paiement) |
| Articles exclus | Aucun par défaut (configurable par exceptions) |
| Frais de livraison | **Exclus** de la base de commission |
| Frais de paiement | **Exclus** de la base de commission |
| Remises | Si une remise produit existe, la commission se calcule sur le montant **après remise** |

$$ \text{Commission}_{commande} = \text{Base}(\text{sous-total éligible}) \times \text{taux\_appliqué} $$

## 5. Cycle de vie du taux de commission

### 5.1 Entité

`commission_rules` (ou `commission_rates`) :
| Champ | Description |
|-------|-------------|
| `rate` | Taux en pourcentage (ex. 10.00) |
| `effective_from` | Date d'effet (date à laquelle le taux s'applique) |
| `effective_to` | Nullable — date de fin si désactivé |
| `is_active` | Booléen : taux actif / inactif |
| `created_by` | Utilisateur (porteuse) qui a créé le taux |
| `notes` | Raison du changement |

### 5.2 Règles d'application

1. Au moment de la création de la commande payée, on choisit le taux **actif** dont la date d'effet est la plus récente **≤ date de la commande**.
2. Si plusieurs taux sont actifs : seul celui à la date d'effet la plus récente s'applique.
3. Le taux choisi est **figé dans `order_financials`** de la commande (snapshot) : `commission_rate` + `commission_amount`.
4. L'historique des taux est conservé même après désactivation (audit).

### 5.3 Cas d'exceptions

- Des **exceptions par vendeur** peuvent être définies par la porteuse (taux personnalisé pour un vendeur).
- Une exception est un objet : `vendor_id` + `rate` + dates d'effet. Elle **prime** sur le taux global.
- L'exception active doit être la plus récente **≤ date de commande**.
- La règle de snapshot s'applique de la même façon (l'exception appliquée est figée).

## 6. Instantané financier (ordre à date de commande)

Chaque commande `paid` enregistre (table `order_financials`) :
- `subtotal` — sous-total articles
- `discount` — remise éventuelle
- `delivery_fee` — frais de livraison
- `payment_fee` — frais de paiement éventuels
- `commission_base` — base de calcul (sous-total éligible après remise)
- `commission_rate` — taux appliqué (%)
- `commission_amount` — montant de commission
- `vendor_amount` — part vendeur
- `delivery_partner_amount` — part livreur
- `platform_amount` — part Béninfood
- `total_client` — total payé par le client
- `currency` — devise (XOF)
- `payment_reference` — référence kkiapay/txn id

## 7. Cas d'arrondis

- Les montants sont calculés en **centimes** (integer) côté serveur pour éviter les erreurs de floating point.
- L'arrondi se fait au centime le plus proche à chaque étape, de façon cohérente et reproductible.
- Règle : **arrondi demi-up** (0.5 XOF et plus → 1 XOF) appliqué au niveau de la commission et de la part vendeur.

## 8. Tests obligatoires (J106)

- [ ] Cas normal : taux 10 % sur sous-total 10 000 XOF → commission 1 000 XOF ; part vendeur 9 000 XOF
- [ ] Arrondis : sous-total 9 995 XOF, taux 10 % → 999,5 → 1 000 XOF
- [ ] Changement de taux : commande payée avant le changement → taux ancien figé
- [ ] Exception vendeur : vendeur A à 5 %, global à 10 % → commande vendeur A → 5 %
- [ ] Désactivation d'un taux : les nouvelles commandes utilisent le taux suivant le plus récent
- [ ] Remboursement : contre-passée commission (écriture négative) (J14)

## 9. Critères d'acceptation

- [ ] Taux géré en back-office sans déploiement
- [ ] Historique des taux conservé
- [ ] Snapshot taux + montant dans chaque commande payée
- [ ] Exceptions vendeur supportées
- [ ] Calculs testés (normal, arrondis, remboursements, changements de taux)