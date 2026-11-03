# Deft on Railway

One-click Railway template for [Deft](https://github.com/Maneek21/Deft) — a self-hostable workspace where people and AI agents share chat, tasks, projects, notes, wiki, calendar and approvals, with an MCP server for personal AI clients.

Deploy button: _added after the template is generated_

## What this repo contains

- `Dockerfile` — `FROM ghcr.io/maneek21/deft:0.3.0-preview.140` (official AGPL-3.0 release image, pinned by digest), plus Caddy and a start wrapper. Built by GitHub Actions to `ghcr.io/onepush-dev/deft:0.3.0-preview.140`.
- `railway/Caddyfile` — upstream's documented single-origin routing on Railway's `$PORT`: `/api`, `/socket.io`, `/oauth`, `/.well-known`, `/health` → API (:3001), everything else → web (:3000).
- `railway/railway-start.sh` — waits for Postgres, runs upstream's one-shot `init` (`db:assert-fresh`, `db:push-full`, `db:seed`) on a fresh database or `db:upgrade` on an existing one, keeps both upload folders on the volume, sets all `NEXT_PUBLIC_*` URLs to the Railway public domain, then runs upstream's entrypoint.

## Services

| Service | Image | Volume |
|---|---|---|
| Deft | `ghcr.io/onepush-dev/deft:0.3.0-preview.140` | `/app/uploads` |
| Postgres | `pgvector/pgvector:0.8.7-pg16` (pgvector is required by Deft's schema) | `/var/lib/postgresql/data` |

## Variables

| Variable | Default |
|---|---|
| `Deft.DATABASE_URL` | `postgres://postgres:${{Postgres.POSTGRES_PASSWORD}}@${{Postgres.RAILWAY_PRIVATE_DOMAIN}}:5432/postgres` |
| `Deft.JWT_SECRET` | `${{secret(64)}}` |
| `Deft.JWT_REFRESH_SECRET` | `${{secret(64)}}` |
| `Deft.ENCRYPTION_KEY` | `${{secret(64)}}` (keep it with your backups) |
| `Deft.NEXT_PUBLIC_APP_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` (API/WS URLs default to the same origin) |
| `Postgres.POSTGRES_PASSWORD` | `${{secret(32)}}` |
| `Postgres.PGDATA` | `${{RAILWAY_VOLUME_MOUNT_PATH}}/pgdata` |

Optional: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY` (or add keys per workspace in Settings → AI), `R2_*` for Cloudflare R2 uploads, `METRICS_SCRAPE_TOKEN`, `VAPID_*` for browser push. If you use a custom domain, set `NEXT_PUBLIC_APP_URL` to it and redeploy.

## First run

Open the public URL and create the first account — it owns the workspace (signup closes after that; invite teammates from Settings → Members). AI features stay off until a provider key is added.

## License

Deft is AGPL-3.0-only. Corresponding source: upstream [Maneek21/Deft v0.3.0-preview.140](https://github.com/Maneek21/Deft/tree/v0.3.0-preview.140) plus this repo's wrapper files (`DEFT_SOURCE_CODE_URL` points here).
