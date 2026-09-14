# J15 — Modèle de livraison par zones

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** Validé — **Source :** Plan directeur V1.2, Phase 02, J15

---

## 1. Objet

Définir le modèle de tarification de la livraison par zones : zones, mode d'identification, tarifs, vendeurs concernés et conditions d'application.

## 2. Concepts

| Notion | Définition |
|--------|------------|
| **Zone de livraison** | Périmètre géographique (quartier, secteur, arrondissement, commune) desservi avec un tarif. |
| **Tarif de zone** | Montant de livraison appliqué pour une zone, défini par la porteuse. |
| **Zone inactive** | Zone non desservie provisoirement (aucune commande possible vers cette zone). |
| **Zone inconnue** | Adresse client ne correspondant à aucune zone active → la commande est bloquée à l'étape adresse. |

## 3. Mode d'identification de zone

Le mode retenu doit être simple et robuste en V1.2 :

- **Mode retenu : quartier/secteur déclaré + vérification par distance.** Le client choisit son quartier (liste issue des zones), l'adresse est saisie, et la zone est confirmée. En cas de doute, la distance entre valeurs retenues est évaluée.

Options complémentaires (à consolider à la Phase 09) :
| Mode | Description | Retenu ? |
|------|-------------|----------|
| Par quartier/secteur | Liste des zones couvrant la ville | ⭐ (recommandé) |
| Par distance | Tarif dégressif selon distance (ex. boucle par km) | Option |
| Par combinaison | Zone principale + sur-tarif si hors périmètre | Option |

> Décision à verrouiller à la Phase 09 (J70) : le mode exact. Le design ci-dessous est prévu pour supporter la **zone + tarif fixe par zone**.

## 4. Structure de données (règles cibles)

### 4.1 `delivery_zones`
| Champ | Description |
|-------|-------------|
| `name` | Nom de la zone (ex. « Cotonou - Zogbo », « Godomey ») |
| `city` | Ville |
| `is_active` | Zone active/inactive |
| `geo_data` | Géométrie (proxy : quartiers couverts) ou liste de quartiers |
| `sort_order` | Ordre d'affichage |

### 4.2 `delivery_rates`
| Champ | Description |
|-------|-------------|
| `zone_id` | Zone concernée |
| `vendor_id` | Nullable — si null, tarif global ; sinon tarif spécifique vendeur pour cette zone |
| `price` | Tarif (montant fixe) pour la zone |
| `effective_from` / `effective_to` | Période de validité |
| `is_active` | Actif/inactif |

## 5. Moteur de tarification

1. On détermine la **zone** du client à partir de son adresse de livraison (J81).
2. On vérifie que la zone est **active** ; sinon la commande est refusée à l'étape adresse (message « zone non desservie »).
3. On récupère le tarif applicable :
   - **Tarif vendeur spécifique** si un `delivery_rate` existe pour ce couple (vendeur, zone) ;
   - sinon **tarif global** de la zone ;
   - sinon, si aucun tarif : zone non desservie pour ce vendeur → pas de commande.
4. Le tarif retenu est **figé** dans la commande au passage `awaiting_payment` (historisation : `delivery_fee` + référence du tarif appliqué).

## 6. Conditions d'application

1. Le vendeur ne livre que dans les **zones couvertes** (via tarif global ou tarif vendeur). Si aucune zone active ne couvre l'adresse du client → commande impossible.
2. La porteuse peut **créer/modifier/activer/désactiver** zones et tarifs depuis le **back-office sans déployer de code** (J74).
3. Le tarif de livraison est calculé **côté serveur** ; le mobile ne le calcule jamais.
4. Le **changement de zone entre la quote et la validation n'est pas possible** : la zone est verrouillée au passage `awaiting_payment`.

## 7. Historisation

- Chaque commande enregistre : `delivery_fee` appliqué et l'identifiant du tarif source (tracafilité).
- Les modifications de tarifs sont historisées (`effective_from/to`, `is_active`, `updated_by`).

## 8. Cas limites à tester (J76)

- [ ] Adresse dans une **zone inconnue** → blocage propre au checkout
- [ ] **Zone inactive** → blocage propre au checkout
- [ ] Vendeur sans tarif pour la zone du client → message « livraison impossible pour ce vendeur »
- [ ] Tarif vendeur spécifique vs tarif global → le spécifique l'emporte
- [ ] Changement de tarif après `awaiting_payment` → l'ancien tarif est figé sur la commande

## 9. Critères d'acceptation

- [ ] Zones et tarifs administrables par la porteuse (back-office)
- [ ] Sélection automatique de la zone depuis l'adresse client
- [ ] Calcul des frais de livraison **avant** validation de commande, côté serveur
- [ ] Tarifs (global + spécifique vendeur) supportés
- [ ] Historisation du tarif appliqué par commande
- [ ] Cas limites (zone inconnue/inactive) gérés proprement