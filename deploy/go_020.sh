#!/bin/bash
# LooneyBin 0.2.0 deploy trigger. Run ON .96, from the deploy source root.
#
#   bash deploy/go_020.sh --check        pre-flight only, changes nothing (safe any time)
#   bash deploy/go_020.sh --go 5         pre-flight, bump PBO, warn players 5 min, then deploy
#
# --go is the ONLY mode that touches anything. It bumps the PBO name in both places, then hands
# off to scheduled_restart.py, which warns players over BE RCON + Discord and finally sets
# server_control.restart_now=1 / hard_pending=1. The watchdog picks that up and runs
# FORCE_DEPLOY=1 run-boot2.sh: guard -> repack mission + AP_server -> relaunch -> post notes.
#
# FORCE_DEPLOY deliberately punches through BOTH the nightly window and deploy/.deploy_freeze --
# the freeze file stops accidental/natural deploys, not this deliberate one.
set -uo pipefail
P="$(cd "$(dirname "$0")/.." && pwd)"
A3="$HOME/.local/share/Steam/steamapps/common/Arma 3 Server"
NEW_PBO="0183"
MODE="${1:---check}"
WARN_MIN="${2:-5}"
FAIL=0

say()  { printf '  %-42s %s\n' "$1" "$2"; }
ok()   { say "$1" "OK — $2"; }
bad()  { say "$1" "FAIL — $2"; FAIL=$((FAIL+1)); }

echo "=== LooneyBin 0.2.0 pre-flight ($(date '+%F %T')) ==="

V=$(grep -o 'Beta [0-9.]*' "$P/mission/Armapunk2035.Malden/version.hpp" | head -1)
[ "$V" = "Beta 0.2.0" ] && ok "staged version" "$V" || bad "staged version" "expected Beta 0.2.0, got '$V'"

CUR_CFG=$(grep -o 'Loonybin_b[0-9]*' "$P/deploy/server.cfg" | head -1)
CUR_PK=$(grep -o 'Armapunk2035_b[0-9]*\.Malden\.pbo' "$P/deploy/run-boot2.sh" | head -1)
[ "$CUR_PK" = "${CUR_CFG}.Malden.pbo" ] && ok "PBO names aligned" "$CUR_CFG" \
  || bad "PBO names aligned" "server.cfg=$CUR_CFG pack=$CUR_PK"
[ -f "$A3/mpmissions/${CUR_CFG}.Malden.pbo" ] && ok "current PBO on disk" "${CUR_CFG}.Malden.pbo" \
  || bad "current PBO on disk" "${CUR_CFG}.Malden.pbo missing — a restart NOW would load no mission"

if python3 "$P/deploy/predeploy_guard.py" "$P/mission/Armapunk2035.Malden" \
     "$A3/mpmissions/${CUR_CFG}.Malden.pbo" >/tmp/lb_guard.log 2>&1; then
  ok "predeploy guard" "no critical-file regression"
else
  bad "predeploy guard" "see /tmp/lb_guard.log"
fi

if [ -f "$P/deploy/cfgfn_audit.py" ]; then
  U=$(python3 "$P/deploy/cfgfn_audit.py" "$P" 2>/dev/null | grep -c '^   line ' || true)
  # config.cpp's two CfgMovesFatigue hits are config classes, not functions -> expected
  [ "$U" -le 2 ] && ok "fn registrations resolve" "$U known non-function hits" \
    || bad "fn registrations resolve" "$U unresolved — a registration points at a missing file"
fi

