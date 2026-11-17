#!/usr/bin/env bash
# build_release.sh — Construit un APK release Béninfood pour Firebase App Distribution.
#
# Usage :
#   ./build_release.sh                      # API de production (Render)
#   ./build_release.sh "https://..."        # URL explicite (serveur de test)
#   API_BASE_URL="https://..." ./build_release.sh
#
# Actions :
#   1. choisit l'URL de l'API (argument, variable d'environnement ou production) ;
#   2. incrémente le versionCode dans pubspec.yaml (+1) ;
#   3. compile l'APK release avec cette URL ;
#   4. affiche le chemin de l'APK prêt à téléverser.
set -euo pipefail

MOBILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBSPEC="$MOBILE_DIR/pubspec.yaml"
DEFAULT_API_BASE_URL="https://benefood.onrender.com"
OUT="$MOBILE_DIR/build/app/outputs/flutter-apk/app-release.apk"

# 1) URL de l'API
if [[ -n "${1:-}" ]]; then
  API_BASE_URL="$1"
elif [[ -z "${API_BASE_URL:-}" ]]; then
  API_BASE_URL="$DEFAULT_API_BASE_URL"
fi
echo "→ URL API   : $API_BASE_URL"

# 2) Incrémenter le versionCode (pubspec.yaml : "version: 1.0.0+1")
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

# 3) Build
echo "→ Build APK release (peut prendre quelques minutes)…"
cd "$MOBILE_DIR"
flutter build apk --release --dart-define="API_BASE_URL=$API_BASE_URL"

echo
echo "✔ APK prêt : $OUT"
echo "  Version $name ($build) — téléverse-le dans Firebase App Distribution."
