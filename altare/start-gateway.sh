#!/bin/sh
# Altare start wrapper for the Hermes Telegram gateway.
# - Seeds the Hermes home (/opt/data) with the checked-in config on first boot.
# - Serves a tiny health endpoint on $PORT so Altare can health-check the deploy
#   (the gateway itself has no HTTP port).
# - Runs the Telegram gateway as the main process.
set -e
HERMES_HOME="${HERMES_HOME:-/opt/data}"
SEED_DIR="/opt/hermes/docker"
for f in config.yaml SOUL.md channel_directory.json; do
  if [ ! -f "$HERMES_HOME/$f" ]; then
    mkdir -p "$HERMES_HOME"
    cp "$SEED_DIR/altare-$f" "$HERMES_HOME/$f" 2>/dev/null || true
  fi
done
PORT="${PORT:-3000}"
/opt/hermes/.venv/bin/python -m http.server "$PORT" --bind 0.0.0.0 >/tmp/altare-health.log 2>&1 &
exec hermes gateway run
