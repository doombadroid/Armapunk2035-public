#!/usr/bin/env bash
# Boot 2: FULL stack (extDB3 -> MariaDB). Reconstructed 2026-05-30 from profiles/console.log
# of the last known-good run (14:54: "extDB3 Loaded" / "Connected to Database").
# Use this to reproduce the JIP / CfgRemoteExec(mode=1) crash, then read logs.
#
# RECONSTRUCTED — verify on first run. If a flag is wrong, fix here and recommit.
set -e

PROJ="$HOME/Documents/LooneyBin Altis Life"
A3SRV="$HOME/.local/share/Steam/steamapps/common/Arma 3 Server"   # real server binary + @extDB3
PROFILES="$HOME/arma3server/profiles"                              # where console.log/Arma3Profile live
LIFE="$PROJ/server/AP_server"                                  # AP_server LOOSE source (packed pbo is stale)

# 0) never run two instances (a second one fails to grab port/DB and dies)
# Arma 3 2.22+ names the running process `rvMain`, so `pkill -x arma3server_x64` matched NOTHING from
# 2026-08-12 to 2026-09-02: every hard restart ADDED a server (random port, full mission logic vs the live
# DB) until the kernel OOM killer culled at random -- including the live one. Kill by CMDLINE ([a]rma =
# no self-match; `-config=` excludes the -client HC) and VERIFY the exit. Never `|| true` a kill.
pkill -f '[a]rma3server_x64 -config=server.cfg' 2>/dev/null || true
for _i in $(seq 1 30); do pgrep -f '[a]rma3server_x64 -config=server.cfg' >/dev/null || break; sleep 1; done
if pgrep -f '[a]rma3server_x64 -config=server.cfg' >/dev/null; then
  echo "[boot] old server survived SIGTERM for 30s -> SIGKILL"
  pkill -9 -f '[a]rma3server_x64 -config=server.cfg' 2>/dev/null || true; sleep 2
fi
pgrep -f '[a]rma3server_x64 -config=server.cfg' >/dev/null && echo "[boot] !! OLD SERVER STILL ALIVE after SIGKILL -- this boot will not get port 2302"

# 1) DB up (mariadb:11 container "looneybin-db"), then wait until it accepts connections.
#    IMPORTANT: the container MUST publish 3306 to the host (127.0.0.1:3306) — extDB3 connects
#    there. A bare `docker run mariadb` with no -p leaves Ports empty -> extDB3 logs
#    "Error with Database Connection" -> player-load query never returns -> client hangs at
#    waitUntil{AP_session_completed}. If the container exists but isn't publishing 3306,
#    recreate it (data is on the named volume looneybin-db-data, so it survives).
# The real data lives on this hash-named volume (15 tables). DO NOT use a fresh named volume here
# or you get an empty DB. (TODO: migrate to a clean named volume + compose.)
DB_VOL="16a82e22244752a0629a63a674048fd2a0373af3ab26ea3f00dd2abb7961035d"
if ! docker ps -a --format '{{.Names}}' | grep -qx looneybin-db; then
  docker run -d --name looneybin-db \
    -e MARIADB_ROOT_PASSWORD=looneybin -e MARIADB_DATABASE=looneybin \
    -e MARIADB_USER=looneybin -e MARIADB_PASSWORD=looneybin \
    -p 127.0.0.1:3306:3306 -v "$DB_VOL":/var/lib/mysql mariadb:11
elif ! docker port looneybin-db 3306 >/dev/null 2>&1; then
  echo "[boot2] looneybin-db not publishing 3306 — recreating (hash volume preserved)"
  docker rm -f looneybin-db
  docker run -d --name looneybin-db \
    -e MARIADB_ROOT_PASSWORD=looneybin -e MARIADB_DATABASE=looneybin \
    -e MARIADB_USER=looneybin -e MARIADB_PASSWORD=looneybin \
    -p 127.0.0.1:3306:3306 -v "$DB_VOL":/var/lib/mysql mariadb:11
else
  docker start looneybin-db
fi
for _i in $(seq 1 30); do
  if docker exec looneybin-db mariadb-admin ping -h 127.0.0.1 --silent 2>/dev/null \
     || docker exec looneybin-db mysqladmin ping -h 127.0.0.1 --silent 2>/dev/null; then
    echo "[boot2] mariadb ready"; break
  fi
  sleep 1
done

# owner 2026-06-14: clear any STALE restart trigger BEFORE the watchdog starts polling. The in-game
# escalation sets server_control.restart_now=1 when a restart doesn't land in 3 min; if the watchdog was
# down (or a power outage hit), that 1 persists in the DB. On the next boot the freshly-launched watchdog
# would see the leftover 1 and INSTANTLY pkill+relaunch -> "it restarted right after the 1-hour warning".
# Zero it here so a restart only fires from THIS session's scheduler.
docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" \
  -e "UPDATE server_control SET restart_now=0 WHERE id=1;" 2>/dev/null && echo "[boot2] cleared stale restart_now"

# owner 2026-06-18: ONE-TIME Sativa->Indica storage comp (player comp after sativa->wax removal). Runs ONCE here,
# while the server is OFFLINE (arma pkilled line 15, DB ready above) so an in-memory house save can't clobber it,
# converts cannas_3/cannas_0 -> cannai_3/cannai_0 in houses.vinv + vehicles.inventory (merging dup stacks), then
# drops a marker so it never repeats. Placed BEFORE the freeze block so it lands on the very next restart either
# way (it's a pure DB op, not a repack). Failure is NON-FATAL: the `if` condition is exempt from `set -e`, and the
# marker is only written on success -> a failed run just retries next boot, the server still launches.
if [ ! -f "$PROJ/deploy/.sativa_comp_done" ]; then
  echo "[boot] running one-time sativa->indica comp..."
  if python3 "$PROJ/deploy/sativa_comp.py" --apply; then
    touch "$PROJ/deploy/.sativa_comp_done"; echo "[boot] sativa comp applied -> marker set (won't repeat)"
  else
    echo "[boot] WARN: sativa comp FAILED -- will retry next boot; server launch continues"
  fi
