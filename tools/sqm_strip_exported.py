#!/usr/bin/env python3
"""
sqm_strip_exported.py -- remove from mission.sqm the static objects that have been exported
into allLocalMapEntities (fn_mapData.sqf), so the map is not placed twice.

Pairs with debug/mapExportRuntime.sqf: that sweeps the world BEFORE fn_mapData runs and logs every
static sqm object with its true ATL position; this deletes exactly those entities from the sqm.

Matching is by class + XY within TOL metres. XY is used rather than Z because the sweep reports ATL
(above terrain) while the sqm stores world height -- the same reason the export had to run in the
engine at all. Class must match too, so co-located props are not confused for one another.

NEVER removed:
  - anything that is not dataType="Object" (markers, logic, triggers, groups, layers, comments)
  - any Object carrying an Attributes>>init string. A runtime sweep cannot read an Eden init, so
    those were excluded from the export and MUST stay here -- this is what keeps the designer's 72
    tree anchors (and every other init-driven placement) alive.
  - anything with isPlayable (the 201 player slots live in Groups)

Safety: the parse->serialize round-trip must reproduce the source byte-for-byte before any deletion
is written, and the surviving-object count is asserted afterwards.

Usage:  python3 tools/sqm_strip_exported.py <export.log> [--write]
"""
import struct, sys, os, re

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQM = os.path.join(REPO, "mission/Armapunk2035.Malden/mission.sqm")
TOL = 1.5

sys.setrecursionlimit(1000000)
data = open(SQM, "rb").read()
assert data[:4] == b"\x00raP", "not a binarized sqm"


def asciiz(i):
    j = data.index(b"\x00", i); return data[i:j], j + 1


def comp(i):
    v = s = 0
    while True:
        b = data[i]; i += 1
        v |= (b & 0x7F) << s
        if not (b & 0x80):
            return v, i
        s += 7


def skip_value(sub, i):
    if sub == 0:
        return data.index(b"\x00", i) + 1
    if sub in (1, 2):
        return i + 4
    raise ValueError("bad subtype %d" % sub)


def skip_array(i):
    n, i = comp(i)
    for _ in range(n):
        t = data[i]; i += 1
        i = skip_array(i) if t == 3 else skip_value(t, i)
    return i


def parse_class(i):
    inh, i = asciiz(i)
    n, i = comp(i)
    entries = []
    for _ in range(n):
        t = data[i]; i += 1
        if t == 0:
            nm, i = asciiz(i); off = struct.unpack_from("<I", data, i)[0]; i += 4
            entries.append(["class", nm, off])
        elif t == 1:
            sub = data[i]; i += 1; nm, i = asciiz(i); vs = i; i = skip_value(sub, i)
            entries.append(["value", nm, sub, data[vs:i]])
        elif t == 2:
            nm, i = asciiz(i); a0 = i; i = skip_array(i)
            entries.append(["array", nm, data[a0:i]])
        elif t == 3:
            nm, i = asciiz(i); entries.append(["extern", nm])
        elif t == 4:
            nm, i = asciiz(i); entries.append(["delete", nm])
        elif t == 5:
            nm, i = asciiz(i); flag = data[i:i + 4]; i += 4; a0 = i; i = skip_array(i)
            entries.append(["array5", nm, flag, data[a0:i]])
        else:
            raise ValueError("unknown entry type %d" % t)
    return inh, entries


def build(off=16):
    inh, entries = parse_class(off)
    for e in entries:
        if e[0] == "class":
            e[2] = build(e[2])
    return {"inh": inh, "entries": entries}


def enc_comp(v):
    out = bytearray()
    while True:
        b = v & 0x7F; v >>= 7
        out.append(b | 0x80 if v else b)
        if not v:
            return bytes(out)


def serialize(root):
    out = bytearray(b"\x00raP")
    out.extend(struct.pack("<III", 0, 8, 0))
    fixups, body_off = [], {}

    def emit(node):
        body_off[id(node)] = len(out)
        out.extend(node["inh"]); out.append(0)
        out.extend(enc_comp(len(node["entries"])))
        kids = []
        for e in node["entries"]:
            if e[0] == "class":
                out.append(0); out.extend(e[1]); out.append(0)
                fixups.append((len(out), e[2])); out.extend(b"\x00\x00\x00\x00")
                kids.append(e[2])
            elif e[0] == "value":
                out.append(1); out.append(e[2]); out.extend(e[1]); out.append(0); out.extend(e[3])
            elif e[0] == "array":
                out.append(2); out.extend(e[1]); out.append(0); out.extend(e[2])
            elif e[0] == "extern":
                out.append(3); out.extend(e[1]); out.append(0)
            elif e[0] == "delete":
                out.append(4); out.extend(e[1]); out.append(0)
            elif e[0] == "array5":
                out.append(5); out.extend(e[1]); out.append(0); out.extend(e[2]); out.extend(e[3])
        trail = len(out); out.extend(b"\x00\x00\x00\x00")
        for k in kids:
            emit(k)
        struct.pack_into("<I", out, trail, len(out))

    emit(root)
    for pos, child in fixups:
        struct.pack_into("<I", out, pos, body_off[id(child)])
    enum_off = len(out)
    out.extend(struct.pack("<I", 0))
    struct.pack_into("<I", out, 12, enum_off)
    return bytes(out)


