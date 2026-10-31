#!/usr/bin/env python3
"""
sqm_strip_anchors.py -- losslessly parse a BINARIZED (rapified, "\\0raP") mission.sqm,
delete the custom-building Land_HelipadEmpty_F anchor Objects (whose init runs
createSimpleObject on a custom .p3d, now moved to init.sqf), renumber the surviving
ItemN classes + fix every `items=` count, and re-serialize a valid rapified mission.sqm.

Safety: a parse->serialize round-trip MUST reproduce the original file byte-for-byte
before any deletion is written. If it doesn't, we abort (serializer not trustworthy).
"""
import struct, sys, re

SRC = sys.argv[1] if len(sys.argv) > 1 else "mission.sqm"
data = open(SRC, "rb").read()
assert data[:4] == b"\x00raP", "not a binarized sqm"
ENUM_OFF = struct.unpack_from("<I", data, 12)[0]

CUSTOM = ("Bank","HQMesh","PoliceHQWallLong","AsylumGrandPalaceBuilding","PalaceShop",
          "JewelryBuildingModel","mentalasylum13","RebelRig","EvidenceSign","FederalReserveSign",
          "BridgeStraight","BridgeMiddle")  # bridge loop now lives in init.sqf; drop its anchor too

# ---------- lossless parser (capture raw byte spans for values/arrays) ----------
def asciiz(i):
    j = data.index(b"\x00", i); return data[i:j], j + 1            # bytes (no null)
def comp(i):
    v = 0; s = 0
    while True:
        b = data[i]; i += 1; v |= (b & 0x7f) << s
        if not (b & 0x80): break
        s += 7
    return v, i
def skip_value(sub, i):
    if sub == 0: return data.index(b"\x00", i) + 1
    if sub in (1, 2): return i + 4
    raise ValueError("bad value subtype %d @%d" % (sub, i))
def skip_array(i):
    n, i = comp(i)
    for _ in range(n):
        t = data[i]; i += 1
        if t == 3: i = skip_array(i)
        else: i = skip_value(t, i)
    return i

def parse_class(i):
    inh, i = asciiz(i)
    n, i = comp(i)
    entries = []
    for _ in range(n):
        t = data[i]; i += 1
        if t == 0:                              # class: name + uint32 body offset
            nm, i = asciiz(i); off = struct.unpack_from("<I", data, i)[0]; i += 4
            entries.append(["class", nm, off])
        elif t == 1:                            # value: subtype + name + value
            sub = data[i]; i += 1; nm, i = asciiz(i)
            vs = i; i = skip_value(sub, i)
            entries.append(["value", nm, sub, data[vs:i]])     # raw value bytes
        elif t == 2:                            # array: name + payload
            nm, i = asciiz(i); a0 = i; i = skip_array(i)
            entries.append(["array", nm, data[a0:i]])          # raw payload
        elif t == 3:
            nm, i = asciiz(i); entries.append(["extern", nm])
        elif t == 4:
            nm, i = asciiz(i); entries.append(["delete", nm])
        elif t == 5:                            # flagged array: name + int32 + payload
            nm, i = asciiz(i); flag = data[i:i+4]; i += 4
            a0 = i; i = skip_array(i)
            entries.append(["array5", nm, flag, data[a0:i]])
        else:
            raise ValueError("unknown entry type %d @%d" % (t, i-1))
    return inh, entries

def build(off):
    inh, entries = parse_class(off)
    for e in entries:
        if e[0] == "class":
            e[2] = build(e[2])                  # replace offset with subtree dict
    return {"inh": inh, "entries": entries}

root = build(16)

# ---------- lossless serializer (depth-first body layout, back-patched offsets) ----------
def enc_comp(v):
    out = bytearray()
    while True:
        b = v & 0x7f; v >>= 7
        out.append(b | 0x80 if v else b)
        if not v: break
    return bytes(out)

def serialize(root):
    out = bytearray(b"\x00raP")
    out.extend(struct.pack("<III", 0, 8, 0))    # enum offset patched at end
    fixups = []                                 # (patch_pos, child_node) -> child body offset
    body_off = {}
    sys.setrecursionlimit(1000000)
    def emit(node):
        # body layout: inh + count + entries + uint32(end-of-subtree) + children(depth-first)
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
        trail = len(out); out.extend(b"\x00\x00\x00\x00")  # placeholder: end-of-subtree offset
        for k in kids:
            emit(k)
        struct.pack_into("<I", out, trail, len(out))        # patch = offset after my whole subtree
    emit(root)
    for pos, child in fixups:
        struct.pack_into("<I", out, pos, body_off[id(child)])
    enum_off = len(out)
    out.extend(struct.pack("<I", 0))             # enum count 0 (matches source)
    struct.pack_into("<I", out, 12, enum_off)
    return bytes(out)

