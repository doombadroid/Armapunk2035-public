#!/usr/bin/env bash
# LooneyBin restart watchdog (owner 2026-06-13). Two jobs:
#
#  1) HARD restarts: the in-game auto-restart scheduler (AP_server init.sqf) sets
#     server_control.restart_now=1 when a cycle is HARD (i.e. the operator staged fixes, so a fresh PBO
#     must be deployed). This watchdog detects it, runs deploy/run-boot2.sh (kills + relaunches the PROCESS
#     so the new mission/AP_server PBOs load), and clears the flag. SOFT restarts are handled entirely
#     in-engine (#restart -> lobby + mission reload) and need NOTHING here.
#
#  2) RESTART WATCH: every restart is logged to restart_log by the scheduler. At the watch_until deadline
#     (server_control.watch_until = 10am tomorrow) this posts the tally to Discord via the bot outbox so the
#     owner is told even if they don't reconnect in-game (the in-game owner-connect box reports it too).
#
# To stage a HARD restart for the NEXT auto-cycle, run:
#     docker exec -i looneybin-db mariadb -ulooneybin -plooneybin looneybin -e \
#       "UPDATE server_control SET hard_pending=1 WHERE id=1;"
#
# Launch from YOUR shell so it survives (sandbox reaps Bash-tool background procs):
#     setsid bash "$HOME/Documents/LooneyBin Altis Life/deploy/restart_watchdog.sh" > /tmp/lb_watchdog.log 2>&1 < /dev/null &
set -u
PROJ="$HOME/Documents/LooneyBin Altis Life"
OUTBOX="$PROJ/loonybot/outbox"
REPORT_CHAN=100000000000000047   # status/admin channel
DB() { docker exec -i looneybin-db mariadb -ulooneybin -plooneybin looneybin -N -e "$1" 2>/dev/null; }

posted_report=0
echo "[watchdog] online $(date '+%F %T')"
# owner 2026-06-14: ignore any restart_now left over from a PREVIOUS session (stale escalation flag / power
# outage) -- we just started, so a 1 sitting here is not OUR signal. Clearing it stops an instant restart.
DB "UPDATE server_control SET restart_now=0 WHERE id=1" >/dev/null 2>&1
while true; do
    # --- 1) restart execution --------------------------------------------------------------------
    now=$(DB "SELECT restart_now FROM server_control WHERE id=1")
    if [ "${now:-0}" = "1" ]; then
        # owner 2026-06-18: hard_pending picks the restart TYPE (the in-game button / 4h auto-restart can't pass
        # an env var, so it's signalled via the DB). 1 = UPDATE (repack + deploy, force past the freeze) ->
        # FORCE_DEPLOY=1. 0 = HARD (relaunch the deployed PBOs as-is, never repack) -> NO_REPACK=1. Read it first,
        # then clear BOTH flags so a stale 1 can't auto-deploy on the next cycle.
        repack=$(DB "SELECT hard_pending FROM server_control WHERE id=1")
        DB "UPDATE server_control SET restart_now=0, hard_pending=0 WHERE id=1"
        cd "$PROJ"
        # Arma 3 2.22+ names the running process `rvMain`, so `pkill -x arma3server_x64` matched NOTHING from
        # 2026-08-12 to 2026-09-02: every hard restart ADDED a server (random port, full mission logic vs the live
        # DB) until the kernel OOM killer culled at random -- including the live one. Kill by CMDLINE ([a]rma =
        # no self-match; `-config=` excludes the -client HC) and VERIFY the exit. Never `|| true` a kill.
        pkill -f '[a]rma3server_x64 -config=server.cfg' 2>/dev/null || true
        for _i in $(seq 1 30); do pgrep -f '[a]rma3server_x64 -config=server.cfg' >/dev/null || break; sleep 1; done
        if pgrep -f '[a]rma3server_x64 -config=server.cfg' >/dev/null; then
            echo "[watchdog] server survived SIGTERM for 30s -> SIGKILL ($(date '+%F %T'))"
            pkill -9 -f '[a]rma3server_x64 -config=server.cfg' 2>/dev/null || true; sleep 2
        fi
        pgrep -f '[a]rma3server_x64 -config=server.cfg' >/dev/null && echo "[watchdog] !! OLD SERVER STILL ALIVE after SIGKILL -- relaunch will not get port 2302"
        : > "$HOME/arma3server/profiles/console.log"
        if [ "${repack:-0}" = "1" ]; then
            echo "[watchdog] restart_now=1, hard_pending=1 -> UPDATE restart (repack + deploy, FORCE_DEPLOY) ($(date '+%F %T'))"
            NO_REPACK=0 FORCE_DEPLOY=1 nohup bash deploy/run-boot2.sh > /tmp/lb_boot.log 2>&1 &
        else
            echo "[watchdog] restart_now=1, hard_pending=0 -> HARD restart (reload deployed PBOs, NO_REPACK) ($(date '+%F %T'))"
            FORCE_DEPLOY=0 NO_REPACK=1 nohup bash deploy/run-boot2.sh > /tmp/lb_boot.log 2>&1 &
        fi
        sleep 60   # give the boot time before resuming polling
    fi

    # --- 2) 10am tally -> Discord (once) ---------------------------------------------------------
    if [ "$posted_report" = "0" ]; then
        past=$(DB "SELECT IF(NOW() >= watch_until, 1, 0) FROM server_control WHERE id=1")
        if [ "${past:-0}" = "1" ]; then
            cnt=$(DB "SELECT COUNT(*) FROM restart_log WHERE ts >= (SELECT watch_start FROM server_control WHERE id=1) AND ts <= (SELECT watch_until FROM server_control WHERE id=1)")
            soft=$(DB "SELECT COUNT(*) FROM restart_log WHERE mode='soft' AND ts >= (SELECT watch_start FROM server_control WHERE id=1) AND ts <= (SELECT watch_until FROM server_control WHERE id=1)")
            hard=$(DB "SELECT COUNT(*) FROM restart_log WHERE mode='hard' AND ts >= (SELECT watch_start FROM server_control WHERE id=1) AND ts <= (SELECT watch_until FROM server_control WHERE id=1)")
            mkdir -p "$OUTBOX"
            python3 - "$REPORT_CHAN" "${cnt:-0}" "${soft:-0}" "${hard:-0}" "$OUTBOX" <<'PY'
import json, sys, time, os
chan, cnt, soft, hard, outbox = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
msg = f"**Restart watch complete (10am).**\n{cnt} server restart(s) since the watch began — {soft} soft, {hard} hard."
open(os.path.join(outbox, f"restartwatch_{int(time.time())}.json"), "w").write(
    json.dumps({"channel_id": int(chan), "content": msg}))
PY
            echo "[watchdog] posted 10am tally: $cnt restarts ($soft soft / $hard hard)"
            posted_report=1
        fi
    fi

    sleep 15
done
