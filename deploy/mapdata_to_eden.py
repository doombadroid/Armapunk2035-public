#!/usr/bin/env python3
"""
mapdata_to_eden.py  --  pull a REGION of the
scripted spawn array (allLocalMapEntities in fn_mapData.sqf) INTO mission.sqm so
the objects show up + are editable in the Eden editor.

USE A REGION, not everything: importing all hundreds of entries bloats mission.sqm
and every imported object would double-spawn until removed from the array.

WORKFLOW
  1. Dry run to see what's there:
       python3 tools/mapdata_to_eden.py --near 13814 18964 50
  2. Apply (writes the objects into mission.sqm AND removes them from the array,
     so there's exactly one copy; .bak written for both files):
       python3 tools/mapdata_to_eden.py --near 13814 18964 50 --apply
  3. Open Eden -> the objects are there, named imp_0, imp_1 ... Edit freely
     (swap classes, add ammo boxes/tables, move things). Save.
  4. Export your edited version back with the forward tool:
       rename/keep their Variable Names starting with xp_  (or pass --prefix imp_)
     then delete them in Eden + save.

HEIGHT: array z is ATL (above ground); mission.sqm needs ASL (above sea). We can't
read Altis terrain offline, so ASL is estimated from the nearest existing mission.sqm
objects (--height H overrides). Fine for flat shop areas; nudge in Eden if needed.
"""
import sys, re, math, argparse, shutil, os

HERE = os.path.dirname(os.path.abspath(__file__))
SQM  = os.path.join(HERE, "..", "mission", "Armapunk2035.Malden", "mission.sqm")
MAP  = os.path.join(HERE, "..", "mission", "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")

# ---- shared sqm helpers ----
def matching_brace(s, i):
    d = 0
    while i < len(s):
        if s[i] == '{': d += 1
        elif s[i] == '}':
            d -= 1
            if d == 0: return i
        i += 1
    return -1

def iter_class(s, lo, hi):
    pat = re.compile(r'class\s+([A-Za-z0-9_]+)\s*\{')
    i = lo
    while True:
        m = pat.search(s, i, hi)
        if not m: break
        ob = m.end() - 1; cb = matching_brace(s, ob)
        if cb < 0 or cb > hi: break
        yield m.group(1), ob + 1, cb
        i = cb + 1

def first_str(b, k):
    m = re.search(r'\b' + re.escape(k) + r'\s*=\s*"((?:[^"]|"")*)"', b)
    return m.group(1) if m else None

def first_arr(b, k):
    m = re.search(r'\b' + re.escape(k) + r'\[\]\s*=\s*\{([^}]*)\}', b)
    return [x.strip() for x in m.group(1).split(',')] if m else None

def sqm_object_heights(s):
    """Return list of (x, y, asl) for every Object in mission.sqm (for terrain estimate)."""
    pts = []
    def walk(lo, hi):
        for n, ilo, ihi in iter_class(s, lo, hi):
            b = s[ilo:ihi]
            if first_str(b, 'dataType') == 'Object':
                p = first_arr(b, 'position')
                if p and len(p) >= 3:
                    pts.append((float(p[0]), float(p[2]), float(p[1])))
            for n2, l2, h2 in iter_class(s, ilo, ihi):
                if n2 == 'Entities': walk(l2, h2)
    for n, lo, hi in iter_class(s, 0, len(s)):
        if n == 'Mission':
            for n2, l2, h2 in iter_class(s, lo, hi):
                if n2 == 'Entities': walk(l2, h2)
            break
    return pts

# ---- SQF array parser ----
def split_top(s):
    """Split a comma-separated SQF list (quote/bracket aware) into top-level elements; return (text, start, end)."""
    out = []; depth = 0; instr = False; start = 0; i = 0
    while i < len(s):
        c = s[i]
        if instr:
            if c == '"':
                if i + 1 < len(s) and s[i + 1] == '"': i += 2; continue
                instr = False
        else:
            if c == '"': instr = True
            elif c == '[': depth += 1
            elif c == ']': depth -= 1
            elif c == ',' and depth == 0:
                out.append((s[start:i], start, i)); start = i + 1
        i += 1
    if s[start:].strip(): out.append((s[start:], start, len(s)))
    return out

def parse_array(mapsrc):
    """Return (inner_start, inner_end, [entry dicts]). Entry: class,x,y,z,dir,init,raw,abs_start,abs_end."""
    m = re.search(r'allLocalMapEntities\s*=\s*\[', mapsrc)
    if not m: sys.exit("allLocalMapEntities not found in fn_mapData.sqf")
    inner_start = m.end()
    close = matching_brace_sq(mapsrc, m.end() - 1)
    inner = mapsrc[inner_start:close]
    entries = []
    for raw, rs, re_ in split_top(inner):
        e = raw.strip()
        if not e.startswith('['): continue
        fields = split_top(e[1:e.rfind(']')])
        if len(fields) < 5: continue
        cls = fields[0][0].strip().strip('"')
        pos = [x.strip() for x in fields[1][0].strip().lstrip('[').rstrip(']').split(',')]
        dirup = fields[2][0].strip()
        init = fields[3][0].strip()
        init = init[1:-1] if init.startswith('"') else ""
        entries.append(dict(cls=cls, x=float(pos[0]), y=float(pos[1]), z=float(pos[2]),
                            dirup=dirup, init=init, raw=raw,
                            abs_start=inner_start + rs, abs_end=inner_start + re_))
    return inner_start, close, entries

