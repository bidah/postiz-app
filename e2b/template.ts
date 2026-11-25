// Postiz as ONE E2B sandbox — no Docker on your machine, no docker-compose.
//
// The upstream image (Debian bookworm + the built Postiz app + nginx on :5000)
// gets its dependencies installed beside it:
//   postgres 15  ·  redis 7  ·  Temporal dev server (single binary, SQLite)
// Temporal's dev server replaces the compose file's temporal + elasticsearch +
// second postgres. Everything is started by start.sh at RUNTIME (not at build),
// because FRONTEND_URL is the sandbox's own public URL: https://5000-<id>.e2b.app.
import { Template } from "e2b";

export const POSTIZ_IMAGE = process.env.POSTIZ_IMAGE || "ghcr.io/gitroomhq/postiz-app:latest";

export const template = Template()
  .fromImage(POSTIZ_IMAGE)
  .setUser("root")
  .aptInstall(["postgresql", "redis-server", "curl", "ca-certificates", "procps"], { noInstallRecommends: true })
  .runCmd([
    // Temporal CLI ships `temporal server start-dev` (frontend :7233, SQLite persistence).
    "curl -fsSL 'https://temporal.download/cli/archive/latest?platform=linux&arch=amd64' | tar -xz -C /usr/local/bin temporal",
    "temporal --version",
    "mkdir -p /uploads /var/lib/temporal /opt/postiz-e2b",
    // Postgres: one cluster, created at build so the first boot is fast.
    "pg_dropcluster --stop 15 main || true",
    "pg_createcluster 15 main",
    "sed -i \"s/^#listen_addresses.*/listen_addresses = 'localhost'/\" /etc/postgresql/15/main/postgresql.conf",
    "sed -i 's/^ssl = on/ssl = off/' /etc/postgresql/15/main/postgresql.conf",
  ])
  .copy("start.sh", "/opt/postiz-e2b/start.sh", { mode: 0o755 })
  .copy("stop.sh", "/opt/postiz-e2b/stop.sh", { mode: 0o755 })
  .setWorkdir("/app");
