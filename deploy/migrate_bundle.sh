#!/usr/bin/env bash
# migrate_bundle.sh — package the LooneyBin live stack for migration to new hardware.
# NON-DISRUPTIVE: this only READS the running server + takes a --single-transaction DB dump
# (InnoDB consistent snapshot, NO write lock), so the live server keeps serving throughout.
# It does NOT stop, restart, pkill, or reconfigure anything that is running.
#
# What it captures (everything that is NOT reproducible from `git clone` + steamcmd):
#   - the MariaDB `looneybin` database (the crown jewel — player data)
#   - secrets (bot tokens, RCON password, extDB3 DB creds, the PBO signing private key)
#   - the deploy one-time-migration markers (so they never re-run on the new box)
#   - the extDB3 connector mod (@extDB3 + libtbbmalloc) + steam_appid.txt + server keys
#   - the exact python requirements for the bots
#   - a MANIFEST with the git URLs/branches + restore steps + checksums
# Code (mission + server SQF) and the Arma base install are NOT bundled — they come from
# `git clone` and `steamcmd` on the new box (see provision_cachyos.sh).
#
# Usage:   deploy/migrate_bundle.sh [OUTDIR]
#   OUTDIR defaults to ~/loonybin-migration. Re-run any time for a fresh DB dump; the last
#   run before cutover is the one you transfer. Secrets go in a SEPARATE tarball you should
#   move with care (scp over ssh, delete after import).
set -euo pipefail

PROJ="$HOME/Documents/LooneyBin Altis Life"
A3SRV="$HOME/.local/share/Steam/steamapps/common/Arma 3 Server"
DB_CONTAINER="looneybin-db"
DB_NAME="looneybin"
DB_USER="looneybin"
DB_PASS="${LOONEYBIN_DB_PASS:-looneybin}"

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="${1:-$HOME/loonybin-migration}/bundle_$STAMP"
mkdir -p "$OUT"/{db,secrets,arma,state}
echo "[bundle] -> $OUT"

# --- 1) DB DUMP (non-blocking, consistent) ------------------------------------------------
# --single-transaction: InnoDB snapshot with NO lock (verified: all 49 tables are InnoDB).
# --quick: stream rows (low memory). --routines/--triggers/--events: procs/triggers/events too.
echo "[bundle] dumping $DB_NAME (single-transaction, no write lock)..."
docker exec "$DB_CONTAINER" sh -c \
  "mariadb-dump -u$DB_USER -p'$DB_PASS' --single-transaction --quick --routines --triggers --events $DB_NAME" \
  | gzip -6 > "$OUT/db/${DB_NAME}_${STAMP}.sql.gz"
echo "[bundle]   -> $(du -h "$OUT/db/${DB_NAME}_${STAMP}.sql.gz" | cut -f1)"

# --- 2) SECRETS (gitignored — must travel out-of-band) ------------------------------------
echo "[bundle] copying secrets..."
# bot tokens + runtime state
cp -a "$PROJ/loonybot/config.json"          "$OUT/secrets/" 2>/dev/null || echo "  (no config.json)"
cp -a "$PROJ/loonybot/enrique.config.json"  "$OUT/secrets/" 2>/dev/null || true
cp -a "$PROJ/loonybot/latoya.config.json"   "$OUT/secrets/" 2>/dev/null || true
cp -a "$PROJ/loonybot/clankr_state.json"    "$OUT/secrets/" 2>/dev/null || true
cp -a "$PROJ"/loonybot/*.ranknicks.json     "$OUT/secrets/" 2>/dev/null || true
# extDB3 DB creds (the DEPLOYED copy has the real password injected; repo copy is CHANGE_ME)
cp -a "$A3SRV/@extDB3/extdb3-conf.ini"       "$OUT/secrets/extdb3-conf.ini.deployed" 2>/dev/null || true
# RCON password + BE config (gitignored)
cp -a "$PROJ/deploy/battleye/beserver.cfg"     "$OUT/secrets/" 2>/dev/null || true
cp -a "$PROJ/deploy/battleye/beserver_x64.cfg" "$OUT/secrets/" 2>/dev/null || true
# PBO SIGNING KEYPAIR (the private key CANNOT be regenerated without invalidating client .bikey)
mkdir -p "$OUT/secrets/keys"
cp -a "$PROJ/deploy/keys/"*.biprivatekey "$OUT/secrets/keys/" 2>/dev/null || echo "  (!! no biprivatekey — PBO signing will break)"
cp -a "$PROJ/deploy/keys/"*.bikey        "$OUT/secrets/keys/" 2>/dev/null || true
chmod -R go-rwx "$OUT/secrets"

# --- 3) ARMA custom parts (not from steamcmd; @AP_server/mission are repacked from source)
echo "[bundle] copying the extDB3 connector + steam_appid + server keys..."
cp -a "$A3SRV/@extDB3"        "$OUT/arma/"               2>/dev/null || true   # connector + libtbbmalloc + libs
cp -a "$A3SRV/steam_appid.txt" "$OUT/arma/"              2>/dev/null || true   # 107410 — MUST stay 107410 on this box class
cp -a "$A3SRV/keys"          "$OUT/arma/server_keys"     2>/dev/null || true   # server keys/ (.bikey allowlist)
# libtbbmalloc lives in the server ROOT (extDB3 dlopens it via LD_LIBRARY_PATH=$A3SRV)
cp -a "$A3SRV"/libtbbmalloc.so* "$OUT/arma/"             2>/dev/null || true

# --- 4) DEPLOY STATE MARKERS (so one-time DB migrations DON'T re-run on the new box) -------
echo "[bundle] copying deploy state markers..."
for m in .sativa_comp_done .housetax_reset_done .stats_declobber_462_done \
         .talent_wipe_b0097_done .house_restore_b0094_done .deploy_freeze; do
  [ -e "$PROJ/deploy/$m" ] && cp -a "$PROJ/deploy/$m" "$OUT/state/" 2>/dev/null || true
done
# current build + version
cp -a "$PROJ"/mission/*/*version*.hpp "$OUT/state/" 2>/dev/null || true
grep -rhoE "Loonybin_b[0-9]+" "$PROJ/deploy/run-boot2.sh" 2>/dev/null | head -1 > "$OUT/state/current_build.txt" || true
# most recent DB backup (belt-and-suspenders alongside the fresh dump above)
_lastbk="$(ls -t "$PROJ/deploy/db_backups/"*.sql* 2>/dev/null | head -1 || true)"
[ -n "$_lastbk" ] && cp -a "$_lastbk" "$OUT/db/" 2>/dev/null || true

