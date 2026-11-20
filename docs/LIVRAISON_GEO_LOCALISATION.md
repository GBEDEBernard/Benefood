# Livraison — infrastructure géolocalisation, adresses et suivi GPS

**Statut :** implémenté et vérifié localement. Aucun commit, push ou pull request n’a été effectué ; toutes les modifications restent dans l’arbre de travail.

## 1. Objectif et principes retenus

Mettre en place une **seule infrastructure géographique** partagée par l’API Laravel (`/api/v1`), l’application Flutter et le référentiel administratif officiel du Bénin. Elle couvre les 13 usages ciblés : activation des comptes, profils client/livreur/vendeur, recherche de lieu, boutiques, adresses de livraison, retrait de colis, livreurs, suivi temps réel, distances, cartes et tableaux de bord.

Règles appliquées sans exception :

- **Aucune localité inventée** : le référentiel IGN fait foi ; un point hors référentiel reste sans rattachement administratif.
- **Aucune assimilation** arrondissement → quartier : `geo_divisions` (niveaux administratifs) et `geo_localities` (villages, quartiers, hameaux, villes) sont deux tables distinctes ; le type IGN (`Type`) est conservé tel quel.
- **Identifiants stables** : `source_key` (dont `Code_GEO` IGN) et codes géographiques officiels conservés, avec source, URL et date de mise à jour.
- **Rétrocompatibilité** : `city`, `area`, `address_text`, `latitude`, `longitude` et l’endpoint `GET /api/v1/locations` restent fonctionnels ; les références géographiques sont ajoutées, jamais substituées brutalement.
- **Aucune dépendance ajoutée** : ni Composer, ni Flutter. Pas de Reverb/WebSocket : FCM + polling restent le canal de production.
- **Aucune clé payante côté mobile** : géocodage et routage restent côté serveur.

## 2. Référentiel officiel IGN Bénin

Sources utilisées (téléchargements mis en cache dans `backend/database/seeders/data/geo/`, licence **Etalab Open Licence 2.0**, coordonnées **WGS84 / EPSG:4326**) :

| Jeu IGN | URL |
| --- | --- |
| Limites départementales | `https://ign.bj/donnees/limites-departementales/telecharger/1` |
| Limites communales | `https://ign.bj/donnees/limites-communales/telecharger/2` |
| Limites des arrondissements | `https://ign.bj/donnees/limites-des-arrondissements/telecharger/3` |
| Chefs-lieux de département | `https://ign.bj/donnees/chefs-lieux-de-departement/telecharger/5` |
| Chefs-lieux de commune | `https://ign.bj/donnees/chefs-lieux-de-commune/telecharger/6` |
| Chefs-lieux d’arrondissement | `https://ign.bj/donnees/chefs-lieux-darrondissement/telecharger/7` |
| Localités et chefs-lieux de village | `https://ign.bj/donnees/localites-et-chefs-lieux-de-village/telecharger/8` |

Import complet rejoué via :

```bash
php artisan tinker --execute "App\Models\GeoCountry::where('code', 'BJ')->delete();" --no-interaction
php artisan geo:import-ign-benin --no-interaction
```

Résultat contrôlé :

| Élément | Count |
| --- | --- |
| Départements | 12 |
| Communes | 77 |
| Arrondissements | 546 |
| Localités | 5 291 |
| Rattachement par nom IGN | 4 642 |
| Rattachement par géométrie | 649 |
| Localités non rattachées | 0 |

Les variantes de noms relevées entre jeux IGN (`Gbafo/Gbaffo`, `Houto/Outo`, `Séméré II/Sèmèrè 2`, `Toumbouctou/Toumboutou`, `Mandékali/Madécali`, `Tchaorou/Tchaourou`, `Djougou/Djoudjou`, `Dassa/Dassa-Zoumè`, `Dogbo/Dogbo-Tota`, `Adjara/Adjarra`, `Sèmè-Podji/Seme Kpodji`) sont résolues dans l’importateur par inclusion dans la géométrie des arrondissements, jamais par création de localité.

La hiérarchie est **configurable par pays** : `geo_countries.levels` décrit les niveaux (`department`, `commune`, `arrondissement` pour `BJ`), `geo_divisions.parent_id` construit l’arbre, et `geo_countries.locality_label` porte le libellé du dernier niveau. D’autres pays pourront utiliser `region`, `province`, `état`, `district`, etc., sans modifier le code.