PN="$P/deploy/patchnote_override.txt"
if [ -f "$PN" ]; then
  # Discord's 2000 limit counts UTF-16 units, so an emoji costs 2 -- `wc -c` (bytes) and a naive
  # character count both give the wrong answer. Measure each ---POST--- part the way Discord does.
  PNR=$(python3 - "$PN" "$V" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read().strip()
parts = [p.strip() for p in re.split(r'(?m)^\s*---POST---\s*$', s) if p.strip()]
worst, over = 0, []
for i, p in enumerate(parts, 1):
    u = len(p.replace("{version}", sys.argv[2]).encode("utf-16-le")) // 2
    worst = max(worst, u)
    if u > 2000: over.append("part %d=%d" % (i, u))
print(("OVER " + ",".join(over)) if over else "OK %d part(s), largest %d utf-16 units" % (len(parts), worst))
PY
)
  case "$PNR" in
    OK*)   ok  "patch notes" "${PNR#OK }" ;;
    *)     bad "patch notes" "$PNR — Discord will reject it" ;;
  esac
  grep -qi 'infamous\|@everyone' "$PN" && bad "patch notes content" "contains a forbidden credit/ping" \
    || ok "patch notes content" "no forbidden credit or mass ping"
else
  bad "patch notes" "deploy/patchnote_override.txt missing — BUGS.md entries would post instead"
fi

pgrep -f restart_watchdog >/dev/null && ok "restart watchdog" "alive (required — it runs the deploy)" \
  || bad "restart watchdog" "DEAD — flags would be set and nothing would act on them"

DBQ() { docker exec looneybin-db mariadb -ulooneybin -plooneybin looneybin -N -e "$1" </dev/null 2>/dev/null; }
[ -n "$(DBQ "SHOW COLUMNS FROM players LIKE 'cyberdeck_modules';")" ] \
  && ok "players.cyberdeck_modules" "present (0.2.0 logins need it)" \
  || bad "players.cyberdeck_modules" "MISSING — every login will error"
F=$(DBQ "SELECT CONCAT(restart_now,'/',hard_pending) FROM server_control WHERE id=1;")
[ "$F" = "0/0" ] && ok "server_control flags" "0/0 idle" || bad "server_control flags" "$F — a deploy may already be queued"

[ -f "$P/deploy/.deploy_freeze" ] && say "deploy freeze" "ARMED — blocks natural deploys; --go overrides it deliberately" \
  || say "deploy freeze" "not present"
ls "$P"/deploy/.repack_on_restart "$P"/deploy/.force_deploy_once >/dev/null 2>&1 \
  && bad "one-shot deploy flags" "present — a natural restart would deploy unattended" \
  || ok "one-shot deploy flags" "none"

echo
if [ "$FAIL" -gt 0 ]; then
  echo "=== $FAIL PRE-FLIGHT FAILURE(S) — not safe to deploy ==="; exit 1
fi
echo "=== pre-flight clean ==="

if [ "$MODE" != "--go" ]; then
  echo "check-only. To deploy:  bash deploy/go_020.sh --go ${WARN_MIN}"
  exit 0
fi

echo
echo ">>> DEPLOYING: bumping $CUR_CFG -> Loonybin_b${NEW_PBO}, warning players ${WARN_MIN} min"
bash "$P/deploy/bump_pbo.sh" "$NEW_PBO" || { echo "PBO bump failed — aborting, nothing triggered"; exit 1; }
AT=$(date -d "+${WARN_MIN} minutes" +%H:%M)
setsid python3 "$P/deploy/scheduled_restart.py" "$AT" "Beta 0.2.0 — The Armapunk Update" \
  > /tmp/lb_sched.log 2>&1 < /dev/null &
echo ">>> restart scheduled for $AT (stdout is block-buffered under setsid; check: pgrep -af scheduled_restart)"
cat <<'POST'

AFTER the server is back up on the new PBO:
  grep -E "guard. OK|pack_pbo|gen_patchnotes" /tmp/lb_boot.log
  grep -cE "Undefined base class|Undefined variable in expression: AP_fnc_" .../console.log   # expect 0
  python3 deploy/migrations/migrate_deck_firmware.py       --schema looneybin --apply
  python3 deploy/migrations/strip_removed_deck_talents.py  --schema looneybin --apply
  curl -I <mission download URL>    # HTTP mission download serves the new PBO
POST
