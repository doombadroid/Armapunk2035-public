#!/usr/bin/env bash
# Bring the telemetry stack up (or apply a compose change) on the box this runs on.
#   deploy/telemetry/up.sh            # up -d
#   deploy/telemetry/up.sh down       # any other compose verb is passed through
# Reads ~/.config/armapunk/telemetry.env (GRAFANA_ADMIN_PASSWORD at least). Creates the data
# directories so the containers (running as $PUID) find them user-owned.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVF="${TELEMETRY_ENV:-$HOME/.config/armapunk/telemetry.env}"
if [ -f "$ENVF" ]; then set -a; . "$ENVF"; set +a; fi
: "${GRAFANA_ADMIN_PASSWORD:?GRAFANA_ADMIN_PASSWORD missing -- put it in $ENVF (chmod 600)}"
export TELEMETRY_DATA="${TELEMETRY_DATA:-$HOME/telemetry}"
export PUID="${PUID:-$(id -u)}"
mkdir -p "$TELEMETRY_DATA/vm" "$TELEMETRY_DATA/grafana"
VERB="${1:-up}"; shift || true
if [ "$VERB" = up ]; then set -- up -d "$@"; else set -- "$VERB" "$@"; fi
exec docker compose -p "${TELEMETRY_PROJECT:-armapunk-telemetry}" -f "$HERE/docker-compose.live.yml" "$@"
