#!/usr/bin/env python3
"""
eden_to_mapdata.py  --  Author NPCs/objects in the Eden editor, round-trip them
back into LooneyBin's scripted spawn array (allLocalMapEntities in fn_mapData.sqf).

WHY: every shop NPC / prop on the map is data in core/config/fn_mapData.sqf, not
placed in mission.sqm, so they don't show in Eden. This converts Eden-placed
objects -> array entries so you can author them visually.

WORKFLOW
  1. In Eden, place your objects. For EACH one to export:
       - set its facing,
       - set its INIT field (use `this`, e.g.  [this,'STAND_U1','general'] call NPC_fnc_copShops; ),
       - give it a VARIABLE NAME starting with the export prefix (default "xp_"):
         Attributes -> Object: Init / Variable Name.  e.g.  xp_cop1, xp_cop2 ...
  2. Save the mission (plain Save -- keep it non-binarized).
  3. Run:   python3 tools/eden_to_mapdata.py
     Prints the array entries. Add  --insert  to append them into fn_mapData.sqf
     (a .bak is written first).
  4. Back in Eden: DELETE the exported (xp_*) objects and save again, so they
     don't spawn twice (once from mission.sqm, once from the array).

ENTRY FORMAT  ["class",[x,y,z],[[dirX,dirY,dirZ],[upX,upY,upZ]],"init",false]
  - mission.sqm position[]={X, HEIGHT(asl), Y}  ->  array [X, Y, z]
  - z is ATL (spawner uses setPosATL): we emit a small ground value (--z, default 0.2).
    Objects on elevated floors/roofs may need their z nudged by hand.
  - rotation: heading = angles[1] (rad) -> vectorDir=[sin,cos,0], up=[0,0,1] (flat/upright).
  - init: `this` -> `_this`; inner "" quotes kept as-is (sqm + array both use "").
"""
import sys, re, math, argparse, shutil, os

HERE = os.path.dirname(os.path.abspath(__file__))
SQM  = os.path.join(HERE, "..", "mission", "Armapunk2035.Malden", "mission.sqm")
MAP  = os.path.join(HERE, "..", "mission", "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")

def matching_brace(s, open_idx):
    depth = 0
    for j in range(open_idx, len(s)):
        if s[j] == '{': depth += 1
        elif s[j] == '}':
            depth -= 1
            if depth == 0: return j
    return -1

def iter_class(s, lo, hi):
    """Yield (name, body_lo, body_hi) for each `class NAME {...}` directly within s[lo:hi]."""
    pat = re.compile(r'class\s+([A-Za-z0-9_]+)\s*\{')
    i = lo
    while True:
        m = pat.search(s, i, hi)
        if not m: break
        ob = m.end() - 1
        cb = matching_brace(s, ob)
        if cb < 0 or cb > hi: break
        yield m.group(1), ob + 1, cb
        i = cb + 1

def first_str(body, key):
    m = re.search(r'\b' + re.escape(key) + r'\s*=\s*"((?:[^"]|"")*)"', body)
    return m.group(1) if m else None

def first_arr(body, key):
    m = re.search(r'\b' + re.escape(key) + r'\[\]\s*=\s*\{([^}]*)\}', body)
    if not m: return None
    return [x.strip() for x in m.group(1).split(',') if x.strip() != '']

def collect_objects(s, ent_lo, ent_hi, out):
    """Walk every Item in this Entities span; collect Objects, recurse into any nested Entities (groups/layers)."""
    for iname, ilo, ihi in iter_class(s, ent_lo, ent_hi):
        body = s[ilo:ihi]
        if first_str(body, 'dataType') == 'Object':
            out.append(body)
        for n2, l2, h2 in iter_class(s, ilo, ihi):      # groups carry a nested class Entities
            if n2 == 'Entities':
                collect_objects(s, l2, h2, out)

def to_entry(body, zdef):
    typ = first_str(body, 'type')
    pos = first_arr(body, 'position')
    ang = first_arr(body, 'angles')
    init = first_str(body, 'init') or ""
    if not typ or not pos or len(pos) < 3:
        return None
    x = float(pos[0]); y = float(pos[2])                 # sqm [X, height, Y] -> array X, Y
    heading = float(ang[1]) if ang and len(ang) >= 2 else 0.0
    dx = round(math.sin(heading), 6); dy = round(math.cos(heading), 6)
    init = re.sub(r'(?<![\w_])this(?![\w])', '_this', init)   # Eden `this` -> spawner `_this`
    return '["%s",[%g,%g,%s],[[%g,%g,0],[0,0,1]],"%s",false]' % (typ, x, y, zdef, dx, dy, init)

def main():
    ap = argparse.ArgumentParser(description="Eden objects -> allLocalMapEntities entries")
    ap.add_argument("--prefix", default="xp_", help='export objects whose Variable Name starts with this (default "xp_")')
    ap.add_argument("--all", action="store_true", help="export ALL objects (ignore prefix)")
    ap.add_argument("--z", type=float, default=0.2, help="ATL height for exported entries (default 0.2)")
    ap.add_argument("--insert", action="store_true", help="append entries into fn_mapData.sqf (writes a .bak first)")
    ap.add_argument("--sqm", default=SQM)
    ap.add_argument("--map", default=MAP)
    args = ap.parse_args()

    s = open(args.sqm, encoding="latin1").read()
    if re.search(r'binarizationWanted=1', s):
        sys.exit("mission.sqm looks binarized -- re-save it non-binarized (plain Save) first.")

    bodies = []
    for n, lo, hi in iter_class(s, 0, len(s)):
        if n == 'Mission':
            for n2, l2, h2 in iter_class(s, lo, hi):
                if n2 == 'Entities':
                    collect_objects(s, l2, h2, bodies)
            break

    if args.all:
        sel = bodies
    else:
        sel = [b for b in bodies if (first_str(b, 'name') or "").startswith(args.prefix)]
    if not sel:
        named = sorted({first_str(b, 'name') for b in bodies if first_str(b, 'name')})
        sys.exit("No objects matched prefix %r (of %d objects).\nNamed objects present: %s"
                 % (args.prefix, len(bodies), ", ".join(named[:40]) or "(none have variable names)"))

    entries = [e for e in (to_entry(b, args.z) for b in sel) if e]
    print("// %d object(s)%s:" % (len(entries), "" if args.all else " (prefix %r)" % args.prefix))
    for e in entries:
        print(e + ",")

    if args.insert:
        m = open(args.map, encoding="latin1").read()
        t = m.rstrip()
        if not t.endswith('];'):
            sys.exit("fn_mapData.sqf doesn't end with '];' -- insert manually.")
        new = t[:-2] + "," + ",".join(entries) + "];" + m[len(t):]
        shutil.copy(args.map, args.map + ".bak")
        open(args.map, "w", encoding="latin1").write(new)
        print("// inserted %d entries into fn_mapData.sqf (backup: fn_mapData.sqf.bak)" % len(entries))

if __name__ == "__main__":
    main()
