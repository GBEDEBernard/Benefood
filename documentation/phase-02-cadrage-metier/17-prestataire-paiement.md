# J17 — Prestataire de paiement (décision)

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** Décision validée — **Source :** Plan directeur V1.2, Phase 02, J17
**Décision :** ✔ **FedaPay** (validation le 14/09/2026)

---

## 1. Décision

| Critère | Choix |
|---------|-------|
| **Prestataire retenu** | **FedaPay** |
| Mot de passe d'accès | Comptes sandbox à créer par la porteuse |
| Abstraction | Interface `PaymentGateway` (réversible) — J87 |
| Monnaies | XOF (et FCFA si supporté) |
| Moyens | Mobile money (MTN MoMo, Moov Money, etc.) principalement |

## 2. Justification du choix

1. **FedaPay est une passerelle béninoise** (Bénin) — alignée avec la cible Béninfood (Benin food) et le marché primaire.
2. **Mobile money natif** : MTN MoMo / Moov Money très répandus au Bénin.
3. **Simplicité d'intégration** : API REST, webhooks, link de paiement rapide — adaptée à une V1.
4. Remboursements gérés côté tableau de bord marchand (J12/J14), tracés côté Béninfood.
5. Disponibilité d'une **bibliothèque PHP officielle** (`fedapay/fedapay-php`) pour l'écosystème Laravel.

## 3. Alternative (garde-fou)

- **Kkiapay** reste l'alternative documentée (Bénin, mobile money).
- Grâce à l'interface `PaymentGateway` (J87), le fournisseur est **réversible** sans réécrire la logique métier.

## 4. Éléments à valider AVANT le développement du module (Phase 11)

| Élément | Statut |
|---------|--------|
| Comptes sandbox FedaPay créés | ☐ |
| Clés API sandbox (public + secret) récupérées en toute sécurité | ☐ |
| Grille tarifaire réelle (frais par transaction, % ET fixe) | ☐ |
| Remboursements via tableau de bord marchand (pas d'API) | ☐ Validé en principe |
| Webhooks : URL de callback, signature, format du payload | ☐ |
| **Mode de reversement / répartition disponible** (vers les wallets vendeurs/livreurs) | ☐ |
| Sandbox sur matériel réel (vrai numéro de test) | ☐ |
| Délai de règlement (T+X) des fonds vers Béninfood | ☐ |

> ⚠️ **RÈGLE (J17) :** aucun développement d'intégration « codé en dur » d'un fournisseur ne doit commencer tant que les comptes sandbox et la grille tarifaire ne sont pas confirmés. Le code reste derrière l'interface `PaymentGateway`.

## 5. Mode de reversement cible

Le modèle financier (J14) prévoit que Béninfood **collecte** via FedaPay puis **reverse** :
- part vendeur → wallet vendeur → payout ;
- part livreur → compte livreur ;
- commission → Béninfood.

Le mode **exact de reversement disponible** chez l'agrégateur (API payout vers numéro MM ? fréquence ?) doit être confirmé dans cette tâche avec l'équipe FedaPay, et la répartition des frais (qui paie les frais d'agrégateur) verrouillée avant la Phase 10 (paiement).

## 6. Règles techniques à respecter

1. Clés stockées uniquement en variables d'environnement côté Laravel (jamais en clair, jamais dans Flutter/Git).
2. Webhook protégé : vérification de signature ; endpoints idempotents.
3. Montant toujours dominé par le serveur (J94).
4. Sandbox pour le développement, environnement production séparé.

## 7. Critères d'acceptation

- [ ] Décision écrite validée (ce document)
- [ ] Interface `PaymentGateway` prévue (J87)
- [ ] Grille tarifaire + mode de reversement confirmés par FedaPay
- [ ] Comptes sandbox référencés en sécurité
- [ ] Règle « pas d'intégration avant validation » respectée