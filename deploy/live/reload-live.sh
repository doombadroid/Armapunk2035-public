#!/usr/bin/env bash
# LIVE reload for Armapunk 2035 on the .96 box (MIGRATION_96.md §5). Derived from deploy/reload-armapunk2035.sh:
# same pack pipeline, but no debug-console patch, no client-cache seed, secrets substituted into server.cfg,
# and the server is bounced through systemd (armapunk-arma.service) instead of nohup. Run by deploy/push-96.sh.
set -e
SRC="${AQ_SRC:-/home/timb/Armapunk2035}"
DEV=/home/timb/arma3server_live
DESC="$SRC/mission/Armapunk2035.Malden/description.ext"
SQM="$SRC/mission/Armapunk2035.Malden/mission.sqm"
CFGRE="$SRC/mission/Armapunk2035.Malden/CfgRE.hpp"
# ---- unique per-build mission name --------------------------------------------------------------
# Every deploy packs to Armapunk2035_bNNNN.Malden.pbo instead of overwriting one filename.
# Two things fall out of that, both of which cost real time before:
#   1. The client holds its CURRENT mission pbo open while Arma runs, so the cache seed below could
#      only land if you had fully exited to desktop first. A new build has a new filename, which is
#      not the file being held -- so the seed works with the game still running.
#   2. The stale-cache footgun disappears. A client can no longer silently keep playing an older
#      build, because the mission NAME changed; there is nothing old to match against.
# Same bNNNN convention the live deploy already uses.
BUILDF="$DEV/.build"   # live counter starts at 2000 (dev is ~1011): names can never collide
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
# ---- DEV-ONLY: stock debug console (owner 2026-09-08, "option A") ----------------------------
# While deploy/LIVE_IS_DEV exists, the PACKED CfgRE lets BIS_fnc_debugConsoleExec reach the server
# (allowedTargets = 2). That alone is gated: BI's function runs nothing until
# BIS_fnc_isDebugConsoleAllowed passes for remoteExecutedOwner (a #login admin, or a UID in
# description.ext's enableDebugConsole[]); anyone else gets "not allowed".
# `call` is NOT whitelisted any more (audit 2026-09-26 deploy-0-0). The 09-08 patch also added
# `class call {allowedTargets = 1;}` as the LOCAL/GLOBAL "return hop", and that let ANY joined client
# remoteExec arbitrary code onto every other client -- the owner's included, where it passes every
# server-side owner-UID check. So LOCAL/GLOBAL exec from the debug console may no longer work in MP
# (BI answers each button with its own remoteExec ["call", ...] from the server; the 09-08 patch
# needed `call` whitelisted for that, BIKI "Arma 3: CfgRemoteExec" says server-sent remoteExec is
# unfiltered -- not verified in-engine). Either way never re-add `call`: the check below refuses to pack.
# #login is part of the gate, so the patch is skipped while passwordAdmin would be a CHANGE_ME default.
# Applied to this box's MIRROR copy only -- push-96 re-mirrors the locked file on every deploy, so
# deleting the marker and pushing restores the lockdown with no other step. Idempotent.
SECRETS="$SRC/deploy/secrets.env"; [ -f "$SECRETS" ] && . "$SECRETS"
if [ -f "$SRC/deploy/LIVE_IS_DEV" ] && [[ "${AP_ADMIN_PW:-CHANGE_ME}" == CHANGE_ME* ]]; then
  echo "[mad] LIVE_IS_DEV: AP_ADMIN_PW unset/placeholder -- debug console NOT whitelisted (#login would grant code exec)"
elif [ -f "$SRC/deploy/LIVE_IS_DEV" ]; then
  python3 - "$CFGRE" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
if "DEV-ONLY (LIVE_IS_DEV)" in s:
    print("[mad] LIVE_IS_DEV: debug console patch already present in CfgRE.hpp"); sys.exit(0)
a = "//class BIS_fnc_debugConsoleExec {allowedTargets = 2;};"
if a not in s:
    sys.exit("[mad] FATAL: CfgRE.hpp anchor for the dev console patch not found -- refusing to pack")
s = s.replace(a, "class BIS_fnc_debugConsoleExec {allowedTargets = 2;};   // DEV-ONLY (LIVE_IS_DEV): reload-live.sh", 1)
p.write_text(s)
print("[mad] LIVE_IS_DEV: debug console whitelisted in the PACKED CfgRE (authorised callers only; `call` stays blocked)")
PY
  [ $? -eq 0 ] || exit 1
fi
if grep -qE 'class[[:space:]]+call[[:space:]]*\{' "$CFGRE"; then
  echo "[mad] FATAL: CfgRE.hpp whitelists \`call\` (any client could run code on the others) -- refusing to pack"; exit 1
fi
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

# (no client on this box: the dev script's MPMissionsCache seed is omitted)

# Keep only the last few builds. Each is ~149MB in BOTH mpmissions and the client cache, so without
# pruning this fills the disk in a couple of dozen iterations.
KEEP=3
for d in "$DEV/mpmissions"; do
    [ -d "$d" ] || continue
    ls -1t "$d"/Armapunk2035_b*.Malden.pbo 2>/dev/null | tail -n +$((KEEP+1)) | while read -r old; do
        rm -f "$old" && echo "[mad] pruned $(basename "$old")"
    done
done

# ---- server.cfg from the committed template + gitignored secrets, then bounce the unit -------------
# (deploy/secrets.env is sourced above, before the debug console patch)
sed -e "s|@AP_ADMIN_PW@|${AP_ADMIN_PW:-CHANGE_ME}|" -e "s|@AP_CMD_PW@|${AP_CMD_PW:-CHANGE_ME}|" -e "s|@AP_JOIN_PW@|${AP_JOIN_PW:-}|" \
    -e "s/template = \"[^\"]*\"/template = \"$MNAME\"/" "$SRC/deploy/live/server.cfg" > "$DEV/server.cfg"
grep -q "template = \"$MNAME\"" "$DEV/server.cfg" || { echo "[mad] FATAL: template substitution failed"; exit 1; }
export XDG_RUNTIME_DIR=/run/user/$(id -u)
START=$(date '+%Y-%m-%d %H:%M:%S')
systemctl --user restart armapunk-arma
echo "[mad] restarting LIVE (armapunk-arma.service) -- $MNAME ($(du -h "$DEV/mpmissions/$MNAME.pbo" | cut -f1))"

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
LOG="/tmp/armapunk-live-boot.log"
for _ in $(seq 1 40); do
    journalctl --user -u armapunk-arma --since "$START" -o cat --no-pager > "$LOG" 2>/dev/null
    grep -q "read from bank" "$LOG" 2>/dev/null && break
    sleep 3
done
journalctl --user -u armapunk-arma --since "$START" -o cat --no-pager > "$LOG" 2>/dev/null
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