## 3. Backend Laravel

### 3.1 Migrations

| Migration | Rôle |
| --- | --- |
| `2026_11_20_183928_create_geo_reference_tables.php` | `geo_countries`, `geo_divisions` (arbre + bbox + géométrie simplifiée), `geo_localities` (type IGN, coordonnées, source, code) |
| `2026_11_20_183929_add_geo_fields_to_addresses_users_vendors_tables.php` | Références `country_id`, `division_id`, `locality_id`, précision GPS, source et date ; références de retrait `pickup_*` sur `vendors` |
| `2026_11_20_183930_add_tracking_fields_to_deliveries_tables.php` | Dernière position, précision, vitesse, cap, source et horodatage sur `deliveries` ; précision/vitesse/source sur `delivery_locations` |

Les anciennes colonnes sont conservées ; les clés étrangères utilisent `nullOnDelete` pour ne jamais détruire une adresse historique lors d’une mise à jour du référentiel.

### 3.2 Modèles, services et validation

- Modèles `GeoCountry`, `GeoDivision`, `GeoLocality` + factories.
- `GeoReferenceImporter` : lecture des 7 GeoJSON, normalisation des noms, rattachement par nom puis par point, remplacement transactionnel du pays.
- `GeocodingService` :
  - recherche textuelle et géocodage inversé **locaux d’abord** (`searchLocal()`, `reverseLocal()`), sans appel réseau ;
  - adaptateurs interchangeables `nominatim` (par défaut, User-Agent + throttling), `mapbox`, `google`, `local` ;
  - cache configuré, timeout et intervalle minimum `BENINFOOD_GEOCODING_MIN_INTERVAL_MS=1100` ;
  - clés API lues uniquement dans la configuration serveur.
- `GeoFields` : rules + `resolve()` partagées par les contrôleurs (adresses, onboarding, `User`, `Vendor`, snapshots `pickup`/`dropoff` des colis). La résolution ne fait **aucun appel réseau** : elle ne valide que des identifiants présents dans le référentiel local.
- `DeliveryTrackingService` : dépôt des positions, contrôle mission active/propriétaire, throttling 4 s en mission / 15 s hors mission, précision max 100 m, vitesse max 40 m/s, calcul des distances orthodromiques et routières, ETA, et payload de polling léger.
- `DriverLocationUpdated` : événement prêt pour broadcast (`delivery.*`, `driver.location.updated`) mais `broadcastWhen()` renvoie `false` tant que `BENINFOOD_TRACKING_BROADCAST_ENABLED=false`.

### 3.3 API

Toutes les réponses suivent l’enveloppe `{data, meta}` de `App\Support\Api` ; les erreurs suivent `{errors:[{code,message,field}]}`.

| Méthode | Endpoint | Usage |
| --- | --- | --- |
| GET | `/api/v1/geo/countries` | Pays, hiérarchie configurable, source et date |
| GET | `/api/v1/geo/divisions` | Niveaux filtrables par `country`, `level`, `parent_id`, `q`, pagination |
| GET | `/api/v1/geo/localities` | Localités par `division_id`, `kind`, `q`, pagination |
| GET | `/api/v1/geo/search` | Autocomplétion dans le référentiel officiel |
| POST | `/api/v1/geo/geocode` | Géocodage d’une adresse libre (serveur uniquement) |
| POST | `/api/v1/geo/reverse` | Rattachement officiel d’un point GPS (`404` = aucun rattachement) |
| GET | `/api/v1/locations` | Endpoint historique conservé pour repli |
| PATCH | `/api/v1/driver/me/availability/location` | Endpoint canonique de dépôt GPS, étendu aux métadonnées |
| GET | `/api/v1/orders/{order}/tracking` | Suivi léger commande |
| GET | `/api/v1/parcels/{parcel}/tracking` | Suivi léger colis |

Le payload de suivi est :

```json
{
  "active": true,
  "status": "in_delivery",
  "points": {"client": {...}, "shop": {...}, "driver": {...}},
  "distances": {"straight_km": {...}, "road_m": 2100, "road_provider": "osrm", "road_duration_s": 480},
  "eta": {"seconds": 480, "minutes": 8, "source": "road", "provider": "osrm", "available": true},
  "legacy_position": {"latitude": 6.36, "longitude": 2.43}
}
```