fi

# owner 2026-06-18 (#374): ONE-TIME house-tax CLEAN SLATE. House-tax payments were broken the whole time --
# fn_houseTaxSRV paid `WHERE id='%1'` but the client sends the house OID (AP_houseID), not the `id` PK, so
# tax_paid never cleared and every house carries bogus accrued back-tax (relog -> re-charged). The code is fixed
# (WHERE oid) THIS deploy; reset every house's tax_paid=NOW ONCE here (offline, DB ready) so nobody is hit with a
# huge first bill. tax_playtime left intact (keeps earned playtime-discount). Marker so it never repeats; non-fatal.
if [ ! -f "$PROJ/deploy/.housetax_reset_done" ]; then
  echo "[boot] running one-time house-tax clean slate (tax_paid=NOW)..."
  if docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" \
       -e "UPDATE houses SET tax_paid=NOW();"; then
    touch "$PROJ/deploy/.housetax_reset_done"; echo "[boot] house-tax clean slate applied -> marker set (won't repeat)"
  else
    echo "[boot] WARN: house-tax reset FAILED -- will retry next boot; server launch continues"
  fi
fi

# owner 2026-06-25 (HOUSE FULL-TAKE DUPE): drop the `houses_no_wipe` BEFORE-UPDATE trigger (added live 06-25 18:16 as
# a stop-gap for the #542 house WIPE). It reverts ANY content->empty pinv/vinv UPDATE -- but a legit FULL-TAKE writes
# the SAME empty value, so the trigger reverted real takes: the house kept the gear the player already pocketed =
# server-wide dupe (confirmed live: a `UPDATE ... pinv='[[],0]'` at a full-take was silently reverted, the re-open
# re-showed the full kit). A DB trigger CANNOT tell a take from a wipe -- both write empty. The WIPE is already
# handled upstream in SQF: APS_fnc_updateHouseTrunk's b0094 AP_invHydrated guard reverts an UNHYDRATED empty write
# to the server-local contents BEFORE it reaches the DB, so wipes never persist empty -- only legit takes do. Hence
# the trigger only ever blocked legit takes. Idempotent (IF EXISTS) -> safe to run every boot; non-fatal.
docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" \
  -e "DROP TRIGGER IF EXISTS houses_no_wipe;" 2>/dev/null && echo "[boot] dropped houses_no_wipe trigger (full-take dupe fix; wipe now guarded in SQF)"

# owner 2026-07-10: house RENAME feature -- ensure houses.custom_name exists (idempotent; runs BEFORE the
# server loads so the queryHouses SELECT of custom_name never hits "Unknown column"). Non-fatal.
docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" \
  -e "ALTER TABLE houses ADD COLUMN IF NOT EXISTS custom_name VARCHAR(32) DEFAULT NULL;" 2>/dev/null && echo "[boot] houses.custom_name ensured (house-rename)"
# owner 2026-07-10: house FURNITURE persistence -- the DBs already carry houses.furniture, but neither the
# schema file nor this boot script ever declared it; ensure it (idempotent) so a fresh install persists too.
docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" \
  -e "ALTER TABLE houses ADD COLUMN IF NOT EXISTS furniture TEXT DEFAULT NULL;" 2>/dev/null && echo "[boot] houses.furniture ensured (furniture persistence)"
docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" \
  -e "ALTER TABLE houses ADD COLUMN IF NOT EXISTS helipad TINYINT(1) NOT NULL DEFAULT 0;" 2>/dev/null && echo "[boot] houses.helipad ensured (shed helipad upgrade)"
docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" \
  -e "ALTER TABLE houses ADD COLUMN IF NOT EXISTS malden TINYINT(1) NOT NULL DEFAULT 0;" 2>/dev/null && echo "[boot] houses.malden ensured (Malden Makeover)"
docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" \
  -e "ALTER TABLE houses ADD COLUMN IF NOT EXISTS malden_skin VARCHAR(16) NOT NULL DEFAULT '';" 2>/dev/null && echo "[boot] houses.malden_skin ensured (Malden Makeover skin picker)"
docker exec looneybin-db mariadb -ulooneybin -plooneybin looneybin \
  -e "ALTER TABLE houses ADD COLUMN IF NOT EXISTS rig VARCHAR(64) DEFAULT NULL;" 2>/dev/null && echo "[boot] houses.rig ensured (placeable crypto mining rig)"
# owner 2026-07-22: MULTI-RIG (max 5 per player, spread across owned houses) -- per-rig rows replace the
# single houses.rig/miner slot. Table creation is additive/idempotent so it can run on ANY boot; the
# DESTRUCTIVE legacy copy-in (which NULLs houses.rig/miner) is deferred to the FREEZE=0 one-shot block
# below -- running it on a frozen/natural boot while the OLD PBO (which still reads houses.rig) is live
# would despawn every placed rig until the multi-rig code actually deploys. (Defused 2026-07-23.)
docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" \
  -e "CREATE TABLE IF NOT EXISTS house_rigs (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        oid VARCHAR(64) NOT NULL,
        owner VARCHAR(32) NOT NULL,
        pos VARCHAR(96) NOT NULL,
        since INT UNSIGNED NOT NULL,
        last_collect INT UNSIGNED NOT NULL,
        PRIMARY KEY (id), KEY idx_oid (oid), KEY idx_owner (owner)
      );" 2>/dev/null && echo "[boot] house_rigs table ensured (multi-rig; legacy copy-in deferred to deploy boot)"
# owner 2026-07-11 (THE INTAKE Act 1): players.intake_path -- 0 pending / 1-3 path / 9 skipped. The one-time
# backfill grandfathers every EXISTING account to 9 so veterans never wake up committed; only accounts
# created after this (INSERT default 0) get the onboarding. Marker-guarded, non-fatal.
docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" \
  -e "ALTER TABLE players ADD COLUMN IF NOT EXISTS intake_path TINYINT(1) NOT NULL DEFAULT 0;" 2>/dev/null && echo "[boot] players.intake_path ensured (Intake Act 1)"
docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" \
  -e "ALTER TABLE players ADD COLUMN IF NOT EXISTS intake_step TINYINT UNSIGNED NOT NULL DEFAULT 0;" 2>/dev/null && echo "[boot] players.intake_step ensured (Parole Papers Act 2)"
if [ ! -f "$PROJ/deploy/.intake_backfill_done" ]; then
  if docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" \
       -e "UPDATE players SET intake_path=9 WHERE intake_path=0; UPDATE players SET intake_step=255 WHERE intake_step=0;"; then
    touch "$PROJ/deploy/.intake_backfill_done"; echo "[boot] intake backfill: existing accounts grandfathered (won't repeat)"
  else
    echo "[boot] WARN: intake backfill FAILED -- will retry next boot"
  fi
fi

# 2) extDB3 config -> point extDB3 at the docker MariaDB. The repo file keeps the password as
#    the placeholder CHANGE_ME (no credential in git); inject the real one into the DEPLOYED
#    copies only. Override with: LOONEYBIN_DB_PASS=... ./run-boot2.sh  (default matches the
#    looneybin-db container's MARIADB_PASSWORD).
DB_PASS="${LOONEYBIN_DB_PASS:-looneybin}"
# extDB3 reads the conf from BOTH the server root and @extDB3 depending on version — stage both.
sed "s/CHANGE_ME/${DB_PASS}/" "$PROJ/server/extdb3-conf.ini" > "$A3SRV/@extDB3/extdb3-conf.ini"
sed "s/CHANGE_ME/${DB_PASS}/" "$PROJ/server/extdb3-conf.ini" > "$A3SRV/extdb3-conf.ini"

# ---- NIGHTLY DEPLOY FREEZE (owner 2026-06-17: "no updates staged for restart-install after 10pm; sleepy time")
# A "restart-install" = repacking the LOOSE source into fresh mission/AP_server PBOs + signing + posting
# patch notes = installing staged edits. During the freeze window we SKIP all of that and relaunch the PBOs
# ALREADY deployed in $A3SRV, so a crash / watchdog / scheduled restart still brings the server back -- but on
# the LAST-DEPLOYED build, never half-finished overnight staging (and no premature patch notes / no
# version<->template mismatch). Recovery can't brick: nothing already-live is touched, only the INSTALL is
# deferred. Override for an emergency hotfix you DO want live now: FORCE_DEPLOY=1. Manual hold any time:
# create deploy/.deploy_freeze (rm it to lift).
FREEZE=0
_hr=$(date +%H)                                              # local hour, 00-23
if [ "$_hr" -ge 22 ] || [ "$_hr" -lt 9 ]; then FREEZE=1; fi  # nightly window: 22:00 -> 08:59 local
[ -f "$PROJ/deploy/.deploy_freeze" ] && FREEZE=1             # manual hold flag (create file to freeze any time)
[ "${FORCE_DEPLOY:-0}" = "1" ] && FREEZE=0                   # explicit override wins
# owner 2026-06-18: ONE-SHOT force-deploy past the nightly freeze. deploy/.force_deploy_once lifts the freeze for
# the NEXT restart ONLY (the owner wants a staged batch live tonight after 22:00 -- the watchdog can't pass an env
# var, so a file is the trigger), then self-deletes so the freeze resumes for every restart after.
[ -f "$PROJ/deploy/.force_deploy_once" ] && { FREEZE=0; rm -f "$PROJ/deploy/.force_deploy_once"; echo "[boot] .force_deploy_once -> freeze lifted for THIS restart only (one-shot), file removed"; }
# owner 2026-06-18: HARD restart = relaunch the ALREADY-DEPLOYED PBOs, NEVER repack. The restart_watchdog sets
# NO_REPACK=1 for a HARD restart (server_control.hard_pending=0: in-game HARD button + the 4h auto-restart); it
# forces the freeze branch regardless of clock/flags so a HARD restart can't deploy staged code. UPDATE restarts
# pass FORCE_DEPLOY=1 instead (above) to repack + force through the freeze. NO_REPACK wins last on purpose.
[ "${NO_REPACK:-0}" = "1" ] && FREEZE=1
# owner 2026-06-20: SHIP STAGED CODE AT THE NEXT NATURAL RESTART (no double-restart). `touch deploy/.repack_on_restart`
# to queue it; the next scheduled / in-game HARD restart (which normally NO_REPACK-reloads) then REPACKS the staged
# source instead, and the flag self-deletes (one-shot). This converts the already-coming 4h restart into the deploy so
# the operator doesn't fire a SEPARATE FORCE_DEPLOY restart on top of it. RESPECTS the nightly window + .deploy_freeze:
# if the next restart is frozen for one of those deliberate holds it stays frozen and the flag WAITS (only consumed
# when it actually repacks), so this never surprise-deploys overnight or past a manual hold. Placed AFTER the NO_REPACK
# line so it overrides NO_REPACK; bump the version + drop deploy/patchnote_override.txt before queueing, same as a deploy.
if [ -f "$PROJ/deploy/.repack_on_restart" ] && [ "$_hr" -lt 22 ] && [ "$_hr" -ge 9 ] && [ ! -f "$PROJ/deploy/.deploy_freeze" ]; then
  FREEZE=0; rm -f "$PROJ/deploy/.repack_on_restart"
  echo "[boot] .repack_on_restart -> repacking staged code on THIS natural restart (one-shot, flag removed)"
