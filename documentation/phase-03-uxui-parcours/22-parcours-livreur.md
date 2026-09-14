# J22 — Maquette : Parcours Livreur

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 03, J22

---

## 1. Structure de navigation (mode Livreur)

```
BottomNavigation (4 onglets) :
├── Missions (actives / disponibles)
├── Historique
├── Gains
└── Profil
```
Header : statut de disponibilité (toggle Online/Offline) + notifications.

## 2. Flux d'activation du livreur (J10)

### 2.1 Livreur indépendant
```
Candidature (profil + docs) ➜ En validation ➜ Validé ➜ Actif ➜ Online
```
### 2.2 Livreur Béninfood
```
Compte créé par Béninfood ➜ Validé ➜ Actif ➜ Online
(le livreur voit son statut et peut se mettre Online)
```

## 3. Écrans détaillés

### 3.1 Profil & statut
| Bloc | Contenu |
|------|---------|
| Info perso | Nom, photo, téléphone |
| Statut compte | Badge (`candidate`, `pending_validation`, `active`, `suspended`…) + message |
| Documents | Liste + état (soumis / valide / à renouveler / refusé avec raison) |
| Type | « Livreur indépendant » ou « Livreur Béninfood » (affiché) |
| **Toggle Disponibilité** | Gros interrupteur **En ligne / Hors ligne** — visible et actif seulement pour `active` |

Règles (J10) : un livreur avec une course en cours ne peut pas passer hors ligne tant que la course n'est pas terminée (message d'info).

### 3.2 Mission (cartographie du flux)
```
Proposée ➜ Acceptée ➜ Collecte (chez vendeur) ➜ En livraison ➜ Livrée (+ preuve)
              │refus
              ▼
         retour pool (trace)
```
- **Courses disponibles** : liste des courses proposées par le système (selon affectation Phase 13) : origine (vendeur), destination (client), zone, montant de course, temps estimé
- **Actions** : Accepter / Refuser (confirmations, J24)
- Une course acceptée devient sa mission active (bloquante)

### 3.3 Mission active (grand écran)
| Zone | Contenu |
|------|---------|
| Carte | Repère vendeur + client + itinéraire |
| Étapes | Stepper visuel : Collecte → En route → Livrée |
| Boutons étape | « J'ai récupéré la commande » → « Commencer la livraison » → « Marquer livrée » |
| Preuve de livraison | Code de confirmation client / photo / signature (selon règle Phase 13) |
| Infos contact | Vendeur (téléphone appeler), Client (téléphone appeler) |
| Infos commande | N° , articles, adresses, note livreur éventuelle |
| Incident | Bouton « Déclarer un incident » (problème vendeur, impossible à livrer…) |

États :
- Collecte : suivi + confirmation pickup (non livré → incident si vendeur indisponible)
- En route : bouton aider, indications de localisation client
- Livrée : saisie preuve → succès → retour au pool

### 3.4 Historique
- Liste des missions : date, n° , zone, montant, statut (livré / refusé / incident / annulé)
- Filtres : aujourd'hui / semaine / mois / tout
- Détail mission : breakdown course (J14/J115)

### 3.5 Gains (livreur indépendant)
| Bloc | Contenu |
|------|---------|
| KPIs | Solde, gains du jour, gains de la semaine |
| Îlot de course | Détail d'une course (frais livraison → part livreur) selon J14 |
| Reversements | Liste des paiements/gains crédités (référence, date, montant) |
| Note | Bouton support composant incidents |

> Livreur Béninfood : onglet Gains simplifié — « Rémunéré par Béninfood » + historique indicatif, selon la décision de J14.

### 3.6 Incidents
- Formulaire : type (vendeur absent, adresse incorrecte, problème produit, impossible à livrer, autre), description, photos
- Résolution par la porteuse (statut : ouvert / en cours / clos)
- Historique des incidents

## 4. Notifications reçues (livreur)
- Nouvelle course proposée (push prioritaire + deep-link) — J24
- Rappel de délai de réponse
- Course annulée / réaffectée
- Incident clos
- Gain crédité

## 5. Règles UX transversales
- **Toggle Online/Offline** visible et persistant en haut (état d'ure immédiate)
- Timeout de réponse affiché pour chaque course proposée (compte à rebours)
- Un seul mission active à la fois — gros contraste quand une course est en cours
- Confirmations obligatoires : refus de course, incident, fin de course
- Mode carte + liste synchrone avec le statut

## 6. Critères de validation (J25)
- [ ] Candidature → activation → online testable sur maquette (indépendant + Béninfood)
- [ ] Flux complet : proposition → accept → pickup → deliver (+ preuve)
- [ ] Cas incidents / refus / impossibilité de livrer spécifiés
- [ ] Gains et reversements conformes à J14
- [ ] Toggle online/offline non destructif en course