`legacy_position` conserve le format historique `position` consommé par les écrans existants. L’accès aux endpoints de suivi est restreint au client propriétaire, au livreur assigné et au vendeur actif de la commande (au propriétaire et au livreur assigné pour les colis). Aucune position n’est persistée sur une mission terminée ou annulée.

`RoutePlanner` met en cache les tracés par coordonnées arrondies à 3 décimales (~110 m) : le polling de suivi ne déclenche donc pas un appel routier à chaque tick.

## 4. Mobile Flutter

### 4.1 Sélecteur hiérarchique

`lib/shared/widgets/city_area_picker.dart` conserve la signature publique `showCityAreaPicker(...)` et ajoute :

- pays → niveaux configurables → localités, via `/geo/*` ;
- recherche serveur, pagination et cache de session ;
- réinitialisation des niveaux inférieurs lors d’un changement de pays ou de subdivision ;
- `includeGps` sur `CityAreaPickerField` : géocodage inversé officiel via `POST /geo/reverse`, avec précision, source et horodatage ;
- repli automatique sur `GET /locations` si le référentiel hiérarchique est indisponible ;
- identifiants stables transmis au backend (`GeoReferenceSelection`).

`GeoReferenceSelection` est propagé dans l’activation client, livreur et vendeur (`LegalInfoStep` inclus), les adresses client et l’adresse boutique/retrait. Les indications codées en dur ont été retirées de `legal_info_step.dart` et `shop_address_edit_screen.dart`. Les zones demo `z1/z2/z3` de `shop_zones_edit_screen.dart` sont **inchangées** : `syncVendorZones()` attend ces IDs de `delivery_zones`.

### 4.2 GPS et suivi

- `LocationService` expose `accuracyM`, `speedMps`, `heading`, `source`, `recordedAt`, `isPrecise`, `trackingFields`, `currentPosition()` et distingue les échecs : service désactivé, permission refusée, position introuvable. Le marqueur GPS n’est **jamais déplacé automatiquement**.
- Les métadonnées GPS sont envoyées par `driver_presence_service.dart`, `background_location_service.dart` et `mission_navigation_screen.dart`.
- Le nouveau modèle `DeliveryTrackingSnapshot` (`lib/shared/models/delivery_tracking.dart`) parse les trois positions, les distances, l’ETA et `legacy_position`.
- `order_tracking_screen.dart`, `parcel_detail_screen.dart` et `vendor_order_detail_screen.dart` utilisent les endpoints légers ; le détail complet n’est rechargé qu’à l’ouverture et lorsque `active` passe à `false` (fin/annulation). Le nouveau colis (`parcel_create_screen.dart`) propage les références `pickup`/`dropoff`, y compris le reverse GPS et les points posés sur la carte.

### 4.3 Écrans et fichiers mobile touchés

- API/modèles/services : `core/data/marketplace_api.dart`, `core/services/{location_service,driver_presence_service,background_location_service}.dart`, `shared/models/{geo_reference,delivery_tracking,address,user,vendor}.dart`, `shared/widgets/city_area_picker.dart`.
- Client : onboarding, adresses, création de colis, détail colis, suivi commande, recherche.
- Livreur : onboarding, navigation de mission.
- Vendeur : onboarding + `LegalInfoStep`, détail commande, adresse boutique/retrait.
- Tests : ajout de `test/core/data/geo_api_test.dart` et `test/shared/models/delivery_tracking_test.dart` ; mocks mis à jour pour `POST /geo/reverse`, `GET /orders/{id}/tracking`, `GET /parcels/{id}/tracking` et `GET /geo/countries` ; cinq tests préexistants obsolètes remis en phase avec l’UI courante.

## 5. Configuration et sécurité

Variables ajoutées dans `backend/.env.example` :