fi
# owner 2026-07-14: PRE-DEPLOY REGRESSION GUARD (after the b0166 cascade). Placed BEFORE the freeze gate so a
# failing guard drops into the SAME safe path as a freeze -- relaunch the existing PBOs AS-IS (no repack, no
# server.cfg rewrite -> no version/template mismatch, server never left down). Blocks when the mission source
# about to be packed is BEHIND the live PBO (core files shrank/vanished = git-synced source clobbered on-box
# edits, the exact b0166 signature). rc 3 = regression -> freeze; rc !=0/!=3 = guard errored -> proceed.
if [ "$FREEZE" != "1" ] && [ "${DEPLOY_GUARD_OVERRIDE:-0}" != "1" ] && [ -f "$PROJ/deploy/predeploy_guard.py" ]; then
  _gpbo=$(ls -t "$A3SRV/mpmissions/"Loonybin_b*.Malden.pbo 2>/dev/null | head -1)
  if [ -n "$_gpbo" ]; then
    python3 "$PROJ/deploy/predeploy_guard.py" "$PROJ/mission/Armapunk2035.Malden" "$_gpbo"; _grc=$?
    if [ "$_grc" = "3" ]; then
      FREEZE=1
      echo "[boot] *** predeploy_guard BLOCKED this deploy (source behind live PBO -- b0166 signature). Relaunching existing PBO AS-IS. Set DEPLOY_GUARD_OVERRIDE=1 to force. ***"
      mkdir -p "$PROJ/loonybot/outbox" && printf '{"channel_id":100000000000000047,"content":":octagonal_sign: **Deploy BLOCKED by regression guard** -- mission source is behind the live PBO (core files shrank/vanished = the b0166 cascade signature). Relaunched the existing PBO unchanged. Reconcile git vs on-box or redeploy with DEPLOY_GUARD_OVERRIDE=1."}' > "$PROJ/loonybot/outbox/guardblock_$(date +%s).json" 2>/dev/null || true
    elif [ "$_grc" != "0" ]; then
      echo "[boot] WARN: predeploy_guard errored (rc=$_grc) -- proceeding without it."
    fi
  fi
fi
if [ "$FREEZE" = "1" ]; then
  echo "[boot] *** DEPLOY FROZEN ($(date '+%F %T')) -- relaunching the already-deployed PBOs AS-IS; NOT repacking staged source, signing, or posting patch notes. Set FORCE_DEPLOY=1 to override. ***"
else
# 3) stage mission as a PACKED .pbo (NOT a loose folder).
#    With a loose mpmissions folder + filePatching, the server runs scripts locally but the
#    __cur_mp.pbo it builds to TRANSFER to clients comes out near-empty (~4KB: description.ext
#    only, no .sqf/.sqm) -> clients get a shell mission -> initPlayerLocal/init.sqf never run on
#    the client -> spawn on debug island, no UI. Packing a real .pbo makes the server send a
#    complete mission. --no-prefix: missions must have NO pbo prefix (filename = identity).
mkdir -p "$A3SRV/mpmissions"
# 3-bak) PBO ROLLBACK BACKUP (owner 2026-06-16): a bad deploy caused a join-kick storm with NO rollback,
#   because run-boot2 deletes every prior PBO before repacking. Archive the CURRENTLY deployed mission PBO
#   (+ its .bisign) here BEFORE the wipe, keeping the last 5. Restore = copy one back into mpmissions and
#   point server.cfg `template` at it.
BKDIR="$PROJ/deploy/pbo_backups"; mkdir -p "$BKDIR"
_curpbo=$(ls -t "$A3SRV/mpmissions/"Loonybin_b*.Malden.pbo 2>/dev/null | head -1)
if [ -n "$_curpbo" ] && [ -f "$_curpbo" ]; then
    _stamp=$(date +%Y%m%d_%H%M%S); _base=$(basename "$_curpbo" .pbo)
    cp "$_curpbo" "$BKDIR/${_base}_${_stamp}.pbo"
    [ -f "$_curpbo.looneybin.bisign" ] && cp "$_curpbo.looneybin.bisign" "$BKDIR/${_base}_${_stamp}.pbo.looneybin.bisign"
    ls -t "$BKDIR/"*.pbo 2>/dev/null | tail -n +6 | while read -r _old; do rm -f "$_old" "$_old.looneybin.bisign"; done
    echo "[backup] archived $(basename "$_curpbo") -> $BKDIR (keeping last 5)"
fi
rm -rf "$A3SRV/mpmissions/"Armapunk2035.Malden* "$A3SRV/mpmissions/"Loonybin_b*.Malden.pbo
python3 "$PROJ/deploy/pack_pbo.py" "$PROJ/mission/Armapunk2035.Malden" "$A3SRV/mpmissions/Armapunk2035_b0169.Malden.pbo" --no-prefix
# publish mission PBO for HTTP fast-download (missionHTTPDownloadBaseURL origin -> missionfiles.service on :8091)
# owner 2026-07-11: RESTORED after a repo-copy sync clobbered it (this block was on-box-only; now in git too).
WEBMISSIONS="$HOME/webmissions"; mkdir -p "$WEBMISSIONS"
rm -f "$WEBMISSIONS/"Loonybin_b*.Malden.pbo
_NEWPBO=$(ls -t "$A3SRV/mpmissions/"Loonybin_b*.Malden.pbo 2>/dev/null | head -1)
[ -n "$_NEWPBO" ] && { cp "$_NEWPBO" "$WEBMISSIONS/"; echo "[webmissions] published $(basename "$_NEWPBO")"; }
# owner 2026-07-10 (security): substitute the real admin passwords from the gitignored secrets.env into the
# deployed server.cfg (same pattern as the extdb3 CHANGE_ME sed above). Missing/unset -> harmless placeholder.
[ -f "$PROJ/deploy/secrets.env" ] && . "$PROJ/deploy/secrets.env"
sed -e "s|@AP_ADMIN_PW@|${AP_ADMIN_PW:-CHANGE_ME_ADMIN}|" -e "s|@AP_CMD_PW@|${AP_CMD_PW:-CHANGE_ME_CMD}|" \
    "$PROJ/deploy/server.cfg" > "$A3SRV/server.cfg"
