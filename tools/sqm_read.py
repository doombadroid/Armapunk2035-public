#!/usr/bin/env python3
"""Minimal reader for a mission.sqm -- enough to walk its entity tree. Handles BOTH forms.

Three tools had each grown their own copy of these sixty lines. This is the shared one, and eleven
tools now go through it, so it is the single place that has to know about the file format.

    parse(path)      -> root node   {"props": {...}, "subs": {name: node}}
    walk(node)       -> yields every node depth-first
    entity_ids(path) -> sorted list of every Eden id in the file

Eden ids are the useful part: get3DENEntityID returns the same number in the editor, and the BIKI
guarantees it survives save/load -- so the set of ids in the .sqm IS the set of entities the mission
ships with, and anything in the editor outside that set was placed this session.

TWO FORMATS, auto-detected by the magic bytes (owner 2026-07-30). The engine loads either, and 3DEN
binarizes on save only when its "Save scenario in binarized form" preference is on. Binarized is
smaller; PLAIN TEXT is diffable, which matters more here -- this repo has twice been bitten by silent
.sqm damage (the Eden re-bake that added 15,642 objects, and the class+XY join that duplicated 838
rows and lost 835), and both would have been obvious in a text diff instead of invisible inside a
binary blob. Callers should not care which form they are handed; that is the point of this module.
"""
import re
import struct


def parse(path):
    data = open(path, "rb").read()
    if data[:4] != b"\x00raP":
        return _parse_text(data.decode("utf-8", "replace"), path)

    def asciiz(i):
        j = data.index(b"\x00", i)
        return data[i:j].decode("latin1"), j + 1

    def comp(i):                                   # 7-bit compressed integer
        v = s = 0
        while True:
            b = data[i]
            i += 1
            v |= (b & 0x7f) << s
            if not (b & 0x80):
                break
            s += 7
        return v, i

    def value(sub, i):
        if sub == 0:
            return asciiz(i)
        if sub == 1:
            return struct.unpack_from("<f", data, i)[0], i + 4
        if sub == 2:
            return struct.unpack_from("<i", data, i)[0], i + 4
        return None, i

    def array(i):
        n, i = comp(i)
        out = []
        for _ in range(n):
            t = data[i]
            i += 1
            if t == 3:
                a, i = array(i)
                out.append(a)
            else:
                v, i = value(t, i)
                out.append(v)
        return out, i

    def parse_class(i):
        _inherited, i = asciiz(i)
        n, i = comp(i)
        props, subs = {}, []
        for _ in range(n):
            t = data[i]
            i += 1
            if t == 0:                             # embedded class: name + uint32 body offset
                nm, i = asciiz(i)
                off = struct.unpack_from("<I", data, i)[0]
                i += 4
                subs.append((nm, off))
            elif t == 1:                           # value
                sub = data[i]
                i += 1
                nm, i = asciiz(i)
                v, i = value(sub, i)
                props[nm] = v
            elif t == 2:                           # array
                nm, i = asciiz(i)
                v, i = array(i)
                props[nm] = v
            elif t in (3, 4):                      # extern / delete: name only
                nm, i = asciiz(i)
            elif t == 5:                           # array with flags
                nm, i = asciiz(i)
                i += 4
                v, i = array(i)
                props[nm] = v
            else:
                break
        return props, subs

    def node(off):
        props, subs = parse_class(off)
        return {"props": props, "subs": {nm: node(o) for nm, o in subs}}

    return node(16)


# Named groups throughout: positional numbering here is easy to get silently wrong, and a
# mis-indexed group would misname classes rather than fail loudly.
_TOK = re.compile(r"""
      \bclass\s+(?P<cname>[A-Za-z_]\w*)\s*(?::\s*[A-Za-z_]\w*\s*)?(?P<copen>\{)
    | (?P<close>\})
    | (?P<aname>[A-Za-z_]\w*)\s*\[\s*\]\s*=\s*
    | (?P<vname>[A-Za-z_]\w*)\s*=\s*
""", re.X)

