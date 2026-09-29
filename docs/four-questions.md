# laravel-shop-api — The Four Questions (operator view)
_Last verified: 2026-09-27 · Laravel 13 · PHP <version from Ex 2>_


## 1. Build
- Command: `composer install --no-dev --optimize-autoloader --no-interaction`
- Lockfile committed: yes/no · Reproducible: …
- Run without local PHP via: composer:2 container (see README)


## 2. Artifact
- App source + vendor/ (~<size> MB). No compile step. Archetype 3.
- Runs under php-fpm (FastCGI :9000) behind Nginx (HTTP :80). Nginx serves public/ directly.


## 3. Runtime needs
- PHP ≥ 8.3
- Extensions (composer-declared): <from Ex 3>
- Extensions (env-implied): pdo_mysql (DB_CONNECTION=mysql), redis (REDIS_CLIENT=phpredis) …
- Writable by fpm user (www-data): storage/, bootstrap/cache/
- Env vars:
  | Var | Required? | Secret? | Example / note |
  |---|---|---|---|
  | APP_KEY | yes | YES — never rotate casually | per-environment |
  | … | | | |
- Drift found (Ex 4): <vars missing from README / .env.example>


## 4. Connections
| To | Port | Via env | Used for |
|---|---|---|---|
| MySQL | 3306 | DB_* | data + migrations table + failed_jobs |
| Redis | 6379 | REDIS_* | cache, sessions, queue |
| SMTP | … | MAIL_* | order email (MAIL_MAILER=log locally) |
| Storage | — | FILESYSTEM_DISK | uploads (local → S3 in W10) |


## Process model
| Process | Command | Notes |
|---|---|---|
| web | php-fpm + Nginx | fresh per request |
| worker | php artisan queue:work redis --tries=3 | restart on every deploy (queue:restart) |
| scheduler | php artisan schedule:run (every minute) | if the app schedules anything |
| release | php artisan migrate --force | once per deploy, not per container |


## Health endpoints
- /health — deep (MySQL + Redis) · /up — shallow (app boots)


## Known traps
- config:cache freezes env and writes secrets to bootstrap/cache/config.php → run at container start, not image build
- APP_KEY change = all sessions + encrypted data invalid


## Open questions for Day 2
- What happens to an order if Redis is down at dispatch?
- One container (Nginx+fpm) or two?
- <audit findings from Ex 7c>

