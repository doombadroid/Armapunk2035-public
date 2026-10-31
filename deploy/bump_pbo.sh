#!/bin/bash
# Atomically bump the mission PBO name in BOTH places (pack target + server.cfg template).
# They MUST match: a repack deletes the previous PBO, so a mismatch = server boots a missing mission.
# Usage: bash deploy/bump_pbo.sh 0183
set -euo pipefail
NEW="${1:?usage: bump_pbo.sh NNNN (e.g. 0183)}"
P="$(cd "$(dirname "$0")/.." && pwd)"
CUR=$(grep -o 'Loonybin_b[0-9]*' "$P/deploy/server.cfg" | head -1)
[ -n "$CUR" ] || { echo "cannot read current PBO name"; exit 1; }
sed -i "s/Loonybin_b[0-9]*/Loonybin_b${NEW}/g" "$P/deploy/run-boot2.sh" "$P/deploy/server.cfg"
A=$(grep -o 'Loonybin_b[0-9]*' "$P/deploy/server.cfg" | head -1)
B=$(grep -o 'Armapunk2035_b[0-9]*\.Malden\.pbo' "$P/deploy/run-boot2.sh" | head -1)
echo "bumped $CUR -> server.cfg=$A pack=$B"
[ "$A" = "Loonybin_b${NEW}" ] && [[ "$B" == "Loonybin_b${NEW}.Malden.pbo" ]] || { echo "MISMATCH -- fix before deploying"; exit 1; }
echo "OK: both aligned. Deploy must REPACK (FORCE_DEPLOY=1) or the new PBO will not exist."
