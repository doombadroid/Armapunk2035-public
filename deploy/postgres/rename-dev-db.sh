#!/usr/bin/env bash
# Rename the dev database from `pgm_full_scratch` to `armapunk`, atomically.
#
# WHY. The dev server runs against `pgm_full_scratch` -- 66 tables, real player rows, the database
# every playtest has written to. `armapunk` is an empty 13-table shell the container created from
# compose.yml's POSTGRES_DB default and nothing has ever used. The names are exactly backwards from
# what anyone would guess, which has now cost debugging time twice: the obvious move on seeing a
# missing column is to look in `armapunk`, find it absent, and conclude the write failed.
#
# The name is a fossil. The database was created as the pgmigrate ETL's full-run scratch target and
# then quietly became the dev database because it was the fully-populated one.
#
# NEEDS ROOT, for /etc/conf.d/pysqfd alone. Run it as:  sudo bash deploy/postgres/rename-dev-db.sh
#
# It is ordered so a failure at any step leaves a working system: the dump happens before anything
# stops, the conf is only rewritten AFTER the rename succeeds, and the services come back last.
set -euo pipefail

PGC=armapunk-pg
OLD=pgm_full_scratch
NEW=armapunk
STALE_BAK="armapunk_empty_$(date +%Y%m%d)"
CONF=/etc/conf.d/pysqfd
DUMPDIR="${DUMPDIR:-/home/timb/db_final_dumps}"

[ "$(id -u)" -eq 0 ] || { echo "FATAL: needs root (only for $CONF)"; exit 1; }

echo "== 1. dump both databases first -- nothing has stopped yet"
mkdir -p "$DUMPDIR"
for db in "$OLD" "$NEW"; do
    out="$DUMPDIR/${db}_$(date +%Y%m%d_%H%M%S).sql.gz"
    docker exec "$PGC" pg_dump -U armapunk -d "$db" | gzip > "$out"
    echo "   $db -> $out ($(du -h "$out" | cut -f1))"
done

echo "== 2. stop the consumers (a rename needs zero connections)"
pkill -f 'name=loonydev' 2>/dev/null || true
rc-service pysqfd stop || true
sleep 3

echo "== 3. rename"
# The empty shell is kept, not dropped: a rename is reversible, a drop is not, and it costs nothing.
docker exec "$PGC" psql -U armapunk -d postgres -c "ALTER DATABASE $NEW RENAME TO $STALE_BAK"
docker exec "$PGC" psql -U armapunk -d postgres -c "ALTER DATABASE $OLD RENAME TO $NEW"
echo "   $NEW -> $STALE_BAK   (empty shell, kept for reversibility)"
echo "   $OLD -> $NEW         (the real dev database)"

echo "== 4. repoint the daemon"
sed -i "s/dbname=$OLD/dbname=$NEW/" "$CONF"
grep -q "dbname=$NEW" "$CONF" || { echo "FATAL: $CONF did not update -- daemon left stopped ON PURPOSE"; exit 1; }

echo "== 5. back up"
rc-service pysqfd start
sleep 2
rc-service pysqfd status || true
echo
echo "Done. Now redeploy the mission:  bash /home/timb/arma3server_dev/reload-armapunk2035.sh"
echo "Verify:  docker exec $PGC psql -U armapunk -d $NEW -tAc \"select count(*) from players\""
echo "Roll back: reverse the two ALTER DATABASE lines and the sed, then restart pysqfd."
