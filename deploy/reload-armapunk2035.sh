#!/usr/bin/env bash
# DEV reload for the Armapunk 2035 FORK (separate repo, not the loonybin overlay).
# Packs ~/Armapunk2035 straight through -- no overlay assembly, the fork IS the tree.
set -e
SRC="${AQ_SRC:-/home/timb/Armapunk2035}"
DEV=/home/timb/arma3server_dev
DESC="$SRC/mission/Armapunk2035.Malden/description.ext"
SQM="$SRC/mission/Armapunk2035.Malden/mission.sqm"
CFGRE="$SRC/mission/Armapunk2035.Malden/CfgRE.hpp"
# dev debug console, same patch the Altis dev flow uses; restored on exit
for f in "$DESC" "$CFGRE"; do [ -f "$f.reloadbak" ] && mv -f "$f.reloadbak" "$f"; cp "$f" "$f.reloadbak"; done
trap 'for f in "$DESC" "$CFGRE"; do mv -f "$f.reloadbak" "$f" 2>/dev/null; done || true' EXIT
sed -i 's/enableDebugConsole\[\]={"76561190000000001"};/enableDebugConsole=2;/' "$DESC"
sed -i 's|//class BIS_fnc_debugConsoleExec {allowedTargets = 2;};|class BIS_fnc_debugConsoleExec {allowedTargets = 0;};|' "$CFGRE"
# ---- unique per-build mission name --------------------------------------------------------------
# Every deploy packs to Armapunk2035_bNNNN.Malden.pbo instead of overwriting one filename.
# Two things fall out of that, both of which cost real time before:
#   1. The client holds its CURRENT mission pbo open while Arma runs, so the cache seed below could
#      only land if you had fully exited to desktop first. A new build has a new filename, which is
#      not the file being held -- so the seed works with the game still running.
#   2. The stale-cache footgun disappears. A client can no longer silently keep playing an older
#      build, because the mission NAME changed; there is nothing old to match against.
# Same bNNNN convention the live deploy already uses.
BUILDF="$DEV/.mad_build"
BUILD=$(( $( [ -f "$BUILDF" ] && cat "$BUILDF" || echo 0 ) + 1 ))
echo "$BUILD" > "$BUILDF"
MNAME=$(printf "Armapunk2035_b%04d.Malden" "$BUILD")
echo "[mad] packing mission as $MNAME (sounds/radio = 1MB promo only since the stream migration) ..."
# Map snapshot (mapdb.md D7): map_objects is the only source of placed objects and nothing in
# the PBO carries a row of it. Regenerate the committed snapshot OUTSIDE the mission
# (deploy/map_snapshot/map_objects.sqf) so git keeps a diff of every map change per deploy; the
# operator commits it. A failure here must stop the pack -- a deploy whose map history is not
# recorded is the thing the snapshot exists to prevent.
echo "[mad] regenerating deploy/map_snapshot/map_objects.sqf from map_objects ..."
"$HOME/pysqf-venv/bin/python" "$SRC/tools/map_generate.py" --write || { echo "[mad] FATAL: map_generate failed"; exit 1; }
# --exclude-list: the dev-only round-trip payload (deploy/pbo_exclude.txt) stays out of the PBO;
# tools/map_pbo_gate.py (run_checks.sh) keeps that list honest.
python3 "$SRC/deploy/pack_pbo.py" "$SRC/mission/Armapunk2035.Malden" \
        "$DEV/mpmissions/$MNAME.pbo" --no-prefix --exclude-list="$SRC/deploy/pbo_exclude.txt" >/dev/null
echo "[mad] packing AP_server ..."
mkdir -p "$DEV/@AP_server/addons"
# The server source dir is BRANCH-DEPENDENT: ap-rename-v2 renamed server/life_server ->
# server/AP_server, every other branch still has life_server. Packing a path that does not exist
# does NOT fail -- pack_pbo.py writes an 81-byte empty PBO and exits 0 -- and the only symptom is
# "Cannot open file .../@AP_server\addons\ap_server" at boot. So: detect, and die loudly if neither.
if   [ -d "$SRC/server/AP_server"   ]; then SRVSRC="$SRC/server/AP_server"
elif [ -d "$SRC/server/life_server" ]; then SRVSRC="$SRC/server/life_server"
else echo "[mad] FATAL: no server source dir (looked for server/AP_server and server/life_server)"; exit 1
fi
# LOWERCASE filename: Linux Arma lowercases addon paths before opening them, so AP_server.pbo warns
# ("not lowercase") and then fails to open as ap_server. The addon FOLDER name is not lowercased.
rm -f "$DEV/@AP_server/addons/AP_server.pbo"
python3 "$SRC/deploy/pack_pbo.py" "$SRVSRC" "$DEV/@AP_server/addons/ap_server.pbo" >/dev/null
echo "[mad]   server addon from ${SRVSRC##*/} -> $(stat -c %s "$DEV/@AP_server/addons/ap_server.pbo") bytes"
sed -i "s/template = \"[^\"]*\"/template = \"$MNAME\"/" "$DEV/server.cfg"