cp "$PROJ/deploy/basic.cfg"  "$A3SRV/basic.cfg"
# owner 2026-06-16 (#309): install the server profile that defines CustomDifficulty. server.cfg selects
# difficulty="Custom", which reads class DifficultyPresets->CustomDifficulty from THIS profile (path is
# $PROFILES/home/<name>/<name>.Arma3Profile, name=looneybin per the launch line). It sets
# mapContentFriendly=0 so civilians stop seeing the (civ-friendly) MaxSec units natively move on the map.
# Overwrite each deploy = single source of truth; the engine re-appends activeKeys at runtime (cosmetic).
mkdir -p "$PROFILES/home/looneybin"
cp "$PROJ/deploy/looneybin.Arma3Profile" "$PROFILES/home/looneybin/looneybin.Arma3Profile"

# 3b) PACK AP_server -> a FRESH .pbo from current source, then stage it.
#     Arma's dedicated addon scanner only loads *.pbo (it will NOT load an unpacked addon folder;
#     -filePatching is for missions, not addons/). The prebuilt pbo in ~/arma3server is STALE
#     (predates later fixes, e.g. broken fn_weatherSync -> "Error Missing }" at init -> client
#     hangs at waitUntil{AP_session_completed}). We pack with deploy/pack_pbo.py (stdlib, no deps).
rm -rf "$A3SRV/@AP_server"
mkdir -p "$A3SRV/@AP_server/addons"
python3 "$PROJ/deploy/pack_pbo.py" "$PROJ/server/AP_server" "$A3SRV/@AP_server/addons/AP_server.pbo"

# 3b-sig) ANTI-CHEAT (owner 2026-06-13): sign the packed PBOs + stage the .bikey and BattlEye filters.
#   @AP_server loads as -mod, so with verifySignatures=2 it MUST be signed or the server rejects it.
#   Keypair lives in deploy/keys (made once: deploy/tools/armake keygen looneybin). The mission pbo is
#   signed too (harmless; missions aren't client-sig-checked, keeps the keyset consistent).
ARMAKE="$PROJ/deploy/tools/armake"
PRIVKEY="$PROJ/deploy/keys/looneybin.biprivatekey"
if [ -x "$ARMAKE" ] && [ -f "$PRIVKEY" ]; then
    "$ARMAKE" sign "$PRIVKEY" "$A3SRV/@AP_server/addons/AP_server.pbo" || echo "[sign] AP_server FAILED"
    _MPBO=$(ls "$A3SRV/mpmissions/"Loonybin_b*.Malden.pbo 2>/dev/null | head -1)
    # owner 2026-06-18: the mpmissions pbo-rm glob (Loonybin_b*.Malden.pbo) does NOT catch the old
    # .pbo.<key>.bisign, so a same-version redeploy hit "File ... .bisign already exists and --force
    # was not set" -> [sign] mission FAILED -> stale/mismatched mission signature. Drop the old sig first.
    [ -n "$_MPBO" ] && { rm -f "$_MPBO".*.bisign; "$ARMAKE" sign "$PRIVKEY" "$_MPBO" || echo "[sign] mission FAILED"; }
    mkdir -p "$A3SRV/keys"
    # Copy EVERY .bikey from deploy/keys/ -> the server keys/ dir. looneybin.bikey verifies @AP_server +
    # the mission. Any OPTIONAL client mod's .bikey dropped in deploy/keys/ (e.g. JSRS SOUNDMOD 2025,
    # workshop 3407948300) is whitelisted so a player who CHOOSES to load that mod passes verifySignatures=2.
    # Optional mods are deliberately NOT added to -mod/-serverMod, so they stay opt-in: the server neither
    # runs nor requires them; players who don't load them are unaffected. (See deploy/keys/OPTIONAL_MODS.md.)
    cp "$PROJ/deploy/keys/"*.bikey "$A3SRV/keys/" 2>/dev/null || true
else
    echo "[sign] armake or private key MISSING -> PBOs UNSIGNED; verifySignatures=2 will reject @AP_server!"
fi
# stage BattlEye filters (log-only action 1; tune from be.log, then raise actions to 7 to enforce)
# + the RCON config (beserver_x64.cfg = RConPassword/RConPort for BattleMetrics).
mkdir -p "$A3SRV/battleye"
cp "$PROJ/deploy/battleye/"*.txt "$A3SRV/battleye/" 2>/dev/null || true
cp "$PROJ/deploy/battleye/"*.cfg "$A3SRV/battleye/" 2>/dev/null || true
# owner 2026-06-16: Linux BE SELF-RELOCATES beserver_x64.so into battleye/launch[/battleye] and reads its RCON
# cfg from the dir holding the RUNNING .so -- NOT battleye/. -bepath=battleye did not stop the relocation, so
# RConPassword/RConPort were never read and RCON (2310) never bound (BattleMetrics couldn't connect). Propagate
# the cfg next to EVERY relocated beserver_x64.so so RCON binds wherever BE ends up. Takes effect next launch.
find "$A3SRV/battleye" -iname "beserver_x64.so" -print0 2>/dev/null | while IFS= read -r -d '' _so; do
    _bd=$(dirname "$_so")
    cp "$PROJ/deploy/battleye/beserver_x64.cfg" "$_bd/beserver_x64.cfg" 2>/dev/null || true
    cp "$PROJ/deploy/battleye/beserver.cfg"     "$_bd/beserver.cfg"     2>/dev/null || true
    cp "$PROJ/deploy/battleye/"*.txt "$_bd/" 2>/dev/null || true   # SECURITY 2026-07-07: BE reads its FILTERS from the relocated .so dir too -- propagate or ZERO filters load (no logging, no 2nd layer)
done

# 3c) patch notes on EVERY pack (owner 2026-06-10): collect BUGS.md "(reboot pending" entries that
#     ship in this pack, mark them deployed, drop the announcement in loonybot/outbox -> the bot
#     posts it to the patch-notes channel with the version from version.hpp.
python3 "$PROJ/deploy/gen_patchnotes.py" || true
fi   # ---- end NIGHTLY DEPLOY FREEZE guard (frozen = skipped everything above since "# 3) stage mission") ----