# --- 5) PYTHON REQUIREMENTS (recreate the bot venv on the new box) ------------------------
echo "[bundle] freezing bot venv requirements..."
"$PROJ/loonybot/venv/bin/pip" freeze > "$OUT/requirements.txt" 2>/dev/null || echo "  (venv freeze failed)"

# --- 6) MANIFEST ---------------------------------------------------------------------------
{
  echo "LooneyBin migration bundle — $STAMP"
  echo "Source box: $(hostname) ($(source /etc/os-release; echo "$PRETTY_NAME") $(uname -r))"
  echo
  echo "== CODE (clone on the new box; NOT in this bundle) =="
  echo "  main repo : git clone https://github.com/doombadroid/LoonyBin.git  (branch: main)"
  echo "              -> \$HOME/Documents/LooneyBin Altis Life"
  echo "  doomba wt : git worktree add ../loonybin-doomba doomba   (or clone -b doomba)"
  echo
  echo "== ARMA BASE (steamcmd on the new box; NOT in this bundle) =="
  echo "  app 233780 (Arma 3 Dedicated Server) -> ~/.local/share/Steam/steamapps/common/Arma 3 Server"
  echo "  steam_appid.txt MUST remain 107410 (233780 crashes this box class — stalled cross-thread pipe)"
  echo "  This bundle carries @extDB3 + libtbbmalloc + server keys (the parts steamcmd does NOT provide)."
  echo
  echo "== DATABASE =="
  echo "  restore: gunzip -c db/${DB_NAME}_${STAMP}.sql.gz | docker exec -i looneybin-db mariadb -ulooneybin -plooneybin looneybin"
  echo "  (provision_cachyos.sh creates a CLEAN NAMED volume 'looneybin-db-data' + restores this — fixes the old hash-volume)"
  echo
  echo "== SECRETS (secrets/ — handle out-of-band, delete after import) =="
  ( cd "$OUT/secrets" && find . -type f | sed 's/^/    /' )
  echo
  echo "== CHECKSUMS =="
  ( cd "$OUT" && find . -type f -exec sha256sum {} \; | sed 's/^/  /' )
} > "$OUT/MANIFEST.txt"

# --- 7) TARBALLS (split: main bundle + secrets separate) ----------------------------------
echo "[bundle] archiving..."
( cd "$(dirname "$OUT")" && tar czf "$(basename "$OUT")_secrets.tar.gz" "$(basename "$OUT")/secrets" )
( cd "$(dirname "$OUT")" && tar czf "$(basename "$OUT")_main.tar.gz" --exclude="$(basename "$OUT")/secrets" "$(basename "$OUT")" )
echo
echo "[bundle] DONE:"
echo "  main    : $(dirname "$OUT")/$(basename "$OUT")_main.tar.gz     ($(du -h "$(dirname "$OUT")/$(basename "$OUT")_main.tar.gz" | cut -f1))"
echo "  secrets : $(dirname "$OUT")/$(basename "$OUT")_secrets.tar.gz  ($(du -h "$(dirname "$OUT")/$(basename "$OUT")_secrets.tar.gz" | cut -f1))  <-- transfer with care, delete after import"
echo "  staged  : $OUT   (+ MANIFEST.txt)"
echo
echo "Next: scp both tarballs to the new box, then run provision_cachyos.sh there."
