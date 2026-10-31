#!/usr/bin/env bash
# Nightly dump of the live database. Local retention 14 days; samurai's cron pulls ~/pg_backups to the NAS.
set -euo pipefail
D="$HOME/pg_backups"; mkdir -p "$D"
OUT="$D/armapunk_$(date +%F_%H%M).dump"
docker exec armapunk-pg pg_dump -U armapunk -d armapunk -Fc > "$OUT"
find "$D" -name 'armapunk_*.dump' -mtime +14 -delete
echo "pg_backup: $(stat -c %s "$OUT") bytes -> $OUT"