# ---- ONE-TIME #462 STATS DE-CLOBBER MIGRATION (owner 2026-06-21) -------------------------------------------
# players_global.stats was a SHARED column: the 17-slot A_stats achievement array (slot4=civArrests) AND the
# 148-slot lifetime array (slot4=prisontime) clobbered each other -> a high prison-time player read as
# civArrests>=50 -> false Bounty Hunter achievement granted when the clothing shop closed (#462). The deployed
# code now SPLITS them: the lifetime array moves to its own `lifetime_stats` column (fn_statTableUpdate +
# fn_getStatsArr), `stats` stays A_stats only, and the loader rejects >17-length A_stats (fn_requestReceived).
# This de-clobbers the EXISTING rows ONE TIME. Gated on FREEZE=0 (runs ONLY on a deploy restart that actually
# packed the split code, so the old code can't re-clobber afterward) + a done-marker so it never repeats. The
# server is OFFLINE at this point (old pkill'd L15, new not launched until below) -> no live session can clobber
# the write. Backs the touched rows up to an in-DB table first; the UPDATE is naturally idempotent (the >17
# filter no-ops once de-clobbered). Same "marker-on-success, launch continues regardless" pattern as the
# boot-time comp/tax tasks above.
STATS_MARK="$PROJ/deploy/.stats_declobber_462_done"
if [ "$FREEZE" = "0" ] && [ ! -f "$STATS_MARK" ]; then
  echo "[boot] #462 stats de-clobber: starting one-time migration (server offline)..."
  if docker exec -i looneybin-db mariadb -ulooneybin -plooneybin looneybin <<'SQL'
ALTER TABLE players_global ADD COLUMN IF NOT EXISTS lifetime_stats TEXT;
CREATE TABLE IF NOT EXISTS _backup_stats_declobber_462 AS
  SELECT playerid, stats AS old_stats, NOW() AS backed_up FROM players_global
  WHERE stats IS NOT NULL AND stats <> '' AND stats <> '[]'
    AND (LENGTH(stats) - LENGTH(REPLACE(stats, ',', '')) + 1) > 17;
UPDATE players_global SET lifetime_stats = stats, stats = NULL
  WHERE stats IS NOT NULL AND stats <> '' AND stats <> '[]'
    AND (LENGTH(stats) - LENGTH(REPLACE(stats, ',', '')) + 1) > 17;
SQL
  then
    touch "$STATS_MARK"
    echo "[boot] #462 stats de-clobber: DONE (backup table _backup_stats_declobber_462; marker set -> never re-runs)"
  else
    echo "[boot] #462 stats de-clobber: FAILED -- no marker written, retries next deploy restart; server launch continues"
  fi
fi

# ---- ONE-TIME TALENT FORCE-GRANT WIPE (owner 2026-06-24, b0097) ---------------------------------------------
# The 2026-06-11 change disabled the standard Talents menu + force-granted EVERY faction talent on each login, so the
# civ/cop/med _talents columns are polluted with the full ID lists. b0097 reverts that (Talents phone button restored,
# force-grant + beta talent-grant removed). Max points is now the per-side CAP (civ 20 / cop 20+ / med 16), so a polluted
# column (~70 IDs) would read OVER-cap in the menu. Wipe the three columns to NULL ONE TIME so every player re-picks their
# own build with full points + free respec (AP_respec_fee=0). Gated FREEZE=0 (runs only on a deploy restart that packed
# the force-grant REMOVAL -> old code can't re-pollute) + marker. Server OFFLINE here (old pkill'd, new not launched) -> no
# live session clobbers it. Backs the rows up first. FAIL -> no marker, retries next deploy restart, launch continues.
TALENT_WIPE_MARK="$PROJ/deploy/.talent_wipe_b0097_done"
if [ "$FREEZE" = "0" ] && [ ! -f "$TALENT_WIPE_MARK" ]; then
  echo "[boot] talent force-grant wipe (b0097): clearing polluted *_talents (server offline)..."
  if docker exec -i looneybin-db mariadb -ulooneybin -plooneybin looneybin <<'SQL'
CREATE TABLE IF NOT EXISTS _backup_talent_wipe_b0097 AS
  SELECT playerid, civ_talents AS old_civ, cop_talents AS old_cop, med_talents AS old_med, NOW() AS backed_up FROM players
  WHERE civ_talents IS NOT NULL OR cop_talents IS NOT NULL OR med_talents IS NOT NULL;
UPDATE players SET civ_talents = NULL, cop_talents = NULL, med_talents = NULL
  WHERE civ_talents IS NOT NULL OR cop_talents IS NOT NULL OR med_talents IS NOT NULL;
SQL
  then
    touch "$TALENT_WIPE_MARK"
    echo "[boot] talent wipe: DONE (backup table _backup_talent_wipe_b0097; marker set -> never re-runs)"
  else
    echo "[boot] talent wipe: FAILED -- no marker written, retries next deploy restart; server launch continues"
  fi
fi

# ---- ONE-TIME MULTI-RIG LEGACY COPY-IN (owner 2026-07-22, defused+gated 2026-07-23) -------------------------
# Copies legacy single-slot houses.rig placements into per-rig house_rigs rows (stamps reset to NOW: legacy
# miner strings were corrupt; no accrual windfall), then NULLs houses.rig/miner so the legacy reload path never
# double-spawns. DESTRUCTIVE for the old code path -> gated FREEZE=0 (runs ONLY on the deploy restart that
# actually packs the multi-rig code) + done-marker. Server OFFLINE here (old pkill'd, new not launched) -> no
# live session mid-write. INSERT is guarded while-empty so a marker loss can't double-copy; the UPDATE no-ops
# once cleared. FAIL -> no marker, retries next deploy restart, launch continues (same pattern as blocks above).
RIGS_MARK="$PROJ/deploy/.rigs_multirig_copyin_done"
if [ "$FREEZE" = "0" ] && [ ! -f "$RIGS_MARK" ]; then
  echo "[boot] multi-rig copy-in: migrating legacy houses.rig placements (server offline)..."
  if docker exec -i looneybin-db mariadb -u"${DB_USER:-looneybin}" -p"${DB_PASS:-looneybin}" "${DB_NAME:-looneybin}" <<'SQL'
