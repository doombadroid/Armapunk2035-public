#!/usr/bin/env python3
"""Server-control agent — the game-box bridge for the website Server page.

The website (Server Control page) only WRITES intents into the `server_control` row of
the game DB. This agent runs on the game box, polls that row, and actuates:

  * svrlock 0/1            -> BE RCON  #unlock / #lock   (block/allow NEW joins; players
                             already connected stay in). Desired state re-synced on start.
  * web_cmd soft|hard|update (+ web_cmd_secs warning) ->
        - warn players via RCON `say` countdown
        - graceful-save (queue bot_commands 'gracefulsave' -> mission saves vehicles/
          trunks/players/storage, then a ~35s extDB3 flush)
        - hand off to the restart_watchdog via server_control.restart_now
          (hard_pending=1 for 'update' => watchdog repacks+deploys the staged PBO;
           hard_pending=0 for soft/hard => relaunch the deployed build as-is)

Idle daemon: only acts on FRESH ('queued') commands (older than 15 min are treated as
stale and cleared, so a restart of THIS agent never fires an old command). A queued
restart can be cancelled from the website mid-countdown. Launched detached by
run-boot2.sh (setsid), same pattern as restart_watchdog / ddos_watch. Safe to (re)start
anytime — it does not touch the arma process directly (the watchdog does the restart).
"""
import socket, zlib, time, os, json, subprocess, re

# repo root = this file's parent's parent (works in the live tree AND a git worktree)
PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTBOX = os.path.join(PROJ, "loonybot", "outbox")
STATUS_CHAN = 100000000000000047   # status/admin Discord channel (via loonybot outbox)
HOST = "127.0.0.1"
LOCK_STATE = "/tmp/lb_svrlock_applied"   # last lock state we pushed to the server
POLL = 5            # seconds between polls
STALE_SECS = 900    # ignore/clear a queued command older than this (15 min)
SAVE_WAIT = 75      # seconds to let the graceful-save + extDB3 flush commit before restart

def log(m): print(f"[svrctl] {m}", flush=True)

# ---- BE RCON (fresh login per command; first command after login MUST be seq 0) --------
def read_creds():
    pw, port = None, 2310
    for p in ["deploy/battleye/beserver_x64.cfg", "deploy/battleye/beserver.cfg",
              "beserver_x64.cfg", "beserver.cfg"]:
        fp = os.path.join(PROJ, p)
        if os.path.exists(fp):
            txt = open(fp, errors="ignore").read()
            m = re.search(r'RConPassword\s+(\S+)', txt)
            if m: pw = m.group(1)
            m = re.search(r'RConPort\s+(\d+)', txt)
            if m: port = int(m.group(1))
            if pw: return pw, port
    return pw, port

PW, PORT = read_creds()

def _wrap(payload):
    crc = zlib.crc32(payload) & 0xFFFFFFFF
    return b"BE" + crc.to_bytes(4, "little") + payload

def rcon(cmd):
    """Send one server command over BE RCON. Best-effort; returns True on send."""
    if not PW:
        log("no RCON password; skipping " + cmd); return False
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(5); s.connect((HOST, PORT))
        s.send(_wrap(b"\xff\x00" + PW.encode()))
        r = s.recv(1024)
        if len(r) < 9 or r[6] != 0xFF or r[7] != 0x00 or r[8] != 0x01:
            log("RCON login failed"); s.close(); return False
        s.send(_wrap(b"\xff\x01" + bytes([0]) + cmd.encode()))
        try: s.recv(1024)
        except Exception: pass
        s.close(); log("rcon: " + cmd); return True
    except Exception as e:
        log(f"RCON error ({cmd}): {e}"); return False

def say(msg): return rcon("say -1 " + msg)

# ---- DB (local docker mariadb, same container arma/extDB3 uses) -------------------------
def _sql(sql, read=False):
    args = ["docker", "exec", "-i", "looneybin-db", "mariadb", "-ulooneybin", "-plooneybin", "looneybin"]
    if read: args.append("-N")
    args += ["-e", sql]
    try:
        out = subprocess.run(args, capture_output=True, text=True, timeout=20)
        return out.stdout.strip()
    except Exception as e:
        log(f"DB error: {e}"); return None

