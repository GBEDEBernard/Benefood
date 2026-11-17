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

php artisan config:cache
php artisan view:cache

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/beninfood.conf