CREATE TABLE IF NOT EXISTS _backup_rigs_multirig AS
  SELECT id AS house_id, oid, owners, rig, miner, NOW() AS backed_up FROM houses
  WHERE rig IS NOT NULL AND rig <> '';
INSERT INTO house_rigs (oid, owner, pos, since, last_collect)
  SELECT oid, COALESCE(owners,''), rig, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
  FROM houses WHERE rig IS NOT NULL AND rig <> ''
  AND NOT EXISTS (SELECT 1 FROM house_rigs LIMIT 1);
UPDATE houses SET rig=NULL, miner=NULL WHERE rig IS NOT NULL;
SQL
  then
    touch "$RIGS_MARK"
    echo "[boot] multi-rig copy-in: DONE (backup table _backup_rigs_multirig; marker set -> never re-runs)"
  else
    echo "[boot] multi-rig copy-in: FAILED -- no marker written, retries next deploy restart; server launch continues"
  fi
fi

# ---- ONE-TIME HOUSE-STORAGE RESTORE (owner 2026-06-24, b0094) ----------------------------------------------
# Two bugs damaged house storage: (b0092) the CfgWeights pinv sanitize STRIPPED gear classes absent from the mission
# weight table (vests/helmets/optics/mags/launchers/bipods/suppressors); (b0093) the hydrate/dehydrate refactor made
# houses open EMPTY on the 2nd+ access (dehydrate set the client var to [[],0], the isNil hydrate trigger never
# re-fired) and a close then saved [[],0] over the whole column = full vinv/pinv WIPE. b0094 fixes both (fn_openInventory
# always re-hydrates; updateHouseTrunk refuses an empty payload from an unhydrated session). This re-applies the lost
# gear/contents from the -HOUSEINV- open-logs. Runs HERE -- server OFFLINE (old pkill'd L15 = SIGTERM fires NO graceful
# disconnect-save, so nothing can undo it), DB up, BEFORE launch -- so the new boot's fn_receiveHouses loads the restored
# rows straight into server-local memory. Idempotent (recomputes from current DB + logs; re-adds only what's still
# missing). One-shot marker. On success, DROP the live `houses_no_wipe` trigger (the stop-gap that blocked content->empty
# writes pre-b0094): b0094's in-code guard replaces it, and keeping it would block legit full-empties now that houses
# load correctly again. FAIL -> no marker, trigger LEFT in place (still protected), retries next deploy restart.
HOUSE_RESTORE_MARK="$PROJ/deploy/.house_restore_b0094_done"
if [ "$FREEZE" = "0" ] && [ ! -f "$HOUSE_RESTORE_MARK" ]; then
  echo "[boot] house-storage restore (b0092 strip + b0093 wipe): applying (server offline)..."
  if "$PROJ/loonybot/venv/bin/python" "$PROJ/deploy/restore_houses_b0094.py" --apply >> "$PROJ/deploy/house_restore.log" 2>&1; then
    touch "$HOUSE_RESTORE_MARK"
    docker exec -i looneybin-db mariadb -ulooneybin -plooneybin looneybin -e "DROP TRIGGER IF EXISTS houses_no_wipe;" 2>/dev/null || true
    echo "[boot] house-storage restore: DONE (log: deploy/house_restore.log; live anti-wipe trigger dropped -> b0094 in-code guard takes over)"
  else
    echo "[boot] house-storage restore: FAILED -- no marker, retries next deploy restart; anti-wipe trigger LEFT IN PLACE; launch continues"
  fi
fi

# 4) launch dedicated server. serverMod = extDB3 + AP_server (both relative to cwd).
#    Mission auto-runs (-autoInit), so the first human client to connect is a JIP join
#    (this is what crashes under mode=1).
mkdir -p "$PROFILES"
cd "$A3SRV"
# CRITICAL: extDB3_x64.so dlopens libtbbmalloc.so.2 which lives in the server root but is NOT
# on the default loader path -> "Call extension 'extDB3' could not be loaded". Add root to
# LD_LIBRARY_PATH so the dependency resolves.
export LD_LIBRARY_PATH="$A3SRV:${LD_LIBRARY_PATH:-}"
# owner 2026-06-13: auto-(re)launch the restart_watchdog if it isn't already running. It polls
# server_control.restart_now and relaunches the PROCESS (pkill + this script) for the 4h auto-restart and
# loonybot's hard path. pgrep guard = only ever ONE; setsid detaches it so it survives this script ending
# AND the sandbox reaper. It is NOT killed by the arma pkill, so it persists across every restart.
if ! pgrep -f "restart_watchdog.sh" >/dev/null 2>&1; then
    setsid bash "$PROJ/deploy/restart_watchdog.sh" > /tmp/lb_watchdog.log 2>&1 < /dev/null &
    echo "[boot] launched restart_watchdog (4h auto-restart driver)"
else
    echo "[boot] restart_watchdog already running"
fi
# owner 2026-06-15: auto-(re)launch the DDoS watcher (detect + Discord-alert only, no mitigation). Same
# setsid+pgrep-guard pattern as the restart_watchdog so it survives this script ending + the arma pkill +
# the sandbox reaper, and only ever runs ONE copy. Samples inbound pps/Mbit/conntrack/udp-drops on the WAN
# NICs and pings the status channel on a sustained flood signature.
if ! pgrep -f "ddos_watch.sh" >/dev/null 2>&1; then
    setsid bash "$PROJ/deploy/ddos_watch.sh" > /tmp/lb_ddoswatch.log 2>&1 < /dev/null &
    echo "[boot] launched ddos_watch (DDoS detector)"
else
    echo "[boot] ddos_watch already running"
