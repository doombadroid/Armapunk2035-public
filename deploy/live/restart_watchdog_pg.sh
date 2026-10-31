#!/usr/bin/env bash
# Live restart driver (owner 2026-09-07): SOFT restart (mission back to the lobby) every 4 h, HARD restart
# (kill + relaunch the arma process) every 12 h.
#
# The MISSION owns the clock and the warnings: server/AP_server/init.sqf runs a serverCycleLength (=4 h)
# countdown with admin boxes at 1h/30m/.../1m, the T-5 feature lock and the graceful save, then writes
# server_control.restart_now=1. THIS script decides what that means:
#   hard_pending=1                      -> HARD (an explicit "restart the process" request, e.g. a deploy)
#   arma process uptime >= HARD_AFTER_S -> HARD (11 h: the third 4-h cycle lands at ~12 h)
#   otherwise                           -> SOFT: BE RCON '#restart' (admin-level; the in-script serverCommand
#                                          is a no-op on a dedi), then bounce the HC unit -- a headless client
#                                          survives '#restart' but sits in the lobby and never re-slots.
# A soft restart that shows no 'Game started' within SOFT_TIMEOUT_S falls back to HARD. Every restart lands
# one restart_log row with its real mode ('soft' | 'hard'). Repacks never happen here -- deploy/push-96.sh
# is the only deploy path.
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u)
HARD_AFTER_S=${HARD_AFTER_S:-39600}      # 11 h
SOFT_TIMEOUT_S=${SOFT_TIMEOUT_S:-120}
SOFT_MIN_UPTIME_S=${SOFT_MIN_UPTIME_S:-180}   # a #restart during init wedged the mission cycle (2026-09-07 21:55, 61 s uptime): hard instead
RCON=/home/timb/Armapunk2035/deploy/live/be_rcon.py
Q() { docker exec armapunk-pg psql -U armapunk -d armapunk -tAc "$1" </dev/null 2>/dev/null; }
log() { echo "restart_watchdog_pg: $(date '+%F %T') $*"; }
arma_pid() { pgrep -f '[a]rma3server_x64 -config=server.cfg' | head -1; }
game_started_since() { journalctl --user -u armapunk-arma -o cat --no-pager --since "$1" 2>/dev/null | grep -aq 'Game started'; }

do_hard() {
  local since; since=$(date '+%F %T')
  log "HARD restart (reason: $1)"
  systemctl --user restart armapunk-arma
  for _ in $(seq 1 40); do sleep 5; game_started_since "$since" && break; done
  game_started_since "$since" && log "HARD: Game started" || log "HARD: no 'Game started' after 200 s -- check journalctl --user -u armapunk-arma"
  systemctl --user start armapunk-hc      # Wants= in the arma unit does this too; explicit is cheap
  Q "insert into restart_log(ts, mode) values (now(), 'hard')" >/dev/null
}

do_soft() {
  local since; since=$(date '+%F %T')
  log "SOFT restart (#restart via RCON; uptime $2 s)"
  # The HC comes OUT first: after '#restart' the engine sits in 'Waiting for next game.' until every
  # connected client is role-assigned, and a headless client thrown back to the lobby never re-slots
  # on its own (2026-09-07 22:01: hung until the 120 s fallback). No HC in the lobby -> the dedi
  # auto-assigns and starts in ~6 s; the HC is started again once the mission is up.
  systemctl --user stop armapunk-hc; sleep 8
  if ! python3 "$RCON" '#restart' >/dev/null 2>&1; then log "SOFT: RCON failed"; do_hard "rcon failed"; return; fi
  local n=$(( SOFT_TIMEOUT_S / 5 ))
  for _ in $(seq 1 $n); do sleep 5; game_started_since "$since" && break; done
  if game_started_since "$since"; then
    log "SOFT: Game started -- starting the HC"
    systemctl --user start armapunk-hc
    Q "insert into restart_log(ts, mode) values (now(), 'soft')" >/dev/null
  else
    log "SOFT: no 'Game started' within ${SOFT_TIMEOUT_S} s"; do_hard "soft restart did not come back"
  fi
}

log "polling server_control every 15 s (soft <${HARD_AFTER_S}s uptime, hard beyond; hard_pending=1 forces hard)"
while true; do
  row=$(Q "select restart_now||' '||hard_pending from server_control where id=1")
  if [ "${row%% *}" = "1" ]; then
    Q "update server_control set restart_now=0, hard_pending=0 where id=1" >/dev/null
    pid=$(arma_pid); up=$(ps -o etimes= -p "${pid:-0}" 2>/dev/null | tr -d ' '); up=${up:-0}
    if [ "${row##* }" = "1" ]; then do_hard "hard_pending=1"
    elif [ "$up" -ge "$HARD_AFTER_S" ]; then do_hard "uptime ${up}s >= ${HARD_AFTER_S}s"
    elif [ "$up" -lt "$SOFT_MIN_UPTIME_S" ]; then do_hard "uptime ${up}s < ${SOFT_MIN_UPTIME_S}s (too fresh for a soft restart)"
    else do_soft "scheduled" "$up"; fi
    sleep 60
  fi
  sleep 15
done