def matching_brace_sq(s, i):
    """Bracket [] matcher (quote aware), i points at '['."""
    d = 0; instr = False
    while i < len(s):
        c = s[i]
        if instr:
            if c == '"':
                if i + 1 < len(s) and s[i + 1] == '"': i += 2; continue
                instr = False
        else:
            if c == '"': instr = True
            elif c == '[': d += 1
            elif c == ']':
                d -= 1
                if d == 0: return i
        i += 1
    return -1

def heading_from_dirup(dirup):
    m = re.match(r'\[\[\s*([-0-9.eE]+)\s*,\s*([-0-9.eE]+)', dirup)
    if not m: return 0.0
    dx, dy = float(m.group(1)), float(m.group(2))
    return math.atan2(dx, dy)        # dir=[sin h, cos h] -> h

def est_asl(x, y, pts, radius=120.0):
    near = [a for (px, py, a) in pts if (px - x) ** 2 + (py - y) ** 2 <= radius * radius]
    if not near:
        near = sorted(pts, key=lambda p: (p[0]-x)**2+(p[1]-y)**2)[:1]
        near = [near[0][2]] if near else [0.0]
    near.sort()
    return near[len(near)//2]

def emit(idnum, e, asl, name):
    init = e['init'].replace('\r', ' ').replace('\n', ' ').replace('\t', ' ')   # config init="" strings can't hold raw newlines/tabs
    init = re.sub(r'(?<![\w])_this(?![\w])', 'this', init)        # spawner _this -> Eden this
    h = heading_from_dirup(e['dirup'])
    return ('class Item%d {dataType="Object";class PositionInfo {position[]={%g,%g,%g};angles[]={0,%g,0};};'
            'side="Empty";flags=4;class Attributes {init="%s";name="%s";disableSimulation=1;};id=%d;type="%s";};'
            % (idnum, e['x'], asl, e['y'], h, init, name, idnum, e['cls']))

def main():
    ap = argparse.ArgumentParser(description="array region -> mission.sqm objects")
    ap.add_argument("--near", nargs=3, type=float, metavar=("X", "Y", "R"), required=True, help="import entries within R metres of X,Y")
    ap.add_argument("--height", type=float, default=None, help="force ASL height (else estimate from nearby sqm objects)")
    ap.add_argument("--name", default="imp_", help='Variable Name prefix for imported objects (default "imp_")')
    ap.add_argument("--apply", action="store_true", help="write mission.sqm + strip from fn_mapData (else dry run)")
    ap.add_argument("--sqm", default=SQM); ap.add_argument("--map", default=MAP)
    args = ap.parse_args()
    X, Y, R = args.near

    mapsrc = open(args.map, encoding="latin1").read()
    _, _, entries = parse_array(mapsrc)
    hits = [e for e in entries if (e['x'] - X) ** 2 + (e['y'] - Y) ** 2 <= R * R]
    if not hits:
        sys.exit("No array entries within %g m of [%g,%g]." % (R, X, Y))

    print("// %d entr(y/ies) within %gm of [%g,%g]:" % (len(hits), R, X, Y))
    for e in hits:
        print("//   %-32s [%g,%g,%g]  init=%s" % (e['cls'], e['x'], e['y'], e['z'], (e['init'][:50] + '...') if len(e['init']) > 50 else e['init']))
    if not args.apply:
        print("// dry run -- add --apply to write them into mission.sqm + remove from the array.")
        return

    s = open(args.sqm, encoding="latin1").read()
    pts = sqm_object_heights(s)
    blocks = []
    for i, e in enumerate(hits):
        base = args.height if args.height is not None else est_asl(e['x'], e['y'], pts)
        asl = base + e['z']      # ground ASL + the object's own height-above-ground
        blocks.append(emit(900000 + i, e, asl, "%s%d" % (args.name, i)))
    # insert into top Mission>Entities (before its closing brace)
    mi = next(((lo, hi) for n, lo, hi in iter_class(s, 0, len(s)) if n == 'Mission'), None)
    if not mi: sys.exit("no class Mission in mission.sqm")
    ent = next(((l, h) for n, l, h in iter_class(s, mi[0], mi[1]) if n == 'Entities'), None)
    if not ent: sys.exit("no Mission>Entities in mission.sqm")
    ins = ent[1]                       # index of Entities closing '}'
    new_sqm = s[:ins] + "".join(blocks) + s[ins:]
    shutil.copy(args.sqm, args.sqm + ".bak"); open(args.sqm, "w", encoding="latin1").write(new_sqm)
    # remove hits from the array (right-to-left by span; also eat a neighbouring comma)
    spans = sorted([(e['abs_start'], e['abs_end']) for e in hits], reverse=True)
    out = mapsrc
    for a, b in spans:
        # swallow one comma adjacent to the entry
        lo, hi = a, b
        if out[hi:hi+1] == ',': hi += 1
        elif out[lo-1:lo] == ',': lo -= 1
        out = out[:lo] + out[hi:]
    shutil.copy(args.map, args.map + ".bak"); open(args.map, "w", encoding="latin1").write(out)
    print("// imported %d objects into mission.sqm (named %s0..) and removed them from the array. .bak written for both." % (len(blocks), args.name))

if __name__ == "__main__":
    main()
