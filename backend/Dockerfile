# syntax=docker/dockerfile:1

# --- 1. Assets Vite (back-office Blade) -------------------------------------
FROM node:22-alpine AS assets

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

COPY . .
RUN npm run build

# --- 2. Dépendances PHP ------------------------------------------------------
FROM composer:2 AS vendor

WORKDIR /app

COPY . .
RUN mkdir -p bootstrap/cache storage/app/public storage/framework/cache/data \
        storage/framework/sessions storage/framework/views storage/logs
RUN composer install \
        --no-dev \
        --no-interaction \
        --no-progress \
        --prefer-dist \
        --optimize-autoloader

# --- 3. Image d'exécution ----------------------------------------------------
FROM php:8.4-fpm-bookworm AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    APP_ENV=production \
    COMPOSER_ALLOW_SUPERUSER=1

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl unzip git \
        nginx gettext-base supervisor \
        libpng16-16 libjpeg62-turbo libfreetype6 libzip4 \
        libicu72 libonig5 libxml2 \
        libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
        libicu-dev libzip-dev libxml2-dev libonig-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" \
        pdo_mysql mbstring intl zip gd bcmath pcntl opcache; \
    apt-get purge -y --auto-remove \
        libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
        libicu-dev libzip-dev libxml2-dev libonig-dev; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /var/cache/nginx /var/log/supervisor; \
    chown -R www-data:www-data /var/cache/nginx /var/log/supervisor

WORKDIR /var/www/html

COPY --from=vendor --chown=www-data:www-data /app/vendor/ ./vendor/
COPY --chown=www-data:www-data . ./
COPY --from=assets --chown=www-data:www-data /app/public/build/ ./public/build/

COPY php.ini /usr/local/etc/php/conf.d/zz-beninfood.ini
COPY www.conf /usr/local/etc/php-fpm.d/www.conf
COPY supervisord.conf /etc/supervisor/conf.d/beninfood.conf
COPY nginx.conf /var/www/html/nginx.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
