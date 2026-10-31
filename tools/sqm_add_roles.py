#!/usr/bin/env python3
"""
sqm_add_roles.py -- give the Malden mission its PLAYER SLOTS.

The designer's ProjectMaldenMerge sqm contains no playable units at all, so the server
boots with `Number of roles (0)` and nobody can join. Arma assigns roles from the lobby
BEFORE any script runs, so slots cannot be created at runtime -- they have to exist in
mission.sqm. This copies the 201 playable units (138 groups) out of the Altis sqm.

Why copy rather than generate: the slot NAMES are load-bearing. `core/fn_initCop.sqf:17`
gates the SGT+ slot on `(str player) in ["cop_17"]`, and the lobby descriptions
("WhiteListed - Cop", "Whitelisted - Trauma Team (TT)", ...) are what staff whitelist
against. A generated set would silently change both.

The two files are in different formats: Altis ships a TEXT sqm, Malden a BINARIZED
(rapified, "\\0raP") one. So this parses the text tree, encodes it into rapified nodes,
and splices them into Malden's Mission>Entities.

Safety: the rapified parse->serialize round-trip MUST reproduce Malden's sqm byte-for-byte
before anything is spliced in. If it doesn't, the serializer isn't trustworthy and we abort.

Positions: the Altis slots sit on that map's northmost islet. That spot is off-map on
Malden (12.8km vs 30.7km), so the cluster is translated to an empty corner, keeping its
relative layout. It is only ever a few seconds' holding spot -- fn_spawnMenu immediately
does `player setPosASL [worldSize/2, worldSize/2, 50000]; player enableSimulation false`
and holds them there, sim off, until they pick a spawn. That code is already map-agnostic
(worldSize resolves per world), which is why none of it needed porting.

Usage:  python3 tools/sqm_add_roles.py [--write]
"""
import struct, sys, re, os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MALDEN = os.path.join(REPO, "mission/Armapunk2035.Malden/mission.sqm")
ALTIS = "/home/timb/loonybin-doomba/mission/LooneyBin.Altis/mission.sqm"

# Empty corner of Malden to park the slots in. Every object in the designer's sqm was
# binned into 1km cells; the y=0 row and x=0 column came back with 0 of 13,202 objects,
# so this disturbs nothing. Height 0.5 = sea level: infantry snap to the surface, and if
# it is open water they simply tread water for the few seconds before the 50km hold.
HOLD_CENTRE = (1000.0, 500.0)
HOLD_HEIGHT = 0.5

# Malden's highest existing entity id is 39367; start well clear of it.
ID_BASE = 50000

sys.setrecursionlimit(1000000)


# --------------------------------------------------------------------------------------
# rapified (binary) reader -- lossless: value/array payloads are kept as raw byte spans
# --------------------------------------------------------------------------------------
class Rap:
    def __init__(self, data):
        self.d = data
        assert data[:4] == b"\x00raP", "not a binarized sqm"

    def asciiz(self, i):
        j = self.d.index(b"\x00", i)
        return self.d[i:j], j + 1

    def comp(self, i):
        v = s = 0
        while True:
            b = self.d[i]; i += 1
            v |= (b & 0x7F) << s
            if not (b & 0x80):
                return v, i
            s += 7

    def skip_value(self, sub, i):
        if sub == 0:
            return self.d.index(b"\x00", i) + 1
        if sub in (1, 2):
            return i + 4
        raise ValueError("bad value subtype %d @%d" % (sub, i))

    def skip_array(self, i):
        n, i = self.comp(i)
        for _ in range(n):
            t = self.d[i]; i += 1
            i = self.skip_array(i) if t == 3 else self.skip_value(t, i)
        return i

    def parse_class(self, i):
        inh, i = self.asciiz(i)
        n, i = self.comp(i)
        entries = []
        for _ in range(n):
            t = self.d[i]; i += 1
            if t == 0:                                   # class: name + uint32 body offset
                nm, i = self.asciiz(i)
                off = struct.unpack_from("<I", self.d, i)[0]; i += 4
                entries.append(["class", nm, off])
            elif t == 1:                                 # value: subtype + name + payload
                sub = self.d[i]; i += 1
                nm, i = self.asciiz(i)
                vs = i; i = self.skip_value(sub, i)
                entries.append(["value", nm, sub, self.d[vs:i]])
            elif t == 2:                                 # array: name + payload
                nm, i = self.asciiz(i)
                a0 = i; i = self.skip_array(i)
                entries.append(["array", nm, self.d[a0:i]])
            elif t == 3:
                nm, i = self.asciiz(i); entries.append(["extern", nm])
            elif t == 4:
                nm, i = self.asciiz(i); entries.append(["delete", nm])
            elif t == 5:                                 # flagged array: name + int32 + payload
                nm, i = self.asciiz(i)
                flag = self.d[i:i + 4]; i += 4
                a0 = i; i = self.skip_array(i)
                entries.append(["array5", nm, flag, self.d[a0:i]])
            else:
                raise ValueError("unknown entry type %d @%d" % (t, i - 1))
        return inh, entries

    def build(self, off=16):
        inh, entries = self.parse_class(off)
        for e in entries:
            if e[0] == "class":
                e[2] = self.build(e[2])
            elif e[0] == "array":
                e[2] = e[2]
        return {"inh": inh, "entries": entries}


