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
  mix phx.server
) &
PIDS+=("$!")

echo "Started Phoenix on http://localhost:4000"

echo "Notebooks: http://localhost:4000/notebooks"
echo "Live Apps:  http://localhost:4000/liveapps"

echo "Press Ctrl+C to stop all services."

wait
