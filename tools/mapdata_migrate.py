#!/usr/bin/env python3
"""ONE-TIME: rewrite fn_mapData.sqf's positions from the ATL frame into the world frame.

Pairs with debug/mapMigrateWorld.sqf, which logs each row's true getPosWorld. Only the position
field changes; class, orientation, init, server flag and any loadout are carried through as the
original text, so a diff shows exactly one number triple per row and nothing else.

The whole risk here is MISALIGNMENT -- a row paired with a different row's reading. Row order is
the array's own order on both sides, and every reading also carries its class, so the class is
asserted per row and any mismatch aborts. It does not "resync" or skip: a single silent shift
would move thousands of objects, and this repo has already lost 835 rows once to a matching
heuristic that guessed.

    python3 tools/mapdata_migrate.py <rpt-with-MAPMIG-lines> [--write]
"""
import os
import re
import shutil
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(REPO, "mission", "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")

LOGLINE = re.compile(r"\[MAPMIG\] i=(\d+) cls=(\S+) world=([-\d.]+),([-\d.]+),([-\d.]+)")


def parse_rows(src):
    """Split the array into rows, keeping each row's text verbatim after the position field."""
    body = src[src.index("[") + 1:src.rindex("]")]
    rows, depth, start = [], 0, 0
    for i, ch in enumerate(body):
        if ch == "[":
            depth += 1
            if depth == 1:
                start = i
        elif ch == "]":
            depth -= 1
            if depth == 0:
                rows.append(body[start:i + 1])
    out = []
    for r in rows:
        # re.S and \Z, not `.` and `$`: four real rows carry a NEWLINE inside their init string
        # (an NPC that is both a DMV and a shop calls two functions on two lines). Without DOTALL
        # the row match stops at that newline; `$` would also match there. Nothing synthetic
        # catches this -- it only showed up when the parser was first run on the real 8,717 rows.
        # `[^"]*`, not `+`: a v3 model row (mapdb.md D2) carries an EMPTY classname.
        m = re.match(r'\["([^"]*)",\[([-\d.eE]+),([-\d.eE]+),([-\d.eE]+)\],(.*)\]\Z', r, re.S)
        if not m:
            sys.exit("unparsable row: %s" % r[:120])
        tail = m.group(5)
        im = re.match(r'(\[\[.*?\],\[.*?\]\]),"((?:[^"]|"")*)",(true|false)(.*)\Z', tail, re.S)
        if not im:
            sys.exit("unparsable row tail: %s" % tail[:120])
        out.append({"cls": m.group(1),
                    "pos": (float(m.group(2)), float(m.group(3)), float(m.group(4))),
                    "vec": im.group(1), "init": im.group(2).replace('""', '"'),
                    "server": im.group(3), "tail": im.group(4), "raw": r})
    return out


def parse_log(text):
    """Newest complete [MAPMIG] block in the file, as [(class, (x,y,z)), ...] indexed by row."""
    found = {}
    for line in text.splitlines():
        m = LOGLINE.search(line)
        if m:
            found[int(m.group(1))] = (m.group(2),
                                      (float(m.group(3)), float(m.group(4)), float(m.group(5))))
    return [found[i] for i in sorted(found)] if found else []


def rewrite(src, readings):
    rows = parse_rows(src)
    if len(rows) != len(readings):
        sys.exit("ABORT: %d rows but %d readings -- the log is from a different array"
                 % (len(rows), len(readings)))
    parts = []
    for i, (row, (cls, world)) in enumerate(zip(rows, readings)):
        if row["cls"] != cls:
            sys.exit("ABORT: row %d is %s but reading %d is %s -- alignment is broken, "
                     "nothing written" % (i, row["cls"], i, cls))
        parts.append('["%s",[%.3f,%.3f,%.3f],%s,"%s",%s%s]'
                     % (row["cls"], world[0], world[1], world[2], row["vec"],
                        row["init"].replace('"', '""'), row["server"], row["tail"]))
    return "allLocalMapEntities=[" + ",".join(parts) + "];\n"


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    readings = parse_log(open(sys.argv[1], errors="replace").read())
    if not readings:
        sys.exit("no [MAPMIG] lines in %s" % sys.argv[1])
    src = open(TARGET).read()
    out = rewrite(src, readings)
    print("rows migrated: %d" % len(readings))
    moved = sum(1 for a, b in zip(parse_rows(src), parse_rows(out))
                if abs(a["pos"][2] - b["pos"][2]) > 0.001)
    print("rows whose height changed: %d" % moved)
    if "--write" not in sys.argv:
        print("dry run -- pass --write to apply")
        return
    shutil.copy(TARGET, TARGET + ".bak")
    open(TARGET, "w").write(out)
    print("wrote %s (backup at %s.bak)" % (TARGET, TARGET))


if __name__ == "__main__":
    main()