def gc(n, name):
    for e in n["entries"]:
        if e[0] == "class" and e[1] == name:
            return e[2]


def gv(n, name):
    for e in n["entries"]:
        if e[0] == "value" and e[1] == name:
            return e


def farr(buf):
    i, v, s = 0, 0, 0
    while True:
        b = buf[i]; i += 1
        v |= (b & 0x7F) << s
        if not (b & 0x80):
            break
        s += 7
    out = []
    for _ in range(v):
        t = buf[i]; i += 1
        if t == 1:
            out.append(struct.unpack_from("<f", buf, i)[0]); i += 4
        elif t == 2:
            out.append(float(struct.unpack_from("<i", buf, i)[0])); i += 4
        else:
            j = buf.index(b"\x00", i); out.append(0.0); i = j + 1
    return out


def main():
    write = "--write" in sys.argv
    logpath = sys.argv[1]

    exported = {}
    for ln in open(logpath, errors="replace"):
        # the RPT wraps the logged string in quotes and DOUBLES every internal one, so the class name
        # arrives as [""Land_x"",... -- undouble before matching
        ln = ln.replace('""', '"')
        m = re.search(r'-MAPEXPORT- \["([^"]+)",\[([-0-9.]+),([-0-9.]+),', ln)
        if m:
            entry = ln[ln.index("-MAPEXPORT- ") + 12:].rstrip().rstrip('"').rstrip()
            exported.setdefault(m.group(1), []).append(
                (float(m.group(2)), float(m.group(3)), entry))
    print("exported classes: %d, positions: %d"
          % (len(exported), sum(len(v) for v in exported.values())))

    root = build()
    rt = serialize(root)
    if rt != data:
        n = min(len(rt), len(data))
        div = next((k for k in range(n) if rt[k] != data[k]), n)
        print("ROUND-TRIP FAILED first-diff@%d" % div); sys.exit(1)
    print("round-trip OK (%d bytes)" % len(data))

    # spatial index of exported positions per class
    grid = {}
    for cls, pts in exported.items():
        g = {}
        for x, y, entry in pts:
            g.setdefault((int(x // TOL), int(y // TOL)), []).append((x, y, entry))
        grid[cls] = g

    stats = {"removed": 0, "kept_init": 0, "kept_other": 0}
    # Entries for the objects we ACTUALLY delete. Emitting these here rather than filtering the raw
    # sweep separately is what keeps insert and delete in lockstep: an object can only enter
    # allLocalMapEntities by being removed from the sqm in the same pass, so neither doubling nor
    # silent loss is possible.
    matched = []

    def is_exported(node):
        dt = gv(node, b"dataType")
        if not dt or dt[3].rstrip(b"\x00") != b"Object":
            return False
        at = gc(node, b"Attributes")
        if at and gv(at, b"init"):
            stats["kept_init"] += 1
            return False
        if at and gv(at, b"isPlayable"):
            return False
        ty = gv(node, b"type")
        pi = gc(node, b"PositionInfo")
        if not ty or not pi:
            return False
        cls = ty[3].rstrip(b"\x00").decode("latin1")
        g = grid.get(cls)
        if not g:
            return False
        pos = None
        for a in pi["entries"]:
            if a[0] == "array" and a[1] == b"position":
                pos = farr(a[2])
        if not pos or len(pos) < 3:
            return False
        x, y = pos[0], pos[2]
        cx, cy = int(x // TOL), int(y // TOL)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for (ex, ey, entry) in g.get((cx + dx, cy + dy), ()):
                    if abs(ex - x) <= TOL and abs(ey - y) <= TOL:
                        stats["removed"] += 1
                        matched.append(entry[:-1] + ',"",false]')
                        return True
        return False

    def prune(node):
        ents = node["entries"]
        has_items = any(e[0] == "value" and e[1] == b"items" for e in ents)
        item_classes = [e for e in ents if e[0] == "class" and e[1].startswith(b"Item")]
        if has_items and item_classes:
            survivors = [e for e in item_classes if not is_exported(e[2])]
            if len(survivors) != len(item_classes):
                non_items = [e for e in ents if not (e[0] == "class" and e[1].startswith(b"Item"))]
                for idx, e in enumerate(survivors):
                    e[1] = ("Item%d" % idx).encode("latin1")
                node["entries"] = non_items + survivors
                for e in node["entries"]:
                    if e[0] == "value" and e[1] == b"items":
                        e[2] = 2
                        e[3] = struct.pack("<i", len(survivors))
        for e in node["entries"]:
            if e[0] == "class":
                prune(e[2])

    prune(root)
    print("removed from sqm : %d" % stats["removed"])
    print("kept (has init)  : %d" % stats["kept_init"])

    out = serialize(root)
    print("sqm size: %d -> %d bytes" % (len(data), len(out)))

    assert len(matched) == stats["removed"], "matched/removed mismatch"
    mpath = os.path.join(REPO, "build", "mapdata_new_entries.sqf")
    os.makedirs(os.path.dirname(mpath), exist_ok=True)
    open(mpath, "w", encoding="latin1").write(",\n".join(matched))
    print("wrote %d matching mapData entries -> %s" % (len(matched), mpath))

    if write:
        open(SQM, "wb").write(out)
        print("WROTE %s" % SQM)
    else:
        print("(dry run -- pass --write)")


if __name__ == "__main__":
    main()
