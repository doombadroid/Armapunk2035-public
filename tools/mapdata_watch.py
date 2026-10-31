#!/usr/bin/env python3
"""
mapdata_watch.py -- tail the Arma client RPT and apply 3DEN map exports the moment they happen.

    python3 tools/mapdata_watch.py            # leave it running in a terminal
    python3 tools/mapdata_watch.py --dry-run  # report what it WOULD apply, write nothing
    python3 tools/mapdata_watch.py --once     # apply the next export, then exit
    python3 tools/mapdata_watch.py --backfill # also process the last block already in the log

With this running, the whole flow is: place objects in 3DEN -> Debug Console ->
`call compile preprocessFileLineNumbers "mapExportAll.sqf"` -> the entries are in fn_mapData.sqf.
No clipboard, no wl-paste, no second command.

HOW IT READS THE LOG. mapExportAll already logs the export between ===AP_MAPALL_BEGIN=== and
===AP_MAPALL_END=== as a fallback (50 entries per diag_log call). Arma renders a logged string with
the whole thing in quotes and EVERY inner quote DOUBLED, and any embedded newline continues on an
unprefixed line -- so a record is "prefix + quoted blob", and decoding is: split on the timestamp
prefix, drop the outer quotes, un-double the rest. That round-trips the SQF literals exactly,
including the doubled quotes inside NPC init strings.

Safety is whatever `mapdata_all.apply_export` enforces: the >2% net-deletion abort, the 2000-entry
cap on an add-only export, and a fn_mapData.sqf.bak before every write. A refusal is printed loudly
and the watcher keeps running.
"""
import glob
import hashlib
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mapdata_all as M

RPT_DIR = os.environ.get("AP_RPT_DIR", os.path.expanduser(
    "~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/"
    "AppData/Local/Arma 3"))
BEGIN, END = "===AP_MAPALL_BEGIN===", "===AP_MAPALL_END==="
# client RPT lines are "HH:MM:SS "; the server's are "YYYY/MM/DD, HH:MM:SS "
PREFIX = re.compile(r"^(?:\d{4}/\d{2}/\d{2},\s+)?\d{1,2}:\d{2}:\d{2}\s+")
POLL = 1.0


def newest_rpt():
    files = glob.glob(os.path.join(RPT_DIR, "*.rpt"))
    return max(files, key=os.path.getmtime) if files else None


def decode(lines):
    """RPT records -> the exact text mapExportAll built."""
    records, cur = [], None
    for ln in lines:
        m = PREFIX.match(ln)
        if m:
            if cur is not None:
                records.append(cur)
            cur = ln[m.end():]
        elif cur is not None:
            cur += "\n" + ln
    if cur is not None:
        records.append(cur)
    out = []
    for r in records:
        r = r.rstrip("\r\n")
        if r.startswith('"'):
            r = r[1:]
        if r.endswith('"'):
            r = r[:-1]
        out.append(r.replace('""', '"'))          # un-double: RPT doubles every quote it logs
    return "".join(out)


def count_rows(text):
    """Top-level [ ... ] rows, quote-aware -- same scan apply_export uses."""
    n = depth = 0
    q = False
    for c in text:
        if c == '"':
            q = not q
        elif not q:
            if c == '[':
                depth += 1
            elif c == ']':
                depth -= 1
                if depth == 0:
                    n += 1
    return n


def stamp():
    return time.strftime("%H:%M:%S")


def handle(block, dry_run, seen):
    text = decode(block)
    digest = hashlib.sha1(text.encode("utf-8", "replace")).hexdigest()
    if digest in seen:
        print("%s  (same export again -- already applied, ignoring)" % stamp())
        return False
    seen.add(digest)
    rows = count_rows(text)
    mode = "add-only" if "AP_MAPALL_MODE_APPEND" in text else "full-array"
    print("%s  export seen: %d entries, %s" % (stamp(), rows, mode))
    if rows == 0:
        print("%s  nothing parsed out of that block -- ignoring." % stamp())
        return False
    if dry_run:
        print("%s  --dry-run: not writing." % stamp())
        return False
    try:
        print("%s  %s" % (stamp(), M.apply_export(text)))
        return True
    except ValueError as e:
        print("%s  REFUSED: %s" % (stamp(), e))
    except Exception as e:                        # never let one bad block kill the watcher
        print("%s  ERROR applying: %s: %s" % (stamp(), type(e).__name__, e))
    return False


def main():
    # a watcher you pipe into `tee` must still print as it goes, not when the buffer fills
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except AttributeError:
        pass
    dry_run = "--dry-run" in sys.argv
    once = "--once" in sys.argv
    backfill = "--backfill" in sys.argv
    path = newest_rpt()
    if not path:
        sys.exit("no .rpt found in %s (set AP_RPT_DIR)" % RPT_DIR)
    print("watching %s" % path)
    print("  (start the export in 3DEN: call compile preprocessFileLineNumbers \"mapExportAll.sqf\")")

    seen = set()
    if backfill:
        with open(path, "r", encoding="latin-1") as fh:
            lines = fh.read().splitlines()
        block, cap = [], False
        for ln in lines:
            if BEGIN in ln:
                block, cap = [], True
            elif END in ln and cap:
                cap = False
            elif cap:
                block.append(ln)
        if block:
            print("%s  backfill: replaying the last block in the log" % stamp())
            if handle(block, dry_run, seen) and once:
                return

    offset = os.path.getsize(path)          # backfill already consumed the history
    buf, block, cap = "", [], False
    while True:
        newest = newest_rpt()
        if newest != path:                        # Arma restarted -> new log
            path, offset, buf, block, cap = newest, 0, "", [], False
            print("%s  switched to %s" % (stamp(), os.path.basename(path)))
        size = os.path.getsize(path)
        if size < offset:                         # truncated/rotated in place
            offset = 0
        if size > offset:
            with open(path, "rb") as fh:
                fh.seek(offset)
                chunk = fh.read(size - offset)
                offset = fh.tell()
            buf += chunk.decode("latin-1")
            *lines, buf = buf.split("\n")
            for ln in lines:
                if BEGIN in ln:
                    block, cap = [], True
                elif END in ln and cap:
                    cap = False
                    applied = handle(block, dry_run, seen)
                    block = []
                    if applied and once:
                        return
                elif cap:
                    block.append(ln)
        time.sleep(POLL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nstopped.")
