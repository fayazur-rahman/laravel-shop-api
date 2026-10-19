#!/bin/sh
# Runs at container START, when the real environment is present.
set -e


# Freeze config from THIS container's env (never at image build: secrets would be baked in).
# Its output goes to stderr (>&2) so the wrapped command's stdout stays clean:
# KEY=$(docker compose run --rm app php artisan key:generate --show) must capture ONLY the key.
php artisan config:cache >&2


# Replace the shell with the real process (php-fpm or queue:work) so it becomes
# PID 1 and receives SIGTERM from `docker stop` directly.
exec "$@"

