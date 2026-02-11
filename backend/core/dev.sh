#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd mix
require_cmd livebook
require_cmd caddy

if [[ ! -f "$ROOT_DIR/Caddyfile" ]]; then
  echo "Caddyfile not found at $ROOT_DIR/Caddyfile" >&2
  echo "Create it with the recommended reverse_proxy config first." >&2
  exit 1
fi

PIDS=()

cleanup() {
  for pid in "${PIDS[@]:-}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done
}

trap cleanup EXIT INT TERM

(
  cd "$ROOT_DIR"
  PORT=4001 mix phx.server
) &
PIDS+=("$!")

echo "Started Phoenix on http://localhost:4001"

(
  cd "$ROOT_DIR"
  LIVEBOOK_BASE_URL_PATH=/livebook \
  LIVEBOOK_PROXY_HEADERS="x-forwarded-for,x-forwarded-proto" \
  livebook server --port 8080
) &
PIDS+=("$!")

echo "Started Livebook on http://localhost:8080/livebook"

(
  cd "$ROOT_DIR"
  caddy run --config Caddyfile
) &
PIDS+=("$!")

echo "Started Caddy on http://localhost:4000"

echo "Notebooks: http://localhost:4000/notebooks"
echo "Live Apps:  http://localhost:4000/liveapps"

echo "Press Ctrl+C to stop all services."

wait
