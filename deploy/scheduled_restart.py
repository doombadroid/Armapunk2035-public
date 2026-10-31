#!/usr/bin/env python3
"""One-shot scheduled restart (owner 2026-06-26): warn players in-game via BE RCON, then at the
target time set server_control.restart_now=1, hard_pending=1 so the restart_watchdog runs an UPDATE
restart (FORCE_DEPLOY -> repack + deploy the armed b0101). Launch detached so it survives the session:
    setsid python3 deploy/scheduled_restart.py 13:30 b0101 > /tmp/lb_sched_restart.log 2>&1 < /dev/null &
"""
import socket, zlib, time, sys, os, glob, json, subprocess, datetime, re

PROJ = os.path.expanduser("~/Documents/LooneyBin Altis Life")
OUTBOX = os.path.join(PROJ, "loonybot", "outbox")
STATUS_CHAN = 100000000000000047  # status/admin channel
HOST = "127.0.0.1"

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

def rcon_say(msg):
    """Fresh login each call (seq 0), broadcast `say -1`, close. Best-effort."""
    if not PW:
        print("[sched] no RCON password; skipping in-game warn"); return False
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(5); s.connect((HOST, PORT))
        s.send(_wrap(b"\xff\x00" + PW.encode()))
        r = s.recv(1024)
        if len(r) < 9 or r[6] != 0xFF or r[7] != 0x00 or r[8] != 0x01:
            print("[sched] RCON login failed"); s.close(); return False
        # first command after login MUST be seq 0 (this BE tracks an in-order counter)
        s.send(_wrap(b"\xff\x01" + bytes([0]) + ("say -1 " + msg).encode()))
        try: s.recv(1024)
        except Exception: pass
        s.close(); print(f"[sched] said: {msg}"); return True
    except Exception as e:
        print(f"[sched] RCON say error: {e}"); return False

def discord(msg):
    try:
        os.makedirs(OUTBOX, exist_ok=True)
        open(os.path.join(OUTBOX, f"schedrestart_{int(time.time())}.json"), "w").write(
            json.dumps({"channel_id": STATUS_CHAN, "content": msg}))
        print("[sched] discord queued")
    except Exception as e:
        print(f"[sched] discord error: {e}")

def db(sql):
    subprocess.run(["docker", "exec", "-i", "looneybin-db", "mariadb", "-ulooneybin",
                    "-plooneybin", "looneybin", "-e", sql], check=False)

def main():
    hhmm = sys.argv[1] if len(sys.argv) > 1 else "13:30"
    ver  = sys.argv[2] if len(sys.argv) > 2 else "update"
    hh, mm = map(int, hhmm.split(":"))
    now = datetime.datetime.now()
    target = now.replace(hour=hh, minute=mm, second=0, microsecond=0)
    if target <= now:
        target += datetime.timedelta(days=1)
    print(f"[sched] target {target}  (in {(target-now).total_seconds():.0f}s)  ver={ver}")

    discord(f":warning: **Server restart at {hhmm} CST** (~{int((target-now).total_seconds()//60)} min) "
            f"to deploy **{ver}**. Secure your gear & land aircraft.")

    def secs_left(): return (target - datetime.datetime.now()).total_seconds()

    rcon_say(f"LooneyBin: server restart + {ver} UPDATE at {hhmm} CST (~{int(secs_left()//60)} min). Bank gear & land aircraft.")
    def post(mins):
        # countdown post -> in-game (RCON) + Discord status channel
        rcon_say(f"LooneyBin: server restart + {ver} update in {mins} MINUTE{'S' if mins != 1 else ''}. Secure gear & vehicles.")
        discord(f":hourglass_flowing_sand: Server restart + **{ver}** update in **{mins} min** ({hhmm} CST). Secure gear & land aircraft.")
    # post the countdown every 5 minutes, then a 1-minute final
    for mark in [1500, 1200, 900, 600, 300, 60]:
        wait = secs_left() - mark
        if wait > 0:
            time.sleep(wait); post(mark // 60)

    # sleep to T-0
    rem = secs_left()
    if rem > 0:
        time.sleep(rem)
    rcon_say(f"LooneyBin: restarting NOW for {ver}. Back in a few minutes!")
    discord(f":tools: Restarting now for **{ver}**. Back shortly!")
    print(f"[sched] firing restart at {datetime.datetime.now()}")
    db("UPDATE server_control SET restart_now=1, hard_pending=1 WHERE id=1;")
    print("[sched] restart_now=1, hard_pending=1 set -> watchdog will UPDATE-deploy")

if __name__ == "__main__":
    main()
