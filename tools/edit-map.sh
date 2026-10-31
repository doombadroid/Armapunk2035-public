#!/usr/bin/env bash
# The map-editing entry point (design + rationale: mapedit.md; the table: mapdb.md).
#
#   tools/edit-map.sh          stage the edit mission FROM map_objects and print what to do next
#   tools/edit-map.sh push     write the editor's changes back into map_objects, by id
#   tools/edit-map.sh push --dry-run    report the diff, write nothing
#   tools/edit-map.sh watch    leave running: every 3DEN save is pushed by itself
#
# Everything the table places goes into MaldenEdit.Malden: the ~9,400 class rows (layer
# AP_MAPDATA) and the 85 custom .p3d buildings (AP_CUSTOM_P3D), every entity carrying its table id
# (AP_ID=) in the description. That mission is GENERATED and NEVER PACKED, so the shipped
# mission.sqm never gains table content and cannot ship it twice -- once as engine entities and
# once from the table.
#
# `apply` is retired (mapdb.md D7): it rewrote fn_mapData.sqf and malden_buildings.sqf, and
# neither exists any more. The running server picks a push up on its next poll (<= 10 s) --
# no repack, no restart, nobody reconnects.
#
# TWO MISSIONS, ONE RULE EACH:
#   mission/Armapunk2035.Malden/mission.sqm  -- SHIPPED. Never save it from 3DEN.
#   MaldenEdit.Malden                           -- GENERATED. Saving it is the point.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
# psycopg lives in the venv, not in system python; stage and push both read the table.
PY="$HOME/pysqf-venv/bin/python"

case "${1:-stage}" in
  stage)
    "$PY" tools/map_codegen.py stage
    cat <<'EOT'

IMPORTANT: if MaldenEdit is already OPEN in 3DEN, close the scenario (or restart Arma)
before editing further. 3DEN works from its in-memory copy, so a mission opened before this
staging will save that older state back over it -- which silently resurrects whatever was in
it. Staging cannot detect that; only closing and reopening can.

Next:
  1. Launch Arma 3 and open the "MaldenEdit" scenario in the 3DEN editor.
  2. Once per machine: Preferences -> uncheck "Save scenario in binarized form".
     A text .sqm is diffable, which is what makes silent damage visible.
  3. The NPC and custom-building anchors render as nothing. Draw their models with,
     in the Debug Console:
         call compile preprocessFileLineNumbers "edenDraw.sqf";
     Re-run it after moving things to snap the models back onto their anchors.
  4. Edit. Save (MaldenEdit only -- NEVER the shipped mission).
     Per-entity tokens in the Description field: AP_LOD=<0-3> sets the detail tier,
     AP_R=<metres> the stream-in radius (0 = always loaded). Leave them out to keep the row's.
  5. tools/edit-map.sh push        (or leave `tools/edit-map.sh watch` running)
EOT
    ;;
  watch)
    shift
    exec python3 tools/map_watch.py "$@"
    ;;
  apply)
    echo "apply is retired: use push (mapdb.md D7)" >&2
    exit 2
    ;;
  push)
    # The Eden loop's last mile: diff BOTH layers against map_objects by id and write the
    # difference. The running server picks it up on its next poll (<=10s) -- no repack, no
    # restart, nobody disconnected. Refuses a stale edit mission (re-stage first, or --force).
    shift
    exec "$PY" tools/map_push.py "$@"
    ;;
  *)
    echo "usage: tools/edit-map.sh [stage|push [--dry-run|--force]|watch [--once]]" >&2
    exit 2
    ;;
esac
