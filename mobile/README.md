# Béninfood — Application Flutter (Client / Vendeur / Livreur)

Application Flutter unique multi-rôles qui consomme l'API Laravel `backend` (`/api/v1`).

## Lancer l'application

```bash
flutter pub get
flutter run
```

## Connexion à l'API locale

L'URL de base de l'API suit la plateforme par défaut :

| Cible | URL par défaut |
| --- | --- |
| Émulateur Android | `http://10.0.2.2:8000` |
| Desktop / iOS Simulator | `http://127.0.0.1:8000` |
| Téléphone physique | à régler (voir ci-dessous) |

### Sur un téléphone physique

Le backend doit écouter sur toutes les interfaces (et non `127.0.0.1`) :

```bash
cd backend
php -S 0.0.0.0:8000 server.php
```

Sur le même réseau Wi-Fi, ouvrez dans l'app **Réglages du serveur** (icône ⚙ sur
l'écran d'accueil, ou Compte → Réglages du serveur) et saisissez l'IP locale du
poste, par ex. `http://192.168.1.102:8000`. Le bouton **Tester la connexion**
vérifie l'accès avant d'enregistrer (le changement s'applique au prochain
démarrage de l'app).

L'adresse peut aussi être surchargée au build :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.102:8000
```

### iOS (iPhone)

Le trafic HTTP local est bloqué par ATS par défaut. Ajoutez les exceptions dans
`ios/Runner/Info.plist` pour autoriser la mise au point en local :

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsLocalNetworking</key>
  <true/>
</dict>
```

## Build release (APK testeurs)

```bash
flutter build apk --release
# ou, si besoin de forcer l'URL :
flutter build apk --release --dart-define=API_BASE_URL=https://benefood.onrender.com
```

Ne mettez **pas** de slash final dans `API_BASE_URL` : `https://host/` produisait
`https://host//api/v1` et le backend répondait 404 « Ressource introuvable. » à
chaque appel. `AppConfig.normalizeBaseUrl()` corrige désormais ce cas, mais la
forme sans slash reste la référence.

## Voir les logs sur un téléphone

Les `debugPrint` de l'app (y compris `main: apiUrl = ...` et les erreurs HTTP
préfixées `BENINFOOD_API`) sont visibles en release via adb :

```bash
adb devices                       # vérifier que le téléphone est autorisé
adb logcat -s flutter
# ou, pour ne garder que les appels API :
adb logcat | grep BENINFOOD_API
```

Ouvrez l'app et refaites la connexion : la ligne `main: apiUrl = ...` donne
l'URL exacte utilisée, et chaque échec affiche `METHODE URL -> code statut code:
message`. Sur un build distribué via Firebase App Distribution, ces logs ne
sont pas remontés automatiquement : demandez la capture adb ou utilisez
l'écran **Serveur → Tester la connexion**, qui affiche désormais l'URL et le
statut HTTP obtenus.

## Structure

```
lib/
├── app/               → BeninfoodApp (provider racine)
├── core/              → config, http, auth, storage, thème, services
├── features/
│   ├── auth/          → landing, connexion, inscription, mot de passe
│   ├── client/        → accueil, explorer, boutique, panier, commandes, compte
│   ├── vendor/        → boutique, produits, commandes, stats
│   └── driver/        → offres, missions, historique
├── shared/            → modèles + widgets réutilisables
└── router/            → go_router (redirection par session + rôle actif)
```