def enc_comp(v):
    out = bytearray()
    while True:
        b = v & 0x7F; v >>= 7
        out.append(b | 0x80 if v else b)
        if not v:
            return bytes(out)


def serialize(root):
    """Depth-first body layout with back-patched offsets -- the inverse of Rap.build."""
    out = bytearray(b"\x00raP")
    out.extend(struct.pack("<III", 0, 8, 0))    # enum offset patched at the end
    fixups = []
    body_off = {}

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
        struct.pack_into("<I", out, trail, len(out))     # offset just past my whole subtree

    emit(root)
    for pos, child in fixups:
        struct.pack_into("<I", out, pos, body_off[id(child)])
    enum_off = len(out)
    out.extend(struct.pack("<I", 0))                     # enum count 0 (matches source)
    struct.pack_into("<I", out, 12, enum_off)
    return bytes(out)


# --------------------------------------------------------------------------------------
# text sqm reader -> the SAME node shape, so the two trees are interchangeable
# --------------------------------------------------------------------------------------
def enc_number(tok):
    """Eden writes a bare integer as an int and anything with a '.'/exponent as a float.
    Mixed numeric arrays are normal in Eden output (`angles[]={0,4.98,0}`) and getArray
    reads either as a scalar, so preserving the distinction is enough."""
    if re.fullmatch(r"[+-]?\d+", tok):
        return 2, struct.pack("<i", int(tok))
    return 1, struct.pack("<f", float(tok))


class TextSqm:
    """Recursive-descent over the Altis text sqm. Only the constructs Eden emits."""

    def __init__(self, text):
        self.t = text

    def _skip_ws(self, i):
        while i < len(self.t) and self.t[i] in " \t\r\n":
            i += 1
        return i

    def _string(self, i):
        assert self.t[i] == '"'
        i += 1
        out = []
        while True:
            c = self.t[i]
            if c == '"':
                if i + 1 < len(self.t) and self.t[i + 1] == '"':   # "" = one escaped quote
                    out.append('"'); i += 2; continue
                return "".join(out), i + 1
            out.append(c); i += 1

    def _array(self, i):
        """Returns (payload_bytes, next_index). Payload = comp(count) + typed items."""
        assert self.t[i] == "{"
        i += 1
        items = []
        while True:
            i = self._skip_ws(i)
            if self.t[i] == "}":
                i += 1
                break
            if self.t[i] == ",":
                i += 1
                continue
            if self.t[i] == "{":
                payload, i = self._array(i)
                items.append(b"\x03" + payload)
            elif self.t[i] == '"':
                s, i = self._string(i)
                items.append(b"\x00" + s.encode("latin1") + b"\x00")
            else:
                j = i
                while self.t[j] not in ",}\r\n":
                    j += 1
                sub, raw = enc_number(self.t[i:j].strip())
                items.append(bytes([sub]) + raw)
                i = j
        return enc_comp(len(items)) + b"".join(items), i

    def parse_body(self, i):
        """i points just after the '{' of a class body. Returns (node, index past '}')."""
        entries = []
        while True:
            i = self._skip_ws(i)
            if self.t[i] == "}":
                i += 1
                while i < len(self.t) and self.t[i] in " \t\r\n;":
                    i += 1
                return {"inh": b"", "entries": entries}, i
            if self.t.startswith("class", i) and self.t[i + 5] in " \t":
                j = i + 5
                j = self._skip_ws(j)
                k = j
                while self.t[k] not in " \t\r\n{;":
                    k += 1
                name = self.t[j:k]
                k = self._skip_ws(k)
                assert self.t[k] == "{", "bodyless class in sqm: %r" % name
                child, i = self.parse_body(k + 1)
                entries.append(["class", name.encode("latin1"), child])
                continue
            # NAME=VALUE;  or  NAME[]={...};
            k = i
            while self.t[k] not in "=[":
                k += 1
            name = self.t[i:k].strip()
            if self.t[k] == "[":
                assert self.t[k:k + 3] == "[]=", "unexpected '[' at %d" % k
                payload, i = self._array(self._skip_ws(k + 3))
                entries.append(["array", name.encode("latin1"), payload])
            else:
                v = self._skip_ws(k + 1)
                if self.t[v] == '"':
                    s, i = self._string(v)
                    entries.append(["value", name.encode("latin1"), 0,
                                    s.encode("latin1") + b"\x00"])
                else:
                    j = v
                    while self.t[j] != ";":
                        j += 1
                    sub, raw = enc_number(self.t[v:j].strip())
                    entries.append(["value", name.encode("latin1"), sub, raw])
                    i = j
            while i < len(self.t) and self.t[i] in " \t\r\n;":
                i += 1


