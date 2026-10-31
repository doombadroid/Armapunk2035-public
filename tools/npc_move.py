#!/usr/bin/env python3
"""
npc_move.py -- move a placed NPC (and its map marker) to a position and heading.

    python3 tools/npc_move.py --list                        # numbered list of every placed NPC
    python3 tools/npc_move.py 23 5895.84 3498.06 0.49 336   # move #23 there, facing 336
    python3 tools/npc_move.py gun 5895.84 3498.06 0.49 336 --near 5896 3498

SELECTING ONE. Easiest is the number from --list. A name also works -- 'gun', 'wongs', 'civDMV',
'courthouse' -- matched against the shop id and the NPC function. When a name matches more than one
(there are four gun stores), add --near X Y and the closest wins; without it the tool lists the
candidates and refuses rather than guessing.

WHAT IT TOUCHES. The NPC row in core/config/fn_mapData.sqf, and any marker of ours (lh_*) within
--marker-radius of the OLD position, so a shop's map label follows its NPC instead of staying where
the Eden comment put it. The designer's own marker_N labels are never moved.

HEADING is degrees clockwise from north, the same number the in-game debug shows. vectorDir is
[sin(h), cos(h), 0] -- X is the SINE, the opposite of the mathematical convention, pinned in 35b7d50d
by decoding a row that already existed. Getting it backwards silently encodes (180 - h) and turns the
NPC around. vecdir() below is the single copy; npc_place.py and npc_eden.py import it.

SAFETY. fn_mapData is a plain SQF array literal, so editing a row in place is safe. mission.sqm is
edited by ATTRIBUTE ONLY -- no block is added, removed or renumbered -- because deleting a class Item
from the middle of Mission>Entities breaks the numbering the engine walks and the mission stops
loading (5d5f8d01).

Changes do not reach the server until you deploy:
    bash /home/timb/arma3server_dev/reload-armapunk2035.sh
"""
import argparse
import math
import os
import re
import shutil
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAP = os.path.join(REPO, "mission/Armapunk2035.Malden/core/config/fn_mapData.sqf")
SQM = os.path.join(REPO, "mission/Armapunk2035.Malden/mission.sqm")
ROW = re.compile(r'\["([A-Za-z0-9_]+)",\[(-?[\d.]+),(-?[\d.]+),(-?[\d.]+)\],'
                 r'\[\[(-?[\d.]+),(-?[\d.]+),[^\]]*\],\[[^\]]*\]\],"((?:[^"]|"")*)",(true|false)\]')

# rough town centres, only so --list reads like the map instead of a coordinate dump
TOWNS = [("La Pessagne", 3150, 6330), ("Chapoi", 5880, 3560), ("La Port", 8180, 3180),
         ("Larche", 6030, 8620), ("Rebel/outpost", 5150, 9750), ("Prison", 9765, 3895)]


def npcs(text):
    out = []
    for m in ROW.finditer(text):
        init = m.group(7)
        if "NPC_fnc_" not in init:
            continue
        fn = re.search(r"NPC_fnc_(\w+)", init).group(1)
        ids = [i for i in re.findall(r"'([^']+)'", init) if not i.startswith("STAND")]
        # Only the generic dispatchers are named by their id; everything else by its function.
        # civDMV's init also contains a shops 'home' call, so keying purely on the last quoted id
        # would label the DMV "home" -- the same tag as the Home Improvement shop.
        DISPATCH = ("shops", "civProcessItem", "copShops", "civVehicles", "civRebelVehicles",
                    "copVehicles", "chopshop", "civFactory", "medVehicles")
        tag = ids[-1] if (ids and fn in DISPATCH) else fn
        out.append({"m": m, "cls": m.group(1),
                    "x": float(m.group(2)), "y": float(m.group(3)), "z": float(m.group(4)),
                    "dx": float(m.group(5)), "dy": float(m.group(6)),
                    "init": init, "fn": fn, "tag": tag})
    return out


def vecdir(deg):
    """heading (deg clockwise from north) -> the row's vectorDir x,y. X is the SINE."""
    r = math.radians(deg)
    return math.sin(r), math.cos(r)


def bearing(dx, dy):
    """the inverse of vecdir()."""
    return round(math.degrees(math.atan2(dx, dy)) % 360, 1)


def where(x, y):
    best, bd = "", 1e9
    for n, tx, ty in TOWNS:
        d = math.dist((x, y), (tx, ty))
        if d < bd:
            best, bd = n, d
    return best if bd < 900 else "-"


