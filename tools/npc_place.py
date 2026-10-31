#!/usr/bin/env python3
"""
npc_place.py -- turn `-NPCPLACE-` probe lines into allLocalMapEntities rows.

The 108 NPC rows this fork inherited all sat on ALTIS coordinates, 15-25 km off a 12800 m world, so
no shop was reachable; they were removed with the rest of the Altis carryover in 621326b4. They are
still the SPEC though -- which unit class each shop uses and the exact init string that wires it --
so this reads them back out of that commit and re-places them at coordinates the owner marks in game.

    python3 tools/npc_place.py --list                 # what can be placed, and what is placed already
    python3 tools/npc_place.py                        # dry run: show the rows that would be added
    python3 tools/npc_place.py --write                # append them to fn_mapData.sqf (.bak first)

WHY APPEND ONLY. fn_mapData.sqf is one minified array and adding to the end is the operation that has
proven safe. (The sibling hazard is in mission.sqm, where DELETING a class Item block from the middle
leaves a gap in the Item numbering and the engine refuses the mission -- see 5d5f8d01.)

HEADING CONVENTION, and it is not the mathematical one. vectorDir is [sin(h), cos(h), 0] with h
clockwise from north -- the X component is the SINE. This was pinned by decoding a row that already
existed: [-0.5192,-0.8546,0] round-trips to 211.28 degrees only under this convention. Getting it
backwards encodes (180 - h) and turns the NPC around.
"""
import math
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from npc_move import vecdir   # one copy of the heading convention, see its docstring

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAPDATA = os.path.join(REPO, "mission/Armapunk2035.Malden/core/config/fn_mapData.sqf")
SPEC_COMMIT = "621326b4^"          # last commit that still carried the inherited NPC rows
RPT_GLOB = os.path.expanduser(
    "~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/"
    "AppData/Local/Arma 3")

ROW = re.compile(r'\["([A-Za-z0-9_]+)",\[(-?[\d.]+),(-?[\d.]+),(-?[\d.]+)\],'
                 r'\[\[[^\]]*\],\[[^\]]*\]\],"((?:[^"]|"")*)",(true|false)\]')


def spec():
    """tag -> (class, init) recovered from the pre-sweep mapData."""
    txt = subprocess.run(["git", "-C", REPO, "show",
                          f"{SPEC_COMMIT}:mission/Armapunk2035.Malden/core/config/fn_mapData.sqf"],
                         capture_output=True, text=True).stdout
    out = {}
    for cls, x, y, z, init, srv in ROW.findall(txt):
        if "NPC_fnc_" not in init:
            continue
        fn = re.search(r"NPC_fnc_(\w+)", init).group(1)
        ids = [i for i in re.findall(r"'([^']+)'", init) if not i.startswith("STAND")]
        tag = ids[-1] if ids else fn        # shop id when there is one, else the function name
        out.setdefault(tag, (cls, init, fn))
    return out


def placed():
    txt = open(MAPDATA, encoding="utf-8", errors="replace").read()
    return {re.search(r"NPC_fnc_(\w+)", i).group(1)
            for _, _, _, _, i, _ in ROW.findall(txt) if "NPC_fnc_" in i}


def marks():
    """Newest `-NPCPLACE- tag|x|y|z|dir` lines from the client RPT."""
    if not os.path.isdir(RPT_GLOB):
        return []
    rpts = sorted((os.path.join(RPT_GLOB, f) for f in os.listdir(RPT_GLOB) if f.endswith(".rpt")),
                  key=os.path.getmtime)
    if not rpts:
        return []
    seen = {}
    for line in open(rpts[-1], encoding="utf-8", errors="replace"):
        m = re.search(r"-NPCPLACE- ([^|]+)\|([-\d.]+)\|([-\d.]+)\|([-\d.]+)\|([-\d.]+)", line)
        if m:
            seen[m.group(1)] = tuple(float(v) for v in m.groups()[1:])   # last wins: re-mark to move
    return sorted(seen.items())


def build(tag, pos, deg, sp):
    if tag not in sp:
        return None, f"no spec for {tag!r}"
    cls, init, fn = sp[tag]
    dx, dy = vecdir(deg)
    x, y, z = pos
    return ('["%s",[%.3f,%.3f,%.3f],[[%.4f,%.4f,0.0000],[0.0000,0.0000,1.0000]],"%s",false]'
            % (cls, x, y, z, dx, dy, init.replace('"', '""')), None)


def main():
    sp, have = spec(), placed()
    if "--list" in sys.argv:
        print(f"{'tag':26s} {'placed':7s} {'class':26s} init")
        print("-" * 110)
        for tag, (cls, init, fn) in sorted(sp.items()):
            print(f"{tag:26s} {'yes' if fn in have else '-':7s} {cls:26s} {init[:52]}")
        print(f"\n{len(sp)} placeable, {len(have)} NPC function(s) already in the map data.")
        return 0

    ms = marks()
    if not ms:
        print("No -NPCPLACE- lines in the newest client RPT.")
        print("Paste debug/npcprobe.sqf in the debug console, then per NPC:  [\"gun\"] call AP_npcMark;")
        return 1

    rows, errs = [], []
    for tag, (x, y, z, d) in ms:
        row, err = build(tag, (x, y, z), d, sp)
        (errs if err else rows).append(err or row)
        print(f"  {tag:24s} [{x:8.2f},{y:8.2f},{z:6.2f}] dir {d:6.1f}  {'ERROR: '+err if err else 'ok'}")
    if errs:
        print("\nrefusing to write, unknown tags above (try --list)")
        return 2
    if "--write" not in sys.argv:
        print(f"\ndry run -- {len(rows)} row(s). Re-run with --write to append them.")
        return 0

    s = open(MAPDATA, encoding="utf-8", errors="surrogateescape").read()
    before = len(ROW.findall(s))
    i = s.rindex("]")                                   # close of the one array literal
    s = s[:i] + "," + ",".join(rows) + s[i:]
    shutil.copy(MAPDATA, MAPDATA + ".bak-npc")
    open(MAPDATA, "w", encoding="utf-8", errors="surrogateescape").write(s)
    after = len(ROW.findall(open(MAPDATA, encoding="utf-8", errors="replace").read()))
    print(f"\nrows {before} -> {after} (+{after-before}); expected +{len(rows)}")
    return 0 if after - before == len(rows) else 3


if __name__ == "__main__":
    sys.exit(main())
