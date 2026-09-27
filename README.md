# laravel-shop-api

A minimal **Laravel 13** eCommerce API: products, a session-based cart, orders, and a
**queued order-confirmation email**. MySQL for data, Redis for cache + sessions + queue.

This repo is the Phase 2 deploy target of a DevOps roadmap. It is deliberately small:
the interesting part is how it is **built, configured, run, and operated**, not the code.

- PHP **≥ 8.3** · Laravel **13** · MySQL 8 (MariaDB works) · Redis 6+
- All configuration comes from **environment variables**. No hardcoded hosts, and no
  `env()` calls outside `config/` (so `php artisan config:cache` is safe).
- No Dockerfile / Compose yet: those are written in the ops repo work, not here.

---

## Architecture at a glance

```
client ──HTTP──▶ Nginx ──FastCGI :9000──▶ php-fpm (web)
                                             │
                          ┌──────────────────┼──────────────────┐
                          ▼                  ▼                  ▼
                    MySQL :3306         Redis :6379        disk / S3
                  products, orders    cache (db 1)      product images
                  failed_jobs, …      sessions+queue (db 0)
                                             ▲
                         queue worker ───────┘  (php artisan queue:work)
                         sends the order email via MAIL_MAILER
```

### Process model — one codebase, four kinds of process

| Process | Command | Lifetime | Notes |
|---|---|---|---|
| **web** | `php-fpm` behind Nginx | long-running pool, fresh per request | serves HTTP |
| **worker** | `php artisan queue:work redis --tries=3 --timeout=60` | long-running | **restart on every deploy** (`php artisan queue:restart`) — it keeps old code in memory |
| **scheduler** | — | — | not used by this app (nothing is scheduled) |
| **release** | `php artisan migrate --force` | one-off per deploy | run once, **not** in every container's startup |

---

## Ports

| Port | Who listens | Exposed publicly? |
|---|---|---|
| 80 / 443 | Nginx | yes |
| 9000 | php-fpm (FastCGI, not HTTP) | no — Nginx only |
| 3306 | MySQL | no |
| 6379 | Redis | no |
| 8000 | `php artisan serve` (**local dev only**, never production) | no |

---

## Runtime requirements (what the runtime image must contain)

**PHP ≥ 8.3** plus these extensions:

| Extension | Why | Declared in composer.json? |
|---|---|---|
| `pdo_mysql` | `DB_CONNECTION=mysql` | **no** — implied by env. Missing → `could not find driver` |
| `redis` (phpredis) | `REDIS_CLIENT=phpredis` | **no** — implied by env. Missing → `Class "Redis" not found` |
| `mbstring`, `openssl`, `tokenizer`, `ctype`, `fileinfo`, `filter`, `dom`, `xml`/`simplexml`, `iconv`, `session`, `pcre`, `json`, `hash` | framework + packages | yes (`composer check-platform-reqs`) |
| `gd` *or* `imagick` | not required (uploads are validated by MIME only) | no |
| `pdo_sqlite` | **tests only** | no |

> Composer only checks what `composer.json` declares. `pdo_mysql` and `redis` are needed
> because of **env choices**, so they will not appear in `composer check-platform-reqs`.

Writable by the php-fpm user (usually `www-data`): `storage/` and `bootstrap/cache/`.

---

## Environment variables

Copy `.env.example` → `.env` for local runs only. In containers/servers inject real env
vars (they take precedence over `.env`). **Never commit `.env`.**