fi
# owner 2026-07-03: auto-(re)launch the server-control agent — the website Server page bridge. Polls
# server_control and actuates: lock via BE RCON (#lock/#unlock) + warned, graceful-saved restarts handed
# to the restart_watchdog. stdlib-only (no venv). Same setsid+pgrep-guard so it survives this script + the
# arma pkill + the reaper, and only ever runs ONE copy.
if ! pgrep -f "server_control_agent.py" >/dev/null 2>&1; then
    setsid python3 "$PROJ/deploy/server_control_agent.py" > /tmp/lb_svrctl.log 2>&1 < /dev/null &
    echo "[boot] launched server_control_agent (website server-control bridge)"
else
    echo "[boot] server_control_agent already running"
fi
# owner 2026-06-25: auto-(re)launch the LAG-SWITCH watcher (Layer 2: BE-RCON `players` ping-watch -> CLANKR-channel
# REVIEW alerts, never kicks/bans). Gated on config.json lagwatch.enabled=true (off by default). stdlib-only but run
# on the loonybot venv for parity. Same setsid+pgrep-guard so it survives this script + the arma pkill + the reaper.
if python3 -c "import json,sys; sys.exit(0 if (json.load(open('$PROJ/loonybot/config.json')).get('lagwatch') or {}).get('enabled') else 1)" 2>/dev/null; then
    if ! pgrep -f "lagwatch.py" >/dev/null 2>&1; then
        setsid bash -c "cd '$PROJ/loonybot' && venv/bin/python lagwatch.py" > /tmp/lagwatch.log 2>&1 < /dev/null &
        echo "[boot] launched lagwatch (lag-switch detector)"
    else
        echo "[boot] lagwatch already running"
    fi
else
    echo "[boot] lagwatch disabled (config lagwatch.enabled=false) -- skipping"
fi
# owner 2026-06-15: CLANKR (dupe/exploit detector) is a HARD PREREQUISITE -- the server does NOT launch without
# it. The DB is up by here, so start CLANKR on the loonybot venv (if not already running), give it a moment,
# then VERIFY it's alive -- if it isn't, ABORT the boot (exit) and DON'T start the server. setsid so it
# survives this script + the arma pkill + the sandbox reaper; pgrep guard = only ever one copy.
if ! pgrep -f "clankr.py" >/dev/null 2>&1; then
    setsid bash -c "cd '$PROJ/loonybot' && venv/bin/python clankr.py" > /tmp/clankr.log 2>&1 < /dev/null &
    echo "[boot] launching CLANKR (anti-exploit -- hard prerequisite)"
    sleep 4
else
    echo "[boot] CLANKR already running"
fi
if ! pgrep -f "clankr.py" >/dev/null 2>&1; then
    echo "[boot] FATAL: CLANKR is not running and could not be started -> REFUSING to launch the server (CLANKR is a hard prerequisite). Check /tmp/clankr.log"
    exit 1
fi
echo "[boot] CLANKR running -> hard prerequisite satisfied"
# owner 2026-06-20: ENRIQUE gardener bot (DB-only offline weed harvest/replant; separate Discord token). Independent
# of the game server but auto-launched here so it survives restarts like the others. Skips unless its config has a
# real token. setsid+pgrep-guard (narrow `python -u enrique.py` match so it can't self-match a wrapper shell).
if grep -qE '"token"[[:space:]]*:[[:space:]]*"[^"]+"' "$PROJ/loonybot/enrique.config.json" 2>/dev/null; then
    if ! pgrep -f "python -u enrique.py" >/dev/null 2>&1; then
        setsid bash -c "cd '$PROJ/loonybot' && exec venv/bin/python -u enrique.py" > /tmp/enrique.log 2>&1 < /dev/null &
        echo "[boot] launched enrique gardener bot"
    fi
fi
# owner 2026-06-30: LaToya IRS tax bot (separate Discord token). Was NOT in any autolaunch (not OpenRC, not here)
# so she died on the host reboot and went silent. Same setsid+pgrep-guard as the others so she survives restarts.
# Broad `latoya.py` guard (nothing else carries that in its cmdline) so a -u/no-u mismatch can't double-launch her.
if grep -qE '"token"[[:space:]]*:[[:space:]]*"[^"]+"' "$PROJ/loonybot/latoya.config.json" 2>/dev/null; then
    if ! pgrep -f "latoya.py" >/dev/null 2>&1; then
        setsid bash -c "cd '$PROJ/loonybot' && exec venv/bin/python -u latoya.py" > /tmp/latoya.log 2>&1 < /dev/null &
        echo "[boot] launched LaToya IRS bot"
    fi
fi
# NOTE: BOTH extDB3 and AP_server load as serverMod (server-only). AP_server's $PBOPREFIX$ is
# `AP_server`, so the mission's execVM "\AP_server\init.sqf" resolves server-side -- verified.
# It MUST be serverMod (not -mod): under verifySignatures=2 a -mod is advertised to clients, who then
# fail "file '@AP_server\addons\AP_server.pbo' not found" on connect (they never download it).
# (The old "init.sqf not found" with serverMod predated the $PBOPREFIX$ file -- no longer an issue.)
# -bepath: REQUIRED for RCON to bind on Linux. Without it the x64 BE server self-relocates its
# beserver_x64.so into battleye/launch/ and runs from there, and the RCON config (beserver_x64.cfg
# RConPassword/RConPort) is never read -> BE inits + connects to master (filters load) but NO RCON
# socket ever binds (BattleMetrics can't connect). -bepath pins the BE working dir to battleye/ so
# beserver_x64.cfg is read directly. RELATIVE path (cwd=$A3SRV) on purpose: the absolute path has a
# space ("Arma 3 Server") that BE's own arg parser mishandles.
./arma3server_x64 \
  -config=server.cfg -cfg=basic.cfg \
  -profiles="$PROFILES" -name=looneybin \
  -bepath=battleye \
  -serverMod="@extDB3;@AP_server" \
  -filePatching -autoInit \
  2>&1 | tee "$PROFILES/console.log"
