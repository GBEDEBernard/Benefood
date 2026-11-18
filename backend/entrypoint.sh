#!/bin/sh
set -eu

cd /var/www/html

# Render fournit le port à écouter via $PORT.
export PORT="${PORT:-8080}"
envsubst '${PORT}' < nginx.conf > /etc/nginx/nginx.conf

mkdir -p storage/app/public storage/framework/cache/data \
    storage/framework/sessions storage/framework/views storage/logs bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache

# Le lien versionné pointe vers un chemin local absolu : le recréer dans le conteneur.
php artisan storage:link --force >/dev/null

# Render monte les Secret Files en 0600 root, illisibles par PHP-FPM (www-data).
if [ -f /etc/secrets/ca.pem ]; then
    install -m 0644 /etc/secrets/ca.pem /var/www/html/storage/ca.pem
    export MYSQL_ATTR_SSL_CA=/var/www/html/storage/ca.pem
fi

# Comptes de service Firebase : même contrainte de droits que le CA MySQL.
if [ -f /etc/secrets/firebase.json ]; then
    install -m 0644 /etc/secrets/firebase.json /var/www/html/storage/firebase-service-account.json
    export FIREBASE_CREDENTIALS=/var/www/html/storage/firebase-service-account.json
elif [ "${BENINFOOD_PUSH_ENABLED:-false}" = "true" ]; then
    echo "AVERTISSEMENT : BENINFOOD_PUSH_ENABLED=true mais /etc/secrets/firebase.json est absent ; les push FCM echoueront." >&2
fi

# Stockage médias externalisé (Cloudflare R2 / S3) : vérifier la configuration.
if [ "${BENINFOOD_IMAGES_DISK:-public}" = "s3" ]; then
    [ -n "${AWS_ACCESS_KEY_ID:-}" ] || echo "AVERTISSEMENT : BENINFOOD_IMAGES_DISK=s3 mais AWS_ACCESS_KEY_ID est vide." >&2
    [ -n "${AWS_SECRET_ACCESS_KEY:-}" ] || echo "AVERTISSEMENT : BENINFOOD_IMAGES_DISK=s3 mais AWS_SECRET_ACCESS_KEY est vide." >&2
    [ -n "${AWS_BUCKET:-}" ] || echo "AVERTISSEMENT : BENINFOOD_IMAGES_DISK=s3 mais AWS_BUCKET est vide." >&2
    [ -n "${AWS_ENDPOINT:-}" ] || echo "AVERTISSEMENT : BENINFOOD_IMAGES_DISK=s3 mais AWS_ENDPOINT est vide." >&2
    [ -n "${AWS_URL:-}" ] || echo "AVERTISSEMENT : BENINFOOD_IMAGES_DISK=s3 mais AWS_URL est vide ; les URLs des images seront invalides." >&2
fi

attempt=1
until php artisan migrate --force --no-interaction; do
    if [ "$attempt" -ge 5 ]; then
        echo "Database migrations failed after $attempt attempts." >&2
        exit 1
    fi
    echo "Database unavailable, retrying migration ($attempt/5)..." >&2
    attempt=$((attempt + 1))
    sleep 5
done

# Référentiels et compte administrateur (idempotent, sans données de démo).
php artisan db:seed --class=ProductionSeeder --force --no-interaction

php artisan config:cache
php artisan view:cache

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/beninfood.conf