| Variable | Required | Secret | Default in `.env.example` | Purpose |
|---|---|---|---|---|
| `APP_NAME` | no | no | `Laravel Shop API` | App name (also used in Redis key prefix) |
| `APP_ENV` | yes | no | `local` | `local`/`staging`/`production`. `production` makes `migrate` require `--force` |
| `APP_KEY` | **yes** | **yes** | *(empty)* | Encryption key for cookies/sessions. Generate once per environment. Changing it logs everyone out |
| `APP_PREVIOUS_KEYS` | no | yes | *(empty)* | Old keys, only during a planned `APP_KEY` rotation |
| `APP_DEBUG` | yes | no | `true` | **Must be `false` in production** |
| `APP_URL` | yes | no | `http://localhost` | Public base URL |
| `LOG_CHANNEL` | yes | no | `stderr` | `stderr` for containers (`docker logs`), `single` for `storage/logs/laravel.log` |
| `LOG_LEVEL` | no | no | `debug` | `info` or `warning` in production |
| `DB_CONNECTION` | yes | no | `mysql` | Database driver |
| `DB_HOST` | yes | no | `127.0.0.1` | MySQL host (RDS endpoint in AWS) |
| `DB_PORT` | yes | no | `3306` | MySQL port |
| `DB_DATABASE` | yes | no | `shop` | Database name |
| `DB_USERNAME` | yes | no | `shop` | DB user |
| `DB_PASSWORD` | yes | **yes** | `change-me` | DB password |
| `DB_TIMEOUT` | no | no | `5` | Seconds before a DB connect gives up (fail fast, don't hang) |
| `REDIS_CLIENT` | yes | no | `phpredis` | `phpredis` (needs ext) or `predis` (needs `composer require predis/predis`) |
| `REDIS_HOST` | yes | no | `127.0.0.1` | Redis host (ElastiCache endpoint in AWS) |
| `REDIS_PORT` | yes | no | `6379` | Redis port |
| `REDIS_PASSWORD` | no | **yes** | `null` | Redis auth, if enabled |
| `REDIS_DB` | no | no | `0` | Logical DB for queue + sessions |
| `REDIS_CACHE_DB` | no | no | `1` | Logical DB for cache |
| `REDIS_TIMEOUT` | no | no | `2` | Connect timeout (seconds) |
| `REDIS_READ_TIMEOUT` | no | no | `2` | Read timeout (seconds) |
| `CACHE_STORE` | yes | no | `redis` | Cache backend |
| `SESSION_DRIVER` | yes | no | `redis` | Session backend (the **cart** lives in the session) |
| `SESSION_LIFETIME` | no | no | `120` | Minutes |
| `QUEUE_CONNECTION` | yes | no | `redis` | Queue backend. `sync` runs jobs inline (no worker) |
| `MAIL_MAILER` | yes | no | `log` | `log` writes emails to the log (no SMTP). `smtp` for real mail |
| `MAIL_HOST` | if smtp | no | `127.0.0.1` | SMTP host |
| `MAIL_PORT` | if smtp | no | `587` | SMTP port |
| `MAIL_USERNAME` | if smtp | no | `null` | SMTP user |
| `MAIL_PASSWORD` | if smtp | **yes** | `null` | SMTP password |
| `MAIL_FROM_ADDRESS` | yes | no | `orders@example.com` | Sender address |
| `MAIL_FROM_NAME` | no | no | `${APP_NAME}` | Sender name |
| `FILESYSTEM_DISK` | yes | no | `local` | Where uploads go: `local` (`storage/app/private`) or `s3` |
| `AWS_ACCESS_KEY_ID` | no | **yes** | *(empty)* | Only if not using an IAM role. **Prefer a role on AWS** |
| `AWS_SECRET_ACCESS_KEY` | no | **yes** | *(empty)* | Same as above |
| `AWS_DEFAULT_REGION` | if s3 | no | `us-east-1` | Bucket region |
| `AWS_BUCKET` | if s3 | no | *(empty)* | Bucket name |

Switching uploads to S3 is **env-only**: `FILESYSTEM_DISK=s3` + `AWS_BUCKET` + region.
The S3 adapter (`league/flysystem-aws-s3-v3`) is already installed.

---

## Running commands without PHP on your machine

Every command below runs through the official `composer:2` image. Define the prefix once
per terminal, **from the repo root** (`$PWD` is captured at that moment):

```bash
DRUN=(docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/app -w /app)
```

`--user` makes files the container writes (like `vendor/`) owned by **you**, not root.

### Build (install dependencies)

```bash
# Production artifact (what goes into the runtime image)
"${DRUN[@]}" composer:2 composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist

# Development / CI (includes PHPUnit)
"${DRUN[@]}" composer:2 composer install --no-interaction --prefer-dist

# What PHP version + extensions the packages declare
"${DRUN[@]}" composer:2 composer check-platform-reqs --no-dev
```

### Generate an APP_KEY (prints it, writes nothing)

```bash
"${DRUN[@]}" composer:2 php artisan key:generate --show
```

### Inspect

```bash
"${DRUN[@]}" composer:2 php artisan route:list --except-vendor
"${DRUN[@]}" -e APP_KEY="base64:..." composer:2 php artisan about --only=drivers
```

### Run the tests (no MySQL or Redis needed)

Tests use in-memory SQLite, array cache/session, sync queue and a fake mailer
(all set in `phpunit.xml`). Requires dev dependencies.

```bash
"${DRUN[@]}" composer:2 php artisan test
```

### ⚠ Commands that need MySQL / Redis

`composer:2` ships a **minimal PHP** built for Composer. It does not include `pdo_mysql`
or `redis` (check: `"${DRUN[@]}" composer:2 php -m`). So these commands need the
**runtime image** (php-fpm + those extensions) on the same network as MySQL and Redis:

```bash
php artisan migrate --force          # apply schema (once per deploy)
php artisan db:seed --force          # seed the demo catalogue (idempotent)
php artisan queue:work redis --tries=3 --timeout=60   # the worker process
php artisan queue:restart            # tell workers to reload code after a deploy
php artisan queue:failed             # list jobs that exhausted their retries
php artisan queue:retry all          # re-queue failed jobs
php artisan config:cache             # at container START, never at image build
```

Running them via `composer:2` gives `could not find driver`, which is a real,
instructive failure.

### Build → configure → start order (any environment)

1. `composer install --no-dev --optimize-autoloader`
2. Provide env vars (at minimum `APP_KEY`, `DB_*`, `REDIS_*`).
3. `php artisan migrate --force` (once) · `php artisan db:seed --force` (optional)
4. `php artisan config:cache` (at container start, with real env present)
5. Start php-fpm + Nginx (web) and `queue:work` (worker).
6. Verify: `curl http://<host>/health` → `200`.

---

## API

Base path: `/api`. Send `Accept: application/json`. The cart is kept in the **session
cookie**, so keep a cookie jar with curl (`-c jar -b jar`).

| Method | Path | Body | Result |
|---|---|---|---|
| GET | `/api/products` | — | List (cached in Redis for 10 min, invalidated on write) |
| GET | `/api/products/{id}` | — | One product |
| POST | `/api/products` | `name, sku, price_cents, stock, description?` | 201 created |
| POST | `/api/products/{id}/image` | multipart `image` (≤ 2 MB) | 201; stored on `FILESYSTEM_DISK` |
| GET | `/api/cart` | — | Current session cart |
| POST | `/api/cart/items` | `product_id, quantity` | 201; adds to cart |
| DELETE | `/api/cart/items/{productId}` | — | Removes a line |
| DELETE | `/api/cart` | — | Empties cart |
| POST | `/api/orders` | `customer_name, customer_email` | 201; creates order from cart, **queues** the email |
| GET | `/api/orders/{id}` | — | Order + items; `confirmation_sent_at` is set once the worker has sent the email |

Money is integer **cents** (`price_cents`, `total_cents`).

### Health

| Path | Checks | Healthy | Unhealthy |
|---|---|---|---|
| `/health` | MySQL (`select 1`) **and** Redis (`PING`) | `200 {"status":"ok","checks":{"database":"ok","redis":"ok"}}` | `503`, failed check named. Details go to the log only |
| `/up` | app boots (Laravel built-in) | `200` | `500` |

`/health` runs with **no middleware** (no session), so a Redis outage returns a clean 503,
not a 500.

### Example session

```bash
curl -s localhost:8000/health
curl -s -c jar -b jar -H 'Content-Type: application/json' \
     -d '{"product_id":1,"quantity":2}' localhost:8000/api/cart/items
curl -s -c jar -b jar -H 'Content-Type: application/json' -H 'Accept: application/json' \
     -d '{"customer_name":"Kayes","customer_email":"kayes@example.com"}' localhost:8000/api/orders
# before the worker runs: confirmation_sent_at is null
curl -s localhost:8000/api/orders/1
curl -s -H 'Accept: application/json' -F image=@mug.png localhost:8000/api/products/2/image
```

---

## Operational behaviour worth knowing

- **Redis down:** `/health` → 503 (`redis: fail`). `/api/products` → **500** (cache is a hard
  dependency). Carts are **lost** (they live in Redis sessions). Checkout fails.
  `/up` still says 200: it cannot see Redis.
- **MySQL down:** `/health` → 503 (`database: fail`) within `DB_TIMEOUT` seconds.
- **Order placed but dispatch fails** (Redis dies between commit and dispatch): the order is
  saved in MySQL but the request returns 500 and no email is queued.
- **Failed jobs** (after 3 tries, backoff 10s/30s/60s) are recorded in the MySQL
  `failed_jobs` table, even though the queue itself is Redis.
- **After a deploy** the worker keeps running old code until `php artisan queue:restart`.
- **`config:cache`** freezes env values into `bootstrap/cache/config.php` (plaintext, includes
  secrets, gitignored). After it runs, changing env vars has no effect until it is re-run.
- Redis key prefixes: cache → `laravel-shop-api-database-laravel-shop-api-cache-*` in DB 1;
  sessions and the queue (`…queues:default`) live in DB 0.

---

## Project layout (the parts an operator touches)

```
bootstrap/app.php        routing + middleware (api group gets sessions; /health gets none)
config/                  the ONLY place env() is read
database/migrations/     schema (products, orders, order_items + framework tables)
database/seeders/        idempotent demo catalogue
routes/api.php           API routes (/api/*)
routes/health.php        /health (deep) and /
app/Jobs/SendOrderConfirmation.php   the queued job
storage/                 must be writable (logs, cache, local uploads)
phpunit.xml              test env (sqlite :memory:, array stores, sync queue)
```

---

## Push to GitHub

```bash
git remote add origin git@github.com:<your-user>/laravel-shop-api.git
git push -u origin main
```

Before pushing, confirm `git status` shows no `.env` and no `vendor/`.
