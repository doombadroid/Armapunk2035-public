#!/usr/bin/env python3
"""
sqm_extract.py -- parse a BINARIZED (rapified, "\0raP") mission.sqm and pull every
Eden Object's [type, position, angles(rad), init]. Built for ProjectMaldenMerge: the
custom buildings are spawned by createSimpleObject inside Land_HelipadEmpty_F anchors'
init=, so we need each anchor's world pos + heading to re-emit a clean scripted loader.
Usage: sqm_extract.py <mission.sqm>
"""
import struct, sys, re, math

data = open(sys.argv[1], "rb").read()
assert data[:4] == b"\x00raP", "not a binarized sqm"

def asciiz(i):
    j = data.index(b"\x00", i); return data[i:j].decode("latin1"), j + 1
def comp(i):
    v = 0; s = 0
    while True:
        b = data[i]; i += 1; v |= (b & 0x7f) << s
        if not (b & 0x80): break
        s += 7
    return v, i
def value(sub, i):
    if sub == 0: return asciiz(i)
    if sub == 1: return struct.unpack_from("<f", data, i)[0], i + 4
    if sub == 2: return struct.unpack_from("<i", data, i)[0], i + 4
    return None, i
def arr(i):
    n, i = comp(i); out = []
    for _ in range(n):
        t = data[i]; i += 1
        if t == 3:
            a, i = arr(i); out.append(a)
        else:
            v, i = value(t, i); out.append(v)
    return out, i

def parse_class(i):
    """body: inherited asciiz, nEntries comp, entries -> (props, subclasses[(name,off)])"""
    _inh, i = asciiz(i)
    n, i = comp(i)
    props = {}; subs = []
    for _ in range(n):
        t = data[i]; i += 1
        if t == 0:                         # embedded class -> name + uint32 body offset
            nm, i = asciiz(i); off = struct.unpack_from("<I", data, i)[0]; i += 4
            subs.append((nm, off))
        elif t == 1:                       # value
            sub = data[i]; i += 1; nm, i = asciiz(i); v, i = value(sub, i); props[nm] = v
        elif t == 2:                       # array
            nm, i = asciiz(i); v, i = arr(i); props[nm] = v
        elif t in (3, 4):                  # extern/delete class -> name only
            nm, i = asciiz(i)
        elif t == 5:                       # array w/ flags: name + int32 + array
            nm, i = asciiz(i); i += 4; v, i = arr(i); props[nm] = v
        else:
            break
    return props, subs

def node(off):
    props, subs = parse_class(off)
    d = {"props": props, "subs": {}}
    for nm, o in subs:
        d["subs"][nm] = node(o)
    return d

root = node(16)

def walk(n):
    yield n
    for c in n["subs"].values():
        yield from walk(c)

objs = []
for n in walk(root):
    p = n["props"]
    if p.get("dataType") == "Object":
        pi = n["subs"].get("PositionInfo", {}).get("props", {})
        at = n["subs"].get("Attributes", {}).get("props", {})
        pos = pi.get("position"); ang = pi.get("angles")
        init = at.get("init", "")
        objs.append((p.get("type", "?"), pos, ang, init))

CUSTOM = ("Bank","HQMesh","PoliceHQWallLong","AsylumGrandPalaceBuilding","PalaceShop",
          "JewelryBuildingModel","mentalasylum13","RebelRig","EvidenceSign","FederalReserveSign")
print("# total Objects: %d" % len(objs))
hits = []
for typ, pos, ang, init in objs:
    m = re.search(r"\\([A-Za-z0-9_]+)\.p3d", init or "")
    if not m or m.group(1) not in CUSTOM: continue
    model = m.group(1)
    # Eden position[] = [X, Yasl(height), Z(map-Y)]; heading from angles[1] (Y rotation, rad) -> deg
    if pos and len(pos) >= 3:
        X, H, Y = pos[0], pos[1], pos[2]
    else:
        X = H = Y = None
    head = None
    if ang and len(ang) >= 2 and isinstance(ang[1], float):
        head = round(math.degrees(ang[1]) % 360, 1)
    fixed = re.search(r"setDir\s+(\d+)", init)
    hits.append((model, X, Y, H, head, fixed.group(1) if fixed else None))
    print("%-30s pos=[%s, %s]  asl=%s  headDeg=%s%s" % (
        model, round(X,2) if X else X, round(Y,2) if Y else Y,
        round(H,2) if H is not None else H, head,
        "  setDir=%s(fixed)"%fixed.group(1) if fixed else ""))
print("# custom-building placements: %d" % len(hits))
