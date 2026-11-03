#!/bin/sh
# Railway start wrapper for Deft (see Dockerfile). Plain defaults live here because
# Railway templates only keep secret()/reference variables.
set -eu

: "${DATABASE_URL:?DATABASE_URL is required}"
if [ -z "${NEXT_PUBLIC_APP_URL:-}" ]; then
  if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then NEXT_PUBLIC_APP_URL="https://${RAILWAY_PUBLIC_DOMAIN}"; else NEXT_PUBLIC_APP_URL="http://localhost:${PORT}"; fi
fi
NEXT_PUBLIC_APP_URL="${NEXT_PUBLIC_APP_URL%/}"
# One public origin for web + API + websockets (upstream's recommended shape).
export NEXT_PUBLIC_APP_URL
export NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL:-$NEXT_PUBLIC_APP_URL}"
export NEXT_PUBLIC_WS_URL="${NEXT_PUBLIC_WS_URL:-$NEXT_PUBLIC_API_URL}"
export DEFT_PUBLIC_URL="${DEFT_PUBLIC_URL:-$NEXT_PUBLIC_APP_URL}"
export NODE_ENV=production
echo "[railway] public origin: ${NEXT_PUBLIC_APP_URL}"

# Railway allows one volume per service: keep both upstream upload paths on /app/uploads.
mkdir -p /app/uploads
if [ ! -L /app/apps/api/uploads ]; then
  if [ -d /app/apps/api/uploads ]; then cp -a /app/apps/api/uploads/. /app/uploads/ 2>/dev/null || true; rm -rf /app/apps/api/uploads; fi
  ln -s /app/uploads /app/apps/api/uploads
fi

cd /app
node /app/railway/wait-for-db.mjs

# Upstream's one-shot init/upgrade services, folded into startup.
init_fresh() {
  echo "[railway] fresh database: running init (db:assert-fresh, db:push-full, db:seed)"
  pnpm db:assert-fresh && pnpm db:push-full && pnpm db:seed
  node /app/railway/db-state.mjs mark
  echo "[railway] init complete"
}
state=$(node /app/railway/db-state.mjs state)
case "$state" in
  fresh) init_fresh ;;
  partial)
    echo "[railway] an earlier first-boot init did not finish and no accounts exist: resetting the empty schema and re-running init"
    node /app/railway/db-state.mjs reset
    init_fresh ;;
  ready|existing)
    echo "[railway] existing database (${state}): running db:upgrade"
    pnpm db:upgrade ;;
  *) echo "[railway] could not read database state"; exit 1 ;;
esac

# Upstream entrypoint starts API (:3001) and web (:3000); keep Railway's PORT for Caddy.
caddy run --config /app/railway/Caddyfile --adapter caddyfile &
caddy_pid=$!
env -u PORT sh /app/scripts/docker-entrypoint.sh &
app_pid=$!
trap 'kill -TERM $app_pid $caddy_pid 2>/dev/null; wait $app_pid 2>/dev/null; exit 0' TERM INT
while kill -0 $app_pid 2>/dev/null && kill -0 $caddy_pid 2>/dev/null; do sleep 1; done
kill -TERM $app_pid $caddy_pid 2>/dev/null || true
wait $app_pid 2>/dev/null || true
exit 1