def db_exec(sql): _sql(sql, read=False)
def _esc(v): return str(v).replace("\\", "\\\\").replace("'", "''")

def read_row():
    out = _sql(
        "SELECT svrlock, COALESCE(web_cmd,''), COALESCE(web_cmd_secs,0), COALESCE(web_cmd_by,''), "
        "COALESCE(web_cmd_status,''), COALESCE(TIMESTAMPDIFF(SECOND, web_cmd_at, NOW()), 999999) "
        "FROM server_control WHERE id=1", read=True)
    if not out:
        return None
    parts = out.split("\t")
    if len(parts) < 6:
        return None
    return {"svrlock": int(parts[0] or 0), "cmd": parts[1], "secs": int(parts[2] or 0),
            "by": parts[3], "status": parts[4], "age": int(parts[5] or 999999)}

def set_status(st): db_exec(f"UPDATE server_control SET web_cmd_status='{_esc(st)}' WHERE id=1")

def discord(msg):
    try:
        os.makedirs(OUTBOX, exist_ok=True)
        open(os.path.join(OUTBOX, f"svrctl_{int(time.time()*1000)}.json"), "w").write(
            json.dumps({"channel_id": STATUS_CHAN, "content": msg}))
    except Exception as e:
        log(f"discord error: {e}")

# ---- lock ------------------------------------------------------------------------------
def applied_lock():
    try: return open(LOCK_STATE).read().strip()
    except Exception: return None

def arma_bootid():
    """Identity of the current arma server process (pid:starttime) — changes on every
    (re)start. A #lock is reset by an arma restart, so we key the cached lock state to
    this: a new boot forces the desired lock to be re-issued instead of skipped."""
    try:
        for p in os.listdir("/proc"):
            if not p.isdigit():
                continue
            try:
                if open(f"/proc/{p}/comm").read().strip() != "arma3server_x64":
                    continue
                st = open(f"/proc/{p}/stat").read().rsplit(")", 1)[1].split()
                return f"{p}:{st[19]}"   # field 22 (starttime), 0-based index 19 after the comm
            except Exception:
                continue
    except Exception:
        pass
    return None

def apply_lock(desired):
    boot = arma_bootid()
    if not boot:            # server not up -> nothing to lock/unlock (retry next poll)
        return
    tag = ("1" if desired else "0") + ":" + boot
    if applied_lock() == tag:
        return
    ok = rcon("#lock" if desired else "#unlock")
    if ok:
        try: open(LOCK_STATE, "w").write(tag)
        except Exception: pass
        log(f"server {'LOCKED' if desired else 'UNLOCKED'} via RCON (boot {boot})")

# ---- restart ---------------------------------------------------------------------------
def cancelled():
    # Only a SUCCESSFULLY-read row can signal a cancel. A transient DB read failure
    # must NOT be misread as a cancellation (that would falsely abort a real restart).
    for _ in range(3):
        r = read_row()
        if r is not None:
            return r["cmd"] == "" or r["status"] == "cancelled"
        time.sleep(1)
    log("cancelled(): DB unreadable after retries — assuming still queued")
    return False

def countdown(secs, mode_label):
    """Warn players down to T-0. Abort early if the command is cancelled from the site."""
    marks = [m for m in (300, 60, 10) if m < secs]
    end = time.time() + secs
    if secs > 0:
        say(f"LooneyBin: {mode_label} in {secs//60} min {secs%60}s. Secure gear & land aircraft. Progress IS saved.")
    for m in marks:
        while time.time() < end - m:
            if cancelled(): return False
            time.sleep(min(POLL, max(0.5, end - m - time.time())))
        if cancelled(): return False
        say(f"LooneyBin: {mode_label} in {m} seconds." if m < 60 else f"LooneyBin: {mode_label} in {m//60} minute(s).")
    while time.time() < end:
        if cancelled(): return False
        time.sleep(min(POLL, max(0.5, end - time.time())))
    return not cancelled()