# --------------------------------------------------------------------------------------
# node helpers
# --------------------------------------------------------------------------------------
def get_class(node, name):
    for e in node["entries"]:
        if e[0] == "class" and e[1] == name:
            return e[2]
    return None


def get_value(node, name):
    for e in node["entries"]:
        if e[0] == "value" and e[1] == name:
            return e
    return None


def decode_float_array(payload):
    i, v, s = 0, 0, 0
    while True:
        b = payload[i]; i += 1
        v |= (b & 0x7F) << s
        if not (b & 0x80):
            break
        s += 7
    out = []
    for _ in range(v):
        t = payload[i]; i += 1
        if t == 1:
            out.append(struct.unpack_from("<f", payload, i)[0]); i += 4
        elif t == 2:
            out.append(float(struct.unpack_from("<i", payload, i)[0])); i += 4
        else:
            raise ValueError("non-numeric item in position array")
    return out


def encode_float_array(vals):
    return enc_comp(len(vals)) + b"".join(b"\x01" + struct.pack("<f", v) for v in vals)


# --------------------------------------------------------------------------------------
def main():
    write = "--write" in sys.argv

    # ---- refuse against a post-rework sqm -------------------------------------------
    # This tool predates the 2026-08 faction rework (all-civ slots); it re-adds the
    # RETIRED 201-slot layout (cop_17 and the 200 slots around it) that PR7 deleted. Checked
    # here as a raw byte search, BEFORE the binarized parse below, because a post-rework
    # mission.sqm is also a TEXT sqm (the 2026-07-30 convention) and would fail that parse
    # first with an unrelated "not a binarized sqm" message -- this is the real reason to stop.
    mdata = open(MALDEN, "rb").read()
    if b"cop_17" not in mdata:
        print("REFUSING: no cop_17 slot in mission.sqm. This tool predates the 2026-08 "
              "faction rework (all-civ slots) and re-adds the RETIRED 201-slot layout -- "
              "it must not run against a post-rework sqm.")
        sys.exit(1)

    # ---- Malden: parse + ROUND-TRIP GATE -------------------------------------------
    mroot = Rap(mdata).build()
    rt = serialize(mroot)
    if rt != mdata:
        n = min(len(rt), len(mdata))
        div = next((k for k in range(n) if rt[k] != mdata[k]), n)
        print("ROUND-TRIP FAILED. src=%d out=%d first-diff@%d" % (len(mdata), len(rt), div))
        sys.exit(1)
    print("round-trip OK: serializer reproduces Malden sqm byte-for-byte (%d bytes)" % len(mdata))

    mission = get_class(mroot, b"Mission")
    entities = get_class(mission, b"Entities")
    items_val = get_value(entities, b"items")
    before = struct.unpack("<i", items_val[3])[0]

    # ---- Altis: pull out every playable group ---------------------------------------
    atext = open(ALTIS, encoding="latin1").read()
    parser = TextSqm(atext)

    def brace_span(i):
        b = atext.find("{", i); d = 0; j = b
        while j < len(atext):
            if atext[j] == "{":
                d += 1
            elif atext[j] == "}":
                d -= 1
                if d == 0:
                    return b, j
            j += 1
        raise ValueError("unbalanced")

    groups, seen = [], set()
    for m in re.finditer(r'dataType="Group";', atext):
        s = atext.rfind("class ", 0, m.start())
        if s in seen:
            continue
        seen.add(s)
        b, e = brace_span(s)
        if "isPlayable=1" not in atext[b:e]:
            continue
        node, _ = parser.parse_body(b + 1)
        groups.append(node)

    units = sum(1 for g in groups for _ in iter_units(g))
    print("Altis playable groups: %d  units: %d" % (len(groups), units))
    if not groups:
        print("no playable groups found -- aborting"); sys.exit(1)

    # ---- translate the cluster, keeping its relative layout --------------------------
    pts = [decode_float_array(get_class(u, b"PositionInfo") and
                              [e for e in get_class(u, b"PositionInfo")["entries"]
                               if e[0] == "array" and e[1] == b"position"][0][2])
           for g in groups for u in iter_units(g)]
    cx = (min(p[0] for p in pts) + max(p[0] for p in pts)) / 2.0
    cy = (min(p[2] for p in pts) + max(p[2] for p in pts)) / 2.0
    print("Altis cluster centre [%.1f, %.1f] -> Malden [%.1f, %.1f]"
          % (cx, cy, HOLD_CENTRE[0], HOLD_CENTRE[1]))

    nid = ID_BASE
    for g in groups:
        for u in iter_units(g):
            pi = get_class(u, b"PositionInfo")
            for e in pi["entries"]:
                if e[0] == "array" and e[1] == b"position":
                    x, _, y = decode_float_array(e[2])
                    e[2] = encode_float_array([x - cx + HOLD_CENTRE[0],
                                               HOLD_HEIGHT,
                                               y - cy + HOLD_CENTRE[1]])
            idv = get_value(u, b"id")
            if idv:
                idv[2] = 2
                idv[3] = struct.pack("<i", nid); nid += 1
        idv = get_value(g, b"id")
        if idv:
            idv[2] = 2
            idv[3] = struct.pack("<i", nid); nid += 1

    # ---- splice in ------------------------------------------------------------------
    for k, g in enumerate(groups):
        entities["entries"].append(["class", ("Item%d" % (before + k)).encode("latin1"), g])
    items_val[2] = 2
    items_val[3] = struct.pack("<i", before + len(groups))
    print("Mission>Entities items: %d -> %d" % (before, before + len(groups)))

    out = serialize(mroot)
    print("sqm size: %d -> %d bytes" % (len(mdata), len(out)))

    # ---- verify by re-reading what we produced ---------------------------------------
    check = Rap(out).build()
    ce = get_class(get_class(check, b"Mission"), b"Entities")
    n_play = 0
    names = []
    for e in ce["entries"]:
        if e[0] != "class":
            continue
        for u in iter_units(e[2]):
            at = get_class(u, b"Attributes")
            if at and get_value(at, b"isPlayable"):
                n_play += 1
                nv = get_value(at, b"name")
                if nv:
                    names.append(nv[3].rstrip(b"\x00").decode("latin1"))
    print("re-parsed output: %d playable units, %d named" % (n_play, len(names)))
    assert n_play == units, "playable count changed on re-read"
    assert "cop_17" in names, "cop_17 slot missing from the tool's own output -- a re-run should never lose it"
    print("cop_17 present (the old SGT+ gate slot name); sample names: %s" % names[:5])

    if write:
        open(MALDEN, "wb").write(out)
        print("WROTE %s" % MALDEN)
    else:
        print("(dry run -- pass --write to apply)")


def iter_units(group):
    """Yield each Object under a Group's own `class Entities`."""
    ge = get_class(group, b"Entities")
    if not ge:
        return
    for e in ge["entries"]:
        if e[0] == "class":
            yield e[2]


if __name__ == "__main__":
    main()