# ---------- ROUND-TRIP GATE ----------
rt = serialize(root)
if rt != data:
    # diagnose first divergence
    n = min(len(rt), len(data)); div = next((k for k in range(n) if rt[k] != data[k]), n)
    print("ROUND-TRIP FAILED. sizes src=%d out=%d first-diff@%d" % (len(data), len(rt), div))
    print("src:", data[max(0,div-8):div+8].hex(), "out:", rt[max(0,div-8):div+8].hex())
    sys.exit(1)
print("round-trip OK: serializer reproduces source byte-for-byte (%d bytes)" % len(data))

# ---------- DELETE anchors + renumber + fix counts ----------
def is_anchor(node):
    if not isinstance(node, dict): return False
    if not any(e[0]=="value" and e[1]==b"dataType" and e[3].rstrip(b"\x00")==b"Object" for e in node["entries"]):
        return False
    for e in node["entries"]:
        if e[0]=="class" and e[1]==b"Attributes":
            for ie in e[2]["entries"]:
                if ie[0]=="value" and ie[1]==b"init" and ie[2]==0:
                    init = ie[3].rstrip(b"\x00").decode("latin1")
                    m = re.search(r"\\([A-Za-z0-9_]+)\.p3d", init)
                    if m and m.group(1) in CUSTOM: return True
    return False

deleted = {"n": 0}
def fix_entities(node):
    """if node is an Entities-style container (has items= + ItemN classes), drop anchor
       items, renumber survivors 0..k-1, set items=k. recurse everywhere."""
    ents = node["entries"]
    has_items = any(e[0]=="value" and e[1]==b"items" for e in ents)
    item_classes = [e for e in ents if e[0]=="class" and e[1].startswith(b"Item")]
    if has_items and item_classes:
        survivors = []
        for e in item_classes:
            if is_anchor(e[2]):
                deleted["n"] += 1
            else:
                survivors.append(e)
        if len(survivors) != len(item_classes):
            # rebuild entries: keep non-Item entries in place, replace Item block with renumbered survivors
            non_items = [e for e in ents if not (e[0]=="class" and e[1].startswith(b"Item"))]
            for idx, e in enumerate(survivors):
                e[1] = ("Item%d" % idx).encode("latin1")
            node["entries"] = non_items + survivors
            # fix items= value (int subtype 2)
            for e in node["entries"]:
                if e[0]=="value" and e[1]==b"items":
                    e[3] = struct.pack("<i", len(survivors)); e[2] = 2
    # recurse into all child classes (use current entries)
    for e in node["entries"]:
        if e[0]=="class":
            fix_entities(e[2])


DROP = {b"Eden_Extended_Objects"}
removed = {"n": 0}

def enc_comp(v):
    out = bytearray()
    while True:
        b = v & 0x7f; v >>= 7
        if v: out.append(b | 0x80)
        else: out.append(b); break
    return bytes(out)

def filter_payload(buf):
    """buf = raw array payload: comp(count) then count items of (type byte + value)."""
    i = 0; v = 0; s = 0
    while True:                                   # inline comp() over buf
        b = buf[i]; i += 1; v |= (b & 0x7f) << s
        if not (b & 0x80): break
        s += 7
    n = v
    items = []
    for _ in range(n):
        t = buf[i]; start = i; i += 1
        if t == 0:
            j = buf.index(b"\x00", i); val = buf[i:j]; i = j + 1
            items.append((buf[start:i], val))
        elif t in (1, 2):
            i += 4; items.append((buf[start:i], None))
        elif t == 3:
            raise ValueError("nested array in addOns — unexpected")
        else:
            raise ValueError("bad item type %d" % t)
    keep = [it for it in items if it[1] not in DROP]
    removed["n"] += len(items) - len(keep)
    if len(keep) == len(items):
        return buf
    return enc_comp(len(keep)) + b"".join(it[0] for it in keep)

def strip_addons(node):
    for e in node["entries"]:
        if e[0] == "array" and e[1] in (b"addons", b"addOns", b"addOnsAuto"):
            e[2] = filter_payload(e[2])
        elif e[0] == "array5" and e[1] in (b"addons", b"addOns", b"addOnsAuto"):
            e[3] = filter_payload(e[3])
        elif e[0] == "class":
            strip_addons(e[2])

strip_addons(root)
print("addOns entries removed:", removed["n"])
out = serialize(root)
open("mission_noeden.sqm", "wb").write(out)
print("wrote  %d -> %d bytes" % (len(data), len(out)))
