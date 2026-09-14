# J25 — Validation des maquettes et verrouillage UI

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 03, J25

---

## 1. Objet

Valider les maquettes (J19-J24) et **verrouiller la version UI** avant toute implémentation lourde (Phase 04+ et Phases 07-17).

## 2. Check-list de validation par livrable

### 2.1 Parcours Auth & contexte (J19)
- [ ] Registre complet : coordonnées → rôles → OTP → succès
- [ ] Login + reset mot de passe
- [ ] Sélecteur de contexte multi-rôles + bascule de mode
- [ ] Restauration de session au splash

### 2.2 Parcours Client (J20)
- [ ] Accueil, recherche, boutique, produit, panier (mono-vendeur)
- [ ] Adresse + zone + quote + paiement (machine à états Kkiapay)
- [ ] Suivi/historique/reclamation/avis
- [ ] Cas limites : zone non desservie, vendeur fermé, stock 0, multi-vendeur

### 2.3 Parcours Vendeur (J21)
- [ ] Onboarding/activation (J09)
- [ ] Boutique + horaires + statut ouvert/fermé
- [ ] Produits/photos/prix/disponibilité
- [ ] Commandes (accepter/refuser/préparer/prêt)
- [ ] Revenus (J13/J14)

### 2.4 Parcours Livreur (J22)
- [ ] Activation indépendant + Béninfood
- [ ] Disponibilité online/offline
- [ ] Mission : proposée→acceptée→collecte→livrée (+ preuve)
- [ ] Incidents, gains, historique

### 2.5 Back-office porteuse (J23)
- [ ] Dashboard KPI + pilotage vendeurs/livreurs/commandes
- [ ] Commissions, zones/tarifs, paiements/remboursements, réclamations
- [ ] Audit + rapports ; aucun accès DB

### 2.6 Design system & composants (J24)
- [ ] Bibliothèque de composants partagés figée
- [ ] Conventions erreurs/états vides/badges/confirmations
- [ ] Table des deep-links = celle des événements (J128)

## 3. Règles de verrouillage

1. Toute maquette déviante d'une décision Phase 02 (J08-J18) est à signaler **avant** validation.
2. Une fois J25 validé, les écrans servent de **référence fonctionnelle** : le développement de chaque écran doit s'y conformer.
3. Les libellés de copies (textes) seront centralisés (i18n français) pour éviter les écarts.
4. Les changements post-verrouillage passent par le backlog UI (ticket + mazéro d'impact).

## 4. Livrables de sortie de phase

| # | Livrable | Fichier |
|---|----------|---------|
| 1 | Maquette fonctionnelle auth | `19-auth-contexte.md` |
| 2 | Maquette fonctionnelle client | `20-parcours-client.md` |
| 3 | Maquette fonctionnelle vendeur | `21-parcours-vendeur.md` |
| 4 | Maquette fonctionnelle livreur | `22-parcours-livreur.md` |
| 5 | Maquette fonctionnelle back-office | `23-back-office-porteuse.md` |
| 6 | Design system + deep-links | `24-composants-communs.md` |
| 7 | Validation officielle | Ce document (J25) |

## 5. Validation officielle

| Rôle | Nom / Visa | Date |
|------|-----------|------|
| Porteuse (validation métier) | ________ | ____ |
| Développeur (faisabilité) | ________ | ____ |

> ⚠️ Sans visa de validation J25 (ci-dessus), on ne démarre **pas** l'implémentation lourde des écrans (Phases 07-17).

## 6. Critères de sortie de phase 03

- [ ] J19-J24 rédigés et revus
- [ ] J25 visé par la porteuse
- [ ] Documents versionnés (branch `develop`)