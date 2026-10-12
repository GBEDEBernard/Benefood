#!/usr/bin/env bash
# build_release.sh — Construit un APK release Béninfood pour Firebase App Distribution.
#
# Usage :
#   ./build_release.sh                      # URL lue depuis le tunnel Cloudflare actif
#   ./build_release.sh "https://..."        # URL explicite (ex. après redémarrage du tunnel)
#   API_BASE_URL="https://..." ./build_release.sh
#
# Actions :
#   1. récupère l'URL du backend (tunnel actif ou argument) ;
#   2. incrémente automatiquement le versionCode dans pubspec.yaml (+1) ;
#   3. recompile l'APK release avec cette URL ;
#   4. affiche le chemin de l'APK prêt à téléverser.
set -euo pipefail

MOBILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBSPEC="$MOBILE_DIR/pubspec.yaml"
TUNNEL_LOG="${TUNNEL_LOG:-/tmp/opencode/tunnel.log}"
OUT="$MOBILE_DIR/build/app/outputs/flutter-apk/app-release.apk"

# 1) URL de l'API
if [[ -n "${1:-}" ]]; then
  API_BASE_URL="$1"
elif [[ -z "${API_BASE_URL:-}" ]]; then
  API_BASE_URL="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1 || true)"
  if [[ -z "$API_BASE_URL" ]]; then
    echo "ERREUR : aucune URL fournie ni trouvée dans $TUNNEL_LOG" >&2
    echo "Relance le tunnel (ou passe l'URL en argument)." >&2
    exit 1
  fi
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