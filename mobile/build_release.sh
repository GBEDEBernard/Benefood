#!/usr/bin/env bash
# build_release.sh — Construit un APK (ou AAB) release Béninfood signé.
#
# Usage :
#   ./build_release.sh                      # APK release, API de production (Render)
#   ./build_release.sh --aab                # AAB release pour Google Play
#   ./build_release.sh "https://..."        # URL explicite (serveur de test)
#   API_BASE_URL="https://..." ./build_release.sh
#
# Prérequis :
#   - mobile/android/app/google-services.json (Firebase Android)
#   - mobile/android/key.properties + keystore release (voir key.properties.example)
#
# Actions :
#   1. vérifie la configuration Firebase et la signature release ;
#   2. choisit l'URL de l'API ;
#   3. incrémente le versionCode dans pubspec.yaml (+1) ;
#   4. compile l'APK/AAB release ;
#   5. affiche le chemin du fichier prêt à distribuer.
set -euo pipefail

MOBILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBSPEC="$MOBILE_DIR/pubspec.yaml"
DEFAULT_API_BASE_URL="https://benefood.onrender.com"
BUILD_AAB=0

if [[ "${1:-}" == "--aab" ]]; then
  BUILD_AAB=1
  shift
fi

# 1) Préflight : Firebase + signature release
if [[ ! -f "$MOBILE_DIR/android/app/google-services.json" ]]; then
  echo "ERREUR : $MOBILE_DIR/android/app/google-services.json manquant." >&2
  echo "Télécharge-le depuis Firebase Console > Paramètres du projet > Android." >&2
  exit 1
fi

if [[ ! -f "$MOBILE_DIR/android/key.properties" ]]; then
  echo "ERREUR : $MOBILE_DIR/android/key.properties manquant." >&2
  echo "Copie key.properties.example et renseigne le keystore release." >&2
  exit 1
fi

STORE_FILE="$(grep -E '^storeFile=' "$MOBILE_DIR/android/key.properties" | cut -d= -f2-)"
if [[ -z "$STORE_FILE" || ! -f "$MOBILE_DIR/android/$STORE_FILE" ]]; then
  echo "ERREUR : keystore release introuvable ($STORE_FILE)." >&2
  exit 1
fi

# 2) URL de l'API
if [[ -n "${1:-}" ]]; then
  API_BASE_URL="$1"
elif [[ -z "${API_BASE_URL:-}" ]]; then
  API_BASE_URL="$DEFAULT_API_BASE_URL"
fi
echo "→ URL API   : $API_BASE_URL"

# 3) Incrémenter le versionCode (pubspec.yaml : "version: 1.0.0+1")
current="$(grep -E '^version:' "$PUBSPEC" | head -1 | awk '{print $2}')"
if [[ "$current" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
  name="${BASH_REMATCH[1]}"
  build=$(( ${BASH_REMATCH[2]} + 1 ))
  next="$name+$build"
else
  echo "ERREUR : format de version inattendu (« $current ») dans $PUBSPEC" >&2
  exit 1
fi
sed -i "s/^version: .*/version: $next/" "$PUBSPEC"
echo "→ Version   : $current → $next"

# 4) Build
cd "$MOBILE_DIR"
if [[ "$BUILD_AAB" == "1" ]]; then
  echo "→ Build AAB release (Google Play, peut prendre quelques minutes)…"
  flutter build appbundle --release --dart-define="API_BASE_URL=$API_BASE_URL"
  OUT="$MOBILE_DIR/build/app/outputs/bundle/release/app-release.aab"
  LABEL="AAB"
else
  echo "→ Build APK release (peut prendre quelques minutes)…"
  flutter build apk --release --dart-define="API_BASE_URL=$API_BASE_URL"
  OUT="$MOBILE_DIR/build/app/outputs/flutter-apk/app-release.apk"
  LABEL="APK"
fi

echo
echo "✔ $LABEL prêt : $OUT"
echo "  Version $name ($build) — signé avec le keystore release."
echo "  APK : Firebase App Distribution ou installation directe."
echo "  AAB : Google Play Console (test interne / fermé / production)."
