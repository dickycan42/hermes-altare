# Hermes Agent on Altare (Always Free)

Runs the Hermes Telegram gateway (`@hermes_djarot_bot`) on Altare as a
**Docker App** (free tier: 6 GB RAM / 150% CPU / 10 GB disk shared team pool).

## What this repo is

A thin deploy wrapper around upstream `NousResearch/hermes-agent` (pinned commit
`b200f5b`, 2026-11-03). The `Dockerfile` is upstream's, retargeted so the source
is fetched as a tarball at build time; Altare-only additions are marked
`Altare:` in it.

- `Dockerfile` — builds the gateway image (upstream source + pinned SQLite +
  s6-overlay supervision). The image's default command runs the gateway.
- `altare/start-gateway.sh` — seeds `config.yaml` / `SOUL.md` /
  `channel_directory.json` into the home volume on first boot, serves a health
  endpoint on `$PORT`, runs `hermes gateway run`.
- `altare/config.yaml` — the working model config (custom provider, ArxPay
  endpoint `https://arxpay.my.id/v1`, model
  `deepseek-v4.1-flash-abliterated-2`). No secrets in this repo.
- `.github/workflows/docker-publish.yml` — builds the image on every push to
  `main` and publishes it to `ghcr.io/dickycan42/hermes-altare:latest`.

Origin: adapted from the earlier Cloady deploy wrapper (`hermes-cloady`,
0.5 vCPU / 1 GB RAM). Cloady-only files (compose file, env import) were
dropped — Altare deploys the prebuilt image instead.

## How Altare deploys this

Altare's **Bot Hosting** and **App Hosting** build plain Node/Python projects
from GitHub — they cannot build this Dockerfile. The supported path is a
**Docker App** (docs: `docs.altare.gg/apps/docker`): Altare pulls a prebuilt
image from a registry and runs it. That is what this repo publishes.

## Deploy (console)

Prerequisite: the GitHub Actions workflow on `main` must have finished once,
so `ghcr.io/dickycan42/hermes-altare:latest` exists (first build takes a
while — the upstream image builds SQLite from source plus the full frontend;
allow ~15–45 min).

1. Altare console → **Apps** → **New app** → **Docker image**.
2. Image: `ghcr.io/dickycan42/hermes-altare:latest` → **Check**.
3. **Port:** leave empty (a Telegram polling bot serves no traffic; the
   gateway itself has no HTTP port — the start script only serves a tiny
   health endpoint on `$PORT` if one is set).
4. **Data folder:** `/opt/data` — this is what keeps Hermes state (sessions,
   memories, `state.db`, seeded config) when the image is deployed again.
   Without it, a redeploy wipes the bot's memory.
5. **Start command:** `/opt/hermes/docker/start-gateway.sh` (same as the
   image's built-in default; setting it explicitly keeps the console honest).
6. **Variables** (set these in the console — never commit values):
   - `TELEGRAM_BOT_TOKEN` — the bot's token from BotFather (required).
   - `OPENAI_API_KEY` — the ArxPay API key (required; the custom provider
     reads this key for `https://arxpay.my.id/v1`).
   - `OPENROUTER_API_KEY` — set to the same ArxPay key (fallback path the
     config can use; harmless if unused).
   - `PORT` — optional; defaults to `3000` in the start script.
   - `GOOGLE_API_KEY` — not needed for the ArxPay setup (legacy from the
     earlier OpenRouter config); leave unset.
7. Region: pick any (the bot talks to Telegram/ArxPay outbound; latency to
   the user does not matter). Size: smallest that fits — the gateway ran
   fine on 0.5 vCPU / 1 GB RAM on Cloady.
8. Create the app. Watch **Logs**: the gateway is live when the bot answers
   on Telegram.

## Notes / limits

- Altare images run **linux/amd64 only** — the workflow builds amd64.
- The image is large (full Chromium + Node + Python venv + frontend). The
  console raises disk to the minimum for the unpacked image; the free team
  pool is 10 GB total, so this app takes a big share of it.
- `Update automatically` is off by default. Turn it on only if you want
  every new image push to redeploy the bot (state survives via the data
  folder, but a bad image still restarts the gateway).
- The upstream build fetches the hermes-agent tarball at build time; a
  failed build in Actions usually means a transient download blip — re-run
  the workflow.
- If Altare's free tier ever goes away, this same image runs anywhere Docker
  runs: `docker run -v hermes-data:/opt/data -e TELEGRAM_BOT_TOKEN=...
  -e OPENAI_API_KEY=... ghcr.io/dickycan42/hermes-altare:latest`.
