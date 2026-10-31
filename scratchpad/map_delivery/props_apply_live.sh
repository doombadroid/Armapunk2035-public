#!/usr/bin/env bash
# The live step of the props migration, as one command, to be run when NOBODY is in the game:
# the rows and the stripped scenario must land together (a server restart is part of it), or
# every migrated prop is placed twice until they do.
#
#   scratchpad/map_delivery/props_apply_live.sh            # dry run against the LIVE table
#   scratchpad/map_delivery/props_apply_live.sh --apply    # rows + scenario + commit + deploy
#
# What it does with --apply:
#   1. tunnel to the live Postgres on the box, DSN read from the box's env for this process only
#   2. tools/map_migrate_props.py --apply  (rows into the live table, props out of the repo's sqm)
#   3. commit the scenario + undo log pointer
#   4. deploy/push-96.sh --no-notes  (server restart: boots with 13.5k table rows, without the props)
#   5. restart edenlive-host so it reseeds from the table
# Afterwards, by hand: rebuild the designer kits and republish the pages (the map staging changed).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
HOST="${HOST:-timb@10.1.24.96}"
SSH="ssh -i $HOME/.ssh/id_lb"
APPLY=""; [ "${1:-}" = "--apply" ] && APPLY="--apply"
PASS2=""; [ "${PASS:-1}" = "2" ] && PASS2="--pass2"

# refuse while someone is playing: the restart kicks them and the doubled props would confuse them
players=$($SSH "$HOST" 'curl -s -H "X-Eden-Token: $(cat ~/.config/armapunk/edenlive.token)" http://127.0.0.1:2331/players' | python3 -c 'import sys,json; print(",".join(p["name"] for p in json.load(sys.stdin) if p["name"] != "HC"))')
if [ -n "$players" ] && [ -n "$APPLY" ]; then echo "refusing: in the game right now: $players"; exit 1; fi

# the live DSN, for this process only (the file on the box has spaces in the value; read the line)
REMOTE_DSN=$($SSH "$HOST" "grep '^PYSQF_DB_DSN=' ~/.config/armapunk/pysqfd.env | cut -d= -f2-")
$SSH -f -N -L 15432:127.0.0.1:5432 "$HOST"
trap 'pkill -f "ssh -i $HOME/.ssh/id_lb -f -N -L 15432" >/dev/null 2>&1 || true' EXIT
sleep 1
export PYSQF_DB_DSN=$(echo "$REMOTE_DSN" | sed -E 's/port=[0-9]+/port=15432/; s/host=[^ ]+/host=127.0.0.1/')
echo "== live table before"; ~/pysqf-venv/bin/python - <<'PY'
import sys; sys.path.insert(0, "tools"); import apdb_dsn
c = apdb_dsn.connect(); cur = c.cursor()
cur.execute("SELECT count(*), max(rev) FROM map_objects WHERE world='Malden' AND NOT deleted"); print("rows, rev:", cur.fetchone())
PY

~/pysqf-venv/bin/python tools/map_migrate_props.py $PASS2 $APPLY
[ -n "$APPLY" ] || exit 0

echo "== live table after"; ~/pysqf-venv/bin/python - <<'PY'
import sys; sys.path.insert(0, "tools"); import apdb_dsn
c = apdb_dsn.connect(); cur = c.cursor()
cur.execute("SELECT count(*), max(rev) FROM map_objects WHERE world='Malden' AND NOT deleted"); print("rows, rev:", cur.fetchone())
PY
git add mission/Armapunk2035.Malden/mission.sqm
if [ -n "$PASS2" ]; then
git commit -q -F - <<'EOF'
mission.sqm: the server objects and the tree anchors now come from map_objects

Pass 2 of tools/map_migrate_props.py. 214 objects the designer had marked
`_serverObject = true` -- the fed gates, ring safes and walls, the evidence
lockup, the jewelry emporium, the gang compounds, the bridge -- are is_server
rows now: the server spawns them with a global createVehicle exactly as the
engine placed them, so fn_fedLockdown still animates their doors and the boot
resolvers still find them, and clients never stream a second copy. 96 tree
anchors became model rows pointing at the game's own tree models, with the
init's height offset, heading and scale, plus 75 class rows for the visible
grates and bins; the invisible helipads are gone and their unreferenced names
with them.

Left in this file on purpose: the units and their groups, the 60 player slots,
markers, logics, 68 crates, cargo nets, boats and scooters, and the named boat.

Co-Authored-By: Dr. Sbaitso
EOF
else
git commit -q -F - <<'EOF'
mission.sqm: the plain props now come from map_objects

3,907 objects the scenario placed itself -- chairs, tables, PC sets, clutter
cutters, racks and the rest of the static decor, none of them named, scripted,
playable or carrying cargo -- are map_objects rows from this commit on, so
every one of them can be moved live from Eden or F12. tools/map_migrate_props.py
wrote the rows against the live table and took the entities out of this file
in the same step; the undo log is in scratchpad/map_delivery/.

The scenario keeps what still has to be placed by the engine: 282 objects with
init scripts, 104 named ones, the units and their groups, the 60 player slots,
markers, logics, and 68 crates, cargo nets, boats and scooters.

Co-Authored-By: Dr. Sbaitso
EOF
fi
echo "== deploying (server restart)"; deploy/push-96.sh --no-notes | tail -3
$SSH "$HOST" 'systemctl --user restart edenlive-host; sleep 8; grep -h "EDENLIVE. seeded" ~/edenlive/EdenLive_Logs/*.log | tail -1; journalctl --user -u armapunk-arma --since "-3 min" --no-pager | grep "AP-MAP. boot" | tail -1 | cut -c1-140'
echo "next: rebuild the kits (Tools/designer_kit.sh for each designer) and republish the pages"