```dotenv
BENINFOOD_GEOCODING_PROVIDER=nominatim
BENINFOOD_GEO_CACHE_TTL=3600
BENINFOOD_GEOCODING_CACHE_TTL=86400
BENINFOOD_GEOCODING_MIN_INTERVAL_MS=1100
BENINFOOD_TRACKING_MIN_INTERVAL_S=4
BENINFOOD_TRACKING_MAX_ACCURACY_M=100
BENINFOOD_TRACKING_IDLE_MIN_INTERVAL_S=15
BENINFOOD_TRACKING_BROADCAST_ENABLED=false
BENINFOOD_ROUTING_ALLOW_PUBLIC_OSRM=false
# MAPBOX_ACCESS_TOKEN=
# GOOGLE_GEOCODING_API_KEY=
```

- Aucun token Mapbox/Google, aucune URL Nominatim ou OSRM public n’est exposée au mobile.
- `BENINFOOD_ROUTING_ALLOW_PUBLIC_OSRM` reste `false` en production : le routage public n’est qu’un repli de développement.
- Le géocodage externe est désactivé par défaut pour les tests et peut être remplacé par `local` sans modifier l’API.

## 6. Vérifications effectuées

| Contrôle | Résultat |
| --- | --- |
| `php artisan test --compact tests/Feature/ParcelGeoReferenceTest.php tests/Feature/ParcelFeatureTest.php tests/Feature/GeoReferenceApiTest.php tests/Feature/GeoLocationTrackingTest.php` | **44 tests, 258 assertions, 100 % réussis** |
| `vendor/bin/pint --dirty --format agent` | **OK** |
| `flutter analyze` | **0 erreur**, 50 avertissements/informations préexistants (`use_null_aware_elements`, imports inutilisés, `withOpacity`, `use_build_context_synchronously`) ; aucun dans les nouveaux fichiers |
| `flutter test --reporter compact` | **256 tests, 100 % réussis** |
| Import IGN complet | **12 / 77 / 546 / 5 291**, 0 localité non rattachée |

Échecs préexistants documentés avant correction : cinq tests Flutter échouaient déjà à `HEAD` (attentes `Email`, `Véhicule`, `Missions`, `08:00` × 5/7 et `Informations supplémentaires`) ; ils ont été alignés sur l’UI réelle et passent désormais. Côté backend, trois tests échouaient déjà à `HEAD` (`ExampleTest` 302 au lieu de 200 et deux assertions de `ShopDataSeederTest`) ; ils sont sans rapport avec le référentiel géographique.

La suite backend complète a été relancée mais interrompue après plus de 17 minutes sans sortie exploitable ; le dernier résultat complet connu reste **584 tests / 581 réussis / 3 échecs**, soit exactement les trois échecs préexistants ci-dessus. Les tests ciblés géo/suivi, eux, passent intégralement.

## 7. Limites restantes / points de vigilance

1. **Réseau externe** : le géocodage Nominatim reste tributaire de la disponibilité du service public ; le cache et le throttling limitent la pression, mais un fournisseur avec clé (`mapbox`/`google`) est recommandé en production.
2. **Broadcast temps réel** : `DriverLocationUpdated` est prêt mais désactivé ; l’activation nécessiterait Reverb/WebSocket et n’est pas prévue dans cette livraison (FCM + polling suffisent).
3. **Routing** : sans clé Google/ORS, le repli `straight` ou l’OSRM public (uniquement hors production) donne une ETA approximative ; la distance à vol d’oiseau reste toujours distinguée de la distance routière.
4. **Variantes IGN** : les correspondances de noms relevées sont normalisées dans l’importateur ; toute nouvelle variante IGN devra être ajoutée là, sans créer de localité manuelle.
5. **Autres pays** : le schéma est prêt, mais seul le Bénin est importé ; l’ajout d’un pays exige son propre jeu de données officiel et son mapping de niveaux.
6. **Mises à jour IGN** : relancer `php artisan geo:import-ign-benin` après mise à jour des GeoJSON ; les références déjà enregistrées pointent vers des identifiants stables (`source_key`).

## 8. Commandes utiles

```bash
# Réimport complet du référentiel béninois
php artisan geo:import-ign-benin --no-interaction

# Tests backend ciblés géo/suivi
php artisan test --compact tests/Feature/GeoReferenceApiTest.php \
  tests/Feature/GeoLocationTrackingTest.php \
  tests/Feature/ParcelGeoReferenceTest.php

# Tests mobile
cd mobile && flutter analyze && flutter test --reporter compact
```

---

Livraison préparée le 20 novembre 2026. Aucune modification n’a été commitée.