def do_restart(mode, secs, by):
    label = {"update": "server restart + UPDATE", "soft": "server restart", "hard": "server restart"}[mode]
    log(f"restart requested: mode={mode} secs={secs} by={by}")
    discord(f":warning: **{label}** queued from the website by **{by or 'staff'}** — {secs}s warning.")
    set_status("warning")
    if not countdown(secs, label):
        log("restart cancelled during countdown")
        say("LooneyBin: server restart CANCELLED.")
        discord(":x: Restart cancelled.")
        db_exec("UPDATE server_control SET web_cmd=NULL, web_cmd_status='cancelled' WHERE id=1")
        return
    # graceful save (mission saves vehicles/trunks/players/storage) then flush
    set_status("saving")
    say("LooneyBin: saving server state now…")
    db_exec(f"INSERT INTO bot_commands (command, target, arg1, arg2, issued_by) "
            f"VALUES ('gracefulsave', NULL, NULL, NULL, '{_esc('web:'+(by or 'staff'))}')")
    log(f"graceful-save queued; waiting {SAVE_WAIT}s for flush")
    time.sleep(SAVE_WAIT)
    if cancelled():   # cancelled during the save window — bail before the irreversible restart
        log("cancelled during save window; aborting restart")
        discord(":x: Restart cancelled before reboot."); return
    # hand off to the restart_watchdog: hard_pending=1 => repack+deploy (update); 0 => reload as-is
    hp = 1 if mode == "update" else 0
    say("LooneyBin: restarting NOW. Back in a couple minutes!")
    discord(f":tools: Restarting now ({'UPDATE/repack' if hp else 'reload'}). Back shortly!")
    db_exec(f"UPDATE server_control SET restart_now=1, hard_pending={hp}, web_cmd_status='restarting' WHERE id=1")
    log(f"restart_now=1, hard_pending={hp} set -> watchdog will restart")
    time.sleep(15)
    db_exec("UPDATE server_control SET web_cmd=NULL, web_cmd_status='done' WHERE id=1")

def main():
    log(f"starting (PROJ={PROJ}, RCON {'ok' if PW else 'MISSING'} :{PORT})")
    # Any in-flight command present at startup is ORPHANED (we are NOT resuming a do_restart):
    # clear warning/saving/restarting unconditionally, and queued only if stale. An interrupted
    # countdown/save must never silently auto-resume into an unwatched production restart, and the
    # queue must not stay blocked until the row ages out.
    r0 = read_row()
    if r0 and r0["cmd"]:
        st = r0["status"]
        if st in ("warning", "saving", "restarting") or (st == "queued" and r0["age"] > STALE_SECS):
            log(f"clearing orphaned/stale '{st}' command at startup (age {r0['age']}s)")
            db_exec("UPDATE server_control SET web_cmd=NULL, web_cmd_status='cancelled' WHERE id=1")
            if st in ("warning", "saving"):
                discord(":warning: A queued server restart was interrupted (agent restart) and cleared — re-queue it from the website if still needed.")
    while True:
        try:
            r = read_row()
            if r is not None:
                apply_lock(r["svrlock"] == 1)
                if r["cmd"] in ("soft", "hard", "update"):
                    if r["status"] == "queued":
                        if r["age"] > STALE_SECS:
                            log(f"ignoring stale queued command (age {r['age']}s)")
                            db_exec("UPDATE server_control SET web_cmd=NULL, web_cmd_status='' WHERE id=1")
                        else:
                            do_restart(r["cmd"], r["secs"], r["by"])
                    elif r["status"] in ("warning", "saving"):
                        # Reaching the loop top with an in-flight status means the do_restart that
                        # owned it died (agent bounce) — do_restart otherwise blocks the loop. Reap it
                        # so the queue unblocks and no unwatched restart lingers.
                        log(f"reaping orphaned '{r['status']}' command")
                        db_exec("UPDATE server_control SET web_cmd=NULL, web_cmd_status='cancelled' WHERE id=1")
        except Exception as e:
            log(f"loop error: {e}")
        time.sleep(POLL)

if __name__ == "__main__":
    main()
