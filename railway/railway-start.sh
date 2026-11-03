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
tables=$(node -e "
const pg=require('/app/packages/db/node_modules/pg');const c=new pg.Client({connectionString:process.env.DATABASE_URL});
c.connect().then(()=>c.query(\"SELECT count(*)::int AS n FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'\")).then(r=>{console.log(r.rows[0].n);return c.end()}).catch(e=>{console.error(e.message);process.exit(1)})")
if [ "$tables" = "0" ]; then
  echo "[railway] fresh database: running init (db:assert-fresh, db:push-full, db:seed)"
  pnpm db:assert-fresh && pnpm db:push-full && pnpm db:seed
else
  echo "[railway] existing database (${tables} tables): running db:upgrade"
  pnpm db:upgrade
fi

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
