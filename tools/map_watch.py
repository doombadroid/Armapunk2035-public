#!/usr/bin/env python3
"""Watch the edit mission; every 3DEN save is pushed into map_objects by id.

    python3 tools/map_watch.py               # push on every save
    python3 tools/map_watch.py --once        # handle one save, then exit

This is the piece that makes the editor feel wired to the server. SQF cannot write files or run
programs, but it does not need to: 3DEN writes mission.sqm on Ctrl+S, this watches that file, and
each save is diffed against the table BY ID (tools/map_push.py). The running server picks the
rows up on its next poll (<= 10 s) and broadcasts them -- no repack, no restart, nobody
reconnects. There is nothing to deploy any more: the table is the only source of placed objects
(mapdb.md D7), so the old apply -> balance-check -> reload -> wait-for-boot chain is gone.

Any failure is logged loudly and pops a desktop notification when notify-send exists. A save
while a push is running is picked up on the next loop, newest state wins.

LIVE IS NEVER TOUCHED. map_push writes the dev database the tools' DSN points at (~/.pysqf_dsn).
"""
import hashlib
import os
import shutil
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EDIT_DIR = os.environ.get(
    "AP_EDIT_MISSION",
    os.path.expanduser("~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/"
                       "steamuser/Documents/Arma 3/mpmissions/MaldenEdit.Malden"))
SQM = os.path.join(EDIT_DIR, "mission.sqm")
ONCE = "--once" in sys.argv
VENV_PY = os.path.expanduser("~/pysqf-venv/bin/python")   # psycopg lives here, not in system python


def log(msg):
    print("[%s] %s" % (time.strftime("%H:%M:%S"), msg), flush=True)


def notify(msg):
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "Malden map watch", msg],
                       check=False, capture_output=True)


def digest(path):
    try:
        return hashlib.sha256(open(path, "rb").read()).hexdigest()
    except OSError:
        return None


def run(cmd, timeout, env=None):
    return subprocess.run(cmd, cwd=REPO, capture_output=True, text=True, timeout=timeout, env=env)


def handle_push():
    r = run([VENV_PY, "tools/map_push.py"], timeout=300)
    for line in (r.stdout + r.stderr).splitlines():
        log("  " + line)
    if r.returncode != 0:
        log("PUSH FAILED -- nothing written. Fix and save again.")
        notify("map push FAILED -- see the watch terminal")
        return
    log("pushed. the dev server applies it on its next poll (<=10 s); no repack, no reconnect.")
    notify("map edit pushed -- live within 10 s")


def main():
    if not os.path.exists(SQM):
        sys.exit("no edit mission at %s -- run tools/edit-map.sh first" % SQM)
    last = digest(SQM)
    log("watching %s" % SQM)
    log("mode: push to map_objects (no repack)")
    log("save in 3DEN and the rest happens here. Ctrl+C to stop.")
    while True:
        time.sleep(2)
        d = digest(SQM)
        if d is None or d == last:
            continue
        # debounce: 3DEN may still be writing; wait until two reads agree
        while True:
            time.sleep(3)
            d2 = digest(SQM)
            if d2 == d:
                break
            d = d2
        log("save detected")
        handle_push()
        last = digest(SQM)
        log("watching (save again any time)")
        if ONCE:
            return


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
