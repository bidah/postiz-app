# Postiz on E2B

Run this Postiz fork as **one E2B sandbox** — nothing runs on your machine and
no Docker is needed anywhere: E2B builds the template in its cloud from the
upstream Postiz image.

```
postiz image (Debian, app built, nginx :5000)
 + postgres 15 + redis + Temporal dev server (SQLite)   ← replaces docker-compose
 start.sh   boots everything with FRONTEND_URL = https://5000-<sandboxId>.e2b.app
```

## Build the template

```bash
cd e2b && bun install
E2B_API_KEY=… bun build.ts            # template name: "postiz" (E2B_POSTIZ_TEMPLATE)
```

## Run

The CutAI server (`video-editor/server/src/postiz.ts`) owns the lifecycle:

1. `Sandbox.create("postiz", { lifecycle: { onTimeout: "pause", autoResume: true } })`
   — the sandbox pauses when idle and wakes on inbound traffic (API calls,
   OAuth callbacks, platforms fetching media), keeping the same public URL.
2. Runs `/opt/postiz-e2b/start.sh` with `FRONTEND_URL=https://<getHost(5000)>`,
   `JWT_SECRET` and the provider OAuth keys.
3. Registers the single admin org (`POST /api/auth/register`), then reads the
   org's Public API key from Postgres.

Public API: `https://5000-<id>.e2b.app/api/public/v1`, header `Authorization: <apiKey>`.

## Provider OAuth

Register these redirect URIs with each platform (they change if the sandbox is
recreated, so keep the sandbox long-lived):

```
{FRONTEND_URL}/integrations/social/youtube | tiktok | instagram | facebook | linkedin | x
```

Env names: `YOUTUBE_CLIENT_ID/SECRET`, `TIKTOK_CLIENT_ID/SECRET`,
`FACEBOOK_APP_ID/SECRET` (Facebook + Instagram), `INSTAGRAM_APP_ID/SECRET`
(Instagram standalone), `LINKEDIN_CLIENT_ID/SECRET`, `X_API_KEY/SECRET`.

## Caveats

- Scheduled posts fire from Temporal timers inside the sandbox, so the sandbox
  must be running at publish time. The CutAI server resumes it ahead of every
  scheduled post.
- Instagram and Facebook fetch the video by URL: `/uploads` is served on the
  sandbox's public HTTPS URL, which auto-resume makes reachable.
