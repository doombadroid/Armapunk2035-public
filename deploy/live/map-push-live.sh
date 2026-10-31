#!/usr/bin/env bash
# Replace LIVE map content with DEV's. Wholesale, by design (MIGRATION_96.md D7): the map is edited on dev only;
# live's F12 edits are overwritten by the next map push unless pulled back to dev first.
set -euo pipefail
SSH="ssh -i /home/timb/.ssh/id_lb -o BatchMode=yes"; HOST=timb@10.1.24.96
T="-t map_objects -t map_meta -t map_edit_log -t faction_territory"
docker exec armapunk-pg pg_dump -U armapunk -d pgm_full_scratch --data-only --disable-triggers $T | gzip > /tmp/mapcontent.sql.gz
scp -q -i /home/timb/.ssh/id_lb /tmp/mapcontent.sql.gz $HOST:/tmp/
$SSH $HOST 'bash -s' <<'REMOTE'
docker exec armapunk-pg psql -U armapunk -d armapunk -v ON_ERROR_STOP=1 -c "truncate map_objects, map_meta, map_edit_log, faction_territory" </dev/null
gunzip -c /tmp/mapcontent.sql.gz | docker exec -i armapunk-pg psql -U armapunk -d armapunk -v ON_ERROR_STOP=1 -q
docker exec armapunk-pg psql -U armapunk -d armapunk -tAc "select 'live map_objects='||count(*) from map_objects" </dev/null
REMOTE
echo "dev map_objects=$(docker exec armapunk-pg psql -U armapunk -d pgm_full_scratch -tAc 'select count(*) from map_objects')"
