# syntax=docker/dockerfile:1
# laravel-shop-api — one Dockerfile, two runtime images:
#   --target app  → php-fpm (web requests AND the queue worker)
#   --target web  → Nginx carrying only public/ (static files + FastCGI to app:9000)


############################
# Stage 1: vendor — build the Composer artifact
############################
FROM composer:2 AS vendor
WORKDIR /var/www/html


# Dependency manifests first → this layer stays cached until composer.lock changes.
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction


# Then the application code, then the optimized autoloader + package manifest.
COPY . .
RUN composer dump-autoload --no-dev --optimize --no-scripts \
 && php artisan package:discover


############################
# Stage 2: app — php-fpm runtime
############################
FROM php:8.4-fpm AS app


# Extensions composer.json does NOT declare, but this app needs at runtime:
#   pdo_mysql ← DB_CONNECTION=mysql
#   redis     ← REDIS_CLIENT=phpredis
RUN docker-php-ext-install pdo_mysql \
 && pecl install redis \
 && docker-php-ext-enable redis \
 && rm -rf /tmp/pear


# Production php.ini defaults (display_errors off, etc.).
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"


WORKDIR /var/www/html
COPY --from=vendor /var/www/html /var/www/html


# Only these two paths must be writable by the fpm workers (www-data).
RUN chown -R www-data:www-data storage bootstrap/cache


COPY docker/php/entrypoint.sh /usr/local/bin/app-entrypoint
RUN chmod +x /usr/local/bin/app-entrypoint


ENTRYPOINT ["app-entrypoint"]
CMD ["php-fpm"]
EXPOSE 9000


############################
# Stage 3: web — Nginx with the public/ directory baked in
############################
FROM nginx:1.28-alpine AS web
COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=vendor /var/www/html/public /var/www/html/public
EXPOSE 80

