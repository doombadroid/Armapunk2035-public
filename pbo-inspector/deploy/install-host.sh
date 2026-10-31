#!/usr/bin/env bash
# Persistence wiring for the Arma 3 PBO Inspector (run with sudo). Idempotent.
# Installs an OpenRC service that keeps the app on 127.0.0.1:3005 and enables it
# at boot. Public /pbo routing is handled separately in ~/.cloudflared/looneybin.yml.
set -euo pipefail

APP="/home/timb/loonybin-pbo"
DEPLOY="$APP/deploy"

echo ">> app launcher -> /usr/local/bin (space-free path for supervise-daemon)"
install -m 755 "$DEPLOY/run.sh" /usr/local/bin/loonybin-pbo-run

echo ">> install service"
install -m 755 "$DEPLOY/loonybin-pbo" /etc/init.d/loonybin-pbo
rc-update add loonybin-pbo default || true

echo ">> stop any manual preview process on :3005"
if command -v fuser >/dev/null 2>&1; then fuser -k 3005/tcp 2>/dev/null || true; fi
sleep 1

echo ">> start service"
rc-service loonybin-pbo restart
sleep 3

echo ">> status"
rc-service loonybin-pbo status || true

echo ">> check"
curl -s -o /dev/null -w "   app 127.0.0.1:3005/pbo = %{http_code} (307 = login redirect = up)\n" http://127.0.0.1:3005/pbo || true

echo ">> DONE — service enabled at boot. Add the /pbo ingress route to the tunnel next."
