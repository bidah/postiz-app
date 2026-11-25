#!/usr/bin/env bash
# Boot Postiz inside the sandbox. Idempotent: safe to run again after a
# cold boot (a resumed memory snapshot keeps everything running anyway).
#
# Required env: FRONTEND_URL (https://5000-<sandboxId>.e2b.app), JWT_SECRET.
# Optional: provider OAuth keys (YOUTUBE_CLIENT_ID, TIKTOK_CLIENT_ID, …),
#           DISABLE_REGISTRATION (default true: only the first org may sign up).
set -euo pipefail
: "${FRONTEND_URL:?FRONTEND_URL is required}"
: "${JWT_SECRET:?JWT_SECRET is required}"
LOG=/var/log/postiz-e2b
mkdir -p "$LOG" /uploads

# --- postgres -----------------------------------------------------------------
pg_ctlcluster 15 main start 2>/dev/null || true
for i in $(seq 1 30); do pg_isready -q && break; sleep 1; done
su postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='postiz'\"" | grep -q 1 \
  || su postgres -c "psql -c \"CREATE ROLE postiz LOGIN PASSWORD 'postiz'\""
su postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='postiz'\"" | grep -q 1 \
  || su postgres -c "createdb -O postiz postiz"

# --- redis --------------------------------------------------------------------
redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes --save 60 1 --dir /var/lib/redis

# --- temporal (dev server, SQLite) ---------------------------------------------
if ! (echo > /dev/tcp/127.0.0.1/7233) 2>/dev/null; then
  nohup temporal server start-dev --headless --ip 127.0.0.1 --port 7233 \
    --db-filename /var/lib/temporal/temporal.db --namespace default > "$LOG/temporal.log" 2>&1 &
  for i in $(seq 1 60); do (echo > /dev/tcp/127.0.0.1/7233) 2>/dev/null && break; sleep 1; done
fi

# --- postiz ---------------------------------------------------------------------
export MAIN_URL="$FRONTEND_URL"
export NEXT_PUBLIC_BACKEND_URL="$FRONTEND_URL/api"
export BACKEND_INTERNAL_URL="http://localhost:3000"
export DATABASE_URL="postgresql://postiz:postiz@localhost:5432/postiz"
export REDIS_URL="redis://localhost:6379"
export TEMPORAL_ADDRESS="localhost:7233"
export IS_GENERAL="true"
export DISABLE_REGISTRATION="${DISABLE_REGISTRATION:-true}"
export STORAGE_PROVIDER="${STORAGE_PROVIDER:-local}"
export UPLOAD_DIRECTORY="/uploads"
export NEXT_PUBLIC_UPLOAD_DIRECTORY="/uploads"
export API_LIMIT="${API_LIMIT:-90}"

if pgrep -f "pm2" >/dev/null && curl -fsS -o /dev/null http://localhost:5000/api/ 2>/dev/null; then
  echo "postiz already running"; exit 0
fi
pgrep -x nginx >/dev/null || nginx
cd /app
# prisma db push + pm2 (backend, frontend, orchestrator); pm2 daemonizes.
pnpm run prisma-db-push > "$LOG/prisma.log" 2>&1
pm2 delete all >/dev/null 2>&1 || true
pnpm run --parallel pm2 > "$LOG/pm2.log" 2>&1
for i in $(seq 1 180); do
  curl -fsS -o /dev/null "http://localhost:3000/" 2>/dev/null && curl -fsS -o /dev/null "http://localhost:5000/" 2>/dev/null && { echo "postiz ready"; exit 0; }
  sleep 2
done
echo "postiz did not become ready; see $LOG" >&2
exit 1