# ---- publish UI pages to the webpages serve root -------------------------------------------------
# fn_webPageSRV serves any page present under server/AP_server/web UNCONDITIONALLY, overriding the
# client's (possibly newer) mission copy -- there is no version check. The dir went stale at Aug 21
# and silently served the pre-mesh map.html to every client once the pysqfd daemon came up
# (2026-08-28 lesson: the whole mesh-map release never reached a player). So every deploy refreshes
# the CURATED set: files already present in the web root get the current mission copy. Live-editing
# a page in the web root is still fine between deploys, but the mission is the source of truth --
# backport or lose it here.
WEBROOT="$SRC/server/AP_server/web/ui/html"
if [ -d "$WEBROOT" ]; then
    PUB=0
    while IFS= read -r -d '' f; do
        rel="${f#"$WEBROOT"/}"
        m="$SRC/mission/Armapunk2035.Malden/ui/html/$rel"
        if [ -f "$m" ] && ! cmp -s "$m" "$f"; then cp -p "$m" "$f"; PUB=$((PUB+1)); fi
    done < <(find "$WEBROOT" -type f \( -name '*.html' -o -name '*.js' -o -name '*.css' \) -print0)
    echo "[mad] published $PUB UI page(s) to the webpages serve root"
fi

# ---- seed the CLIENT's mission cache so there is nothing to download -----------------------------
# The client and the dev server are the same box, so the PBO never actually needs to travel.
# Measured on this machine: Arma paces its own mission download at ~1.24 MB/s whether it uses the
# in-game transfer or missionHTTPDownloadBaseURL -- 149 MB took ~2 minutes either way, with 585 KB of
# TCP retransmits and a collapsed congestion window ON LOOPBACK, i.e. the client simply is not
# draining the socket. No server-side tuning can fix a receiver-paced transfer.
# Copying the freshly packed PBO straight into MPMissionsCache makes the client find it already
# present and current, and skip the transfer entirely. A completed download produces a byte-identical
# file, so a seeded copy is indistinguishable from a downloaded one.
# The client holds its CURRENT mission pbo open while running, which used to mean this copy could
# only land with Arma fully exited. Build-numbered names solve that: this is a NEW filename, so it is
# never the file being held, and the seed works with the game still open.
CACHE="/home/timb/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma 3/MPMissionsCache"
if [ -d "$CACHE" ]; then
    if cp -f "$DEV/mpmissions/$MNAME.pbo" "$CACHE/$MNAME.pbo" 2>/dev/null; then
        echo "[mad] seeded client cache: $MNAME.pbo ($(du -h "$CACHE/$MNAME.pbo" | cut -f1)) -- no download"
    else
        echo "[mad] WARNING could not seed client cache -- expect a ~2 min download"
    fi
fi

# Keep only the last few builds. Each is ~149MB in BOTH mpmissions and the client cache, so without
# pruning this fills the disk in a couple of dozen iterations.
KEEP=3
for d in "$DEV/mpmissions" "$CACHE"; do
    [ -d "$d" ] || continue
    ls -1t "$d"/Armapunk2035_b*.Malden.pbo 2>/dev/null | tail -n +$((KEEP+1)) | while read -r old; do
        rm -f "$old" && echo "[mad] pruned $(basename "$old")"
    done
done

pkill -f 'name=loonydev' 2>/dev/null || true
sleep 2
: > "$DEV/loonydev.log"
nohup bash "$DEV/run-armapunk2035.sh" > "$DEV/loonydev.log" 2>&1 &
echo "[mad] restarting on MALDEN — $MNAME ($(du -h "$DEV/mpmissions/$MNAME.pbo" | cut -f1))"

# ---- CONFIG GATE ---------------------------------------------------------------
# "read from bank" is NOT proof the mission is healthy. A description.ext that fails
# to parse still reaches it, and the server comes up with no Header, no disabledAI
# (AI fills every player slot), no enableDebugConsole and no CfgFunctions -- which
# reads as four unrelated bugs. That shipped on main for four builds on 2026-08-14
# because the post-deploy check only grepped for script errors, and a config abort
# is not one.
#
# One undefined base class in one dialog is enough to cause it, so this is checked
# on every deploy rather than remembered.
LOG="$DEV/loonydev.log"
for _ in $(seq 1 40); do
    grep -q "read from bank" "$LOG" 2>/dev/null && break
    sleep 3
done
sleep 3
if grep -qE "Undefined base class|some input after EndOfFile|Missing 'description.ext::Header'" "$LOG" 2>/dev/null; then
    echo
    echo "[mad] !!! CONFIG DID NOT PARSE -- the mission is up but description.ext was discarded."
    grep -nE "Undefined base class|some input after EndOfFile|Missing 'description.ext::Header'" "$LOG" | head -5 | sed 's/^/[mad]     /'
    echo "[mad]     Expect AI in every slot, no debug console, and AP_fnc_* undefined."
    echo "[mad]     Fix the named dialog and redeploy; do not test against this build."
    exit 1
fi
echo "[mad] config parsed clean (no undefined base classes, no EndOfFile, Header present)"
