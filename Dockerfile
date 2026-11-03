# Deft on Railway: the official AGPL-3.0 release image (pinned by digest) plus
#  - Caddy on Railway's $PORT doing upstream's documented single-origin routing
#    (/api, /socket.io, /oauth, /.well-known, /health -> API :3001, rest -> web :3000)
#  - a start script that waits for Postgres, runs upstream's one-shot init on a
#    fresh database (db:assert-fresh + db:push-full + db:seed) or db:upgrade on an
#    existing one, links both upload dirs to the volume, then runs upstream's entrypoint.
FROM caddy:2.11.7-alpine AS caddy
FROM ghcr.io/maneek21/deft:0.3.0-preview.140@sha256:e51ab47262a24661984ffdd092328cb8d5b1175c4f0099009d780a9fa1deb559
LABEL org.opencontainers.image.source="https://github.com/onepush-dev/deft" \
      org.opencontainers.image.licenses="AGPL-3.0-only"
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --chmod=644 railway/Caddyfile /app/railway/Caddyfile
COPY --chmod=755 railway/railway-start.sh /app/railway/railway-start.sh
COPY --chmod=644 railway/wait-for-db.mjs /app/railway/wait-for-db.mjs
COPY --chmod=644 railway/db-state.mjs /app/railway/db-state.mjs
ENV PORT=8080 \
    API_PORT=3001 \
    DEFT_SELF_HOSTED=true \
    DEFT_SOURCE_CODE_URL=https://github.com/onepush-dev/deft \
    XDG_CONFIG_HOME=/tmp/caddy-config \
    XDG_DATA_HOME=/tmp/caddy-data
EXPOSE 8080
CMD ["sh", "/app/railway/railway-start.sh"]