def do_list(rows):
    print(f"{'#':>3s}  {'tag':22s} {'area':14s} {'x':>9s} {'y':>9s} {'brg':>5s}  class")
    print("-" * 84)
    for i, r in enumerate(sorted(rows, key=lambda r: (where(r["x"], r["y"]), r["tag"]))):
        print(f"{rows.index(r):3d}  {r['tag']:22s} {where(r['x'], r['y']):14s} "
              f"{r['x']:9.2f} {r['y']:9.2f} {bearing(r['dx'], r['dy']):5.0f}  {r['cls']}")
    print(f"\n{len(rows)} NPCs.  Move one:  python3 tools/npc_move.py <#> X Y Z BEARING")


def move_marker(x_old, y_old, x, y, z, radius):
    t = open(SQM, encoding="utf-8", errors="surrogateescape").read()
    best = None
    for m in re.finditer(r'\bname\s*=\s*"(lh_[A-Za-z0-9_]+)"\s*;', t):
        st = t.rfind("class Item", 0, m.start())
        ob = t.index("{", st)
        d, i = 0, ob
        while i < len(t):
            if t[i] == "{":
                d += 1
            elif t[i] == "}":
                d -= 1
                if d == 0:
                    break
            i += 1
        blk = t[st:i + 1]
        pm = re.search(r"position\[\]=\{([-\d.]+),([-\d.]+),([-\d.]+)\};", blk)
        if not pm:
            continue
        dist = math.dist((float(pm.group(1)), float(pm.group(3))), (x_old, y_old))
        if dist <= radius and (best is None or dist < best[0]):
            best = (dist, st, i + 1, blk, m.group(1))
    if not best:
        return None
    _, st, en, blk, name = best
    new = re.sub(r"position\[\]=\{[^}]*\};", "position[]={%s,%s,%s};" % (x, z, y), blk, count=1)
    shutil.copy(SQM, SQM + ".bak-move")
    open(SQM, "w", encoding="utf-8", errors="surrogateescape").write(t[:st] + new + t[en:])
    return name


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("who", nargs="?", help="number from --list, or a name like gun / wongs / civDMV")
    ap.add_argument("x", nargs="?", type=float)
    ap.add_argument("y", nargs="?", type=float)
    ap.add_argument("z", nargs="?", type=float)
    ap.add_argument("heading", nargs="?", type=float)
    ap.add_argument("--near", nargs=2, type=float, metavar=("X", "Y"))
    ap.add_argument("--marker-radius", type=float, default=60.0)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    s = open(MAP, encoding="utf-8", errors="surrogateescape").read()
    rows = npcs(s)
    if a.list or a.who is None:
        do_list(rows)
        return 0
    if None in (a.x, a.y, a.z, a.heading):
        print("need: <#|name> X Y Z BEARING")
        return 2

    if a.who.isdigit() and int(a.who) < len(rows):
        pick = rows[int(a.who)]
    else:
        w = a.who.lower()
        cand = [r for r in rows if w == r["tag"].lower() or w == r["fn"].lower()
                or w in r["init"].lower()]
        if not cand:
            print(f"nothing matches {a.who!r}; try --list")
            return 1
        if len(cand) > 1:
            if not a.near:
                print(f"{len(cand)} match {a.who!r} -- add --near X Y, or use the number from --list:")
                for r in cand:
                    print(f"    #{rows.index(r):<3d} {r['tag']:20s} [{r['x']:8.2f},{r['y']:8.2f}] "
                          f"{where(r['x'], r['y'])}")
                return 2
            cand = [min(cand, key=lambda r: math.dist((r["x"], r["y"]), tuple(a.near)))]
        pick = cand[0]

    ox, oy = pick["x"], pick["y"]
    dx, dy = vecdir(a.heading)
    m = pick["m"]
    new = ('["%s",[%.3f,%.3f,%.3f],[[%.4f,%.4f,0.0000],[0.0000,0.0000,1.0000]],"%s",false]'
           % (pick["cls"], a.x, a.y, a.z, dx, dy, pick["init"].replace('"', '""')))
    print(f"  {pick['tag']} ({pick['cls']}) in {where(ox, oy)}")
    print(f"  [{ox:.2f},{oy:.2f}] brg {bearing(pick['dx'], pick['dy']):.0f}"
          f"  ->  [{a.x},{a.y},{a.z}] brg {a.heading:g}  vectorDir [{dx:.4f},{dy:.4f},0]")
    if a.dry_run:
        print("  (dry run, nothing written)")
        return 0
    shutil.copy(MAP, MAP + ".bak-move")
    open(MAP, "w", encoding="utf-8", errors="surrogateescape").write(s[:m.start()] + new + s[m.end():])
    mk = move_marker(ox, oy, a.x, a.y, a.z, a.marker_radius)
    print(f"  marker: {mk + ' moved too' if mk else 'none of ours within %g m' % a.marker_radius}")
    print("\n  deploy:  bash /home/timb/arma3server_dev/reload-armapunk2035.sh")
    return 0


if __name__ == "__main__":
    sys.exit(main())
