#!/usr/bin/env bash
# One-shot local playtest: boot full stack, wait for DB, then launch Arma3 client
# direct-connected to localhost (bypasses the launcher).
set -e

PROJ="$HOME/Documents/LooneyBin Altis Life"
PROFILES="$HOME/arma3server/profiles"
PORT=2302

echo "[1/4] starting server (background)..."
pkill -f arma3server_x64 2>/dev/null || true
sleep 1
nohup bash "$PROJ/deploy/run-boot2.sh" > /tmp/boot2-run.log 2>&1 &
echo "      server pid $!, console: $PROFILES/console.log"

echo "[2/4] waiting for 'Connected to Database' (max 60s)..."
ok=0
for i in $(seq 1 60); do
  if grep -q "Connected to Database" "$PROFILES/console.log" 2>/dev/null; then ok=1; echo "      DB connected at ${i}s"; break; fi
  if ! pgrep -f arma3server_x64 >/dev/null 2>&1; then echo "      !! server died:"; tail -25 "$PROFILES/console.log"; exit 1; fi
  sleep 1
done
[ "$ok" -ne 1 ] && { echo "      !! no DB in 60s:"; tail -25 "$PROFILES/console.log"; exit 1; }

echo "[3/4] giving mission 6s to init..."
sleep 6

echo "[4/4] launching client -> 127.0.0.1:$PORT (no launcher)..."
steam -applaunch 107410 -connect=127.0.0.1 -port=$PORT -noLauncher -nosplash -skipIntro -world=empty -name=looney &
echo "done. watch crash, then grep console.log + newest client rpt for 'CfgRemoteExec'."