# A config string cannot hold a literal newline, so a multi-line value is written as quoted
# segments joined by an UNQUOTED ` \n `:   init="a;" \n "b;" \n "c;";
# Reading only the first segment loses the rest SILENTLY -- the surrounding class still parses,
# so nothing looks wrong, and an NPC init that spans two lines comes back with one of them gone.
_CONT = re.compile(r'\s*\\n\s*"')


def _parse_text(text, path="<text>"):
    """Parse the plain-text config form. Same node shape as the binarized reader.

    Deliberately not a general config parser: it handles what a .sqm actually contains -- nested
    classes, scalar properties, and array properties (including nested arrays like position vectors).
    Strings keep their quotes stripped and doubled "" unescaped, matching the binarized reader, so a
    caller cannot tell the two apart.
    """
    # strip comments, but never inside a string literal
    text = re.sub(r'"(?:[^"]|"")*"|//[^\n]*|/\*.*?\*/',
                  lambda m: m.group(0) if m.group(0).startswith('"') else " ", text, flags=re.S)

    def read_value(i):
        while i < len(text) and text[i] in " \t\r\n":
            i += 1
        if i < len(text) and text[i] == '"':
            segs = []
            while True:
                out = []
                i += 1
                while i < len(text):
                    if text[i] == '"':
                        if i + 1 < len(text) and text[i + 1] == '"':
                            out.append('"')
                            i += 2
                            continue
                        i += 1
                        break
                    out.append(text[i])
                    i += 1
                segs.append("".join(out))
                cont = _CONT.match(text, i)      # ` \n "` -> another segment of the same value
                if not cont:
                    break
                i = cont.end() - 1               # leave i on the opening quote
            return "\n".join(segs), i
        j = i
        while j < len(text) and text[j] not in ",;}":
            j += 1
        raw = text[i:j].strip()
        if re.fullmatch(r"-?\d+", raw):
            return int(raw), j
        try:
            return float(raw), j
        except ValueError:
            return raw, j

    def read_array(i):
        while i < len(text) and text[i] in " \t\r\n":
            i += 1
        assert text[i] == "{", "%s: array does not start with { at %d" % (path, i)
        i += 1
        out = []
        while True:
            while i < len(text) and text[i] in " \t\r\n,":
                i += 1
            if i >= len(text) or text[i] == "}":
                return out, i + 1
            if text[i] == "{":
                v, i = read_array(i)
            else:
                v, i = read_value(i)
            out.append(v)

    def read_body(i):
        props, subs = {}, {}
        while i < len(text):
            m = _TOK.search(text, i)
            if not m:
                return props, subs, len(text)
            if m.group("close") is not None:
                return props, subs, m.end()
            if m.group("cname") is not None:
                p, s, i = read_body(m.end())
                subs[m.group("cname")] = {"props": p, "subs": s}
                continue
            if m.group("aname") is not None:
                v, i = read_array(m.end())
                props[m.group("aname")] = v
                continue
            v, i = read_value(m.end())
            props[m.group("vname")] = v
        return props, subs, i

    props, subs, _ = read_body(0)
    return {"props": props, "subs": subs}


def walk(n):
    yield n
    for c in n["subs"].values():
        yield from walk(c)


def entity_ids(path):
    """Every Eden id in the mission -- objects, groups, logics, markers, the lot."""
    out = set()
    for n in walk(parse(path)):
        i = n["props"].get("id")
        if isinstance(i, int):
            out.add(i)
    return sorted(out)


if __name__ == "__main__":
    import collections
    import sys
    root = parse(sys.argv[1])
    kinds = collections.Counter(n["props"].get("dataType") for n in walk(root))
    print("%s: %d ids, %s" % (sys.argv[1], len(entity_ids(sys.argv[1])),
                              {k: v for k, v in kinds.items() if k}))
