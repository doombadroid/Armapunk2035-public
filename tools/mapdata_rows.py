#!/usr/bin/env python3
"""The one reader/writer of the map snapshot (deploy/map_snapshot/map_objects.sqf).

Rows come from mapdata_migrate.parse_rows, which returns each row's text verbatim
(`raw`) plus its parsed fields. That parser drops what lies BETWEEN rows -- the
separating comma and the owner's inline comments -- and a rewriter that loses those
erodes the comments one run at a time. read() recovers each row's gap by locating its
raw text in the source, in order, so emit() reproduces the file byte-for-byte when
nothing changed. That identity is the test.

Row shapes (mapdb.md D2; indices 0-6 are the v2 row, so every old reader still works):
    v2:  [class, pos, [vdir,vup], init, isServer, loadout, id]
    v3:  [class, pos, [vdir,vup], init, isServer, loadout, id,
          model, scale, lod, streamR (-1 = NULL/default), onServer]
Pre-migration rows have five elements and id None. format_row ALWAYS writes the v3
shape, with exactly the precision AP_fnc_mapRowText uses (positions %.3f, vectors %.4f,
scale %.3f, streamR %.1f) so the Python and SQF serialisers agree byte for byte.
"""
import collections
import re

import mapdata_migrate

# shape = element count of the row as READ (5 pre-migration, 7 v2, 12 v3); a Row built by
# hand defaults to the current shape.
Row = collections.namedtuple(
    "Row", "cls pos vdir vup init is_server loadout id raw gap model scale lod stream_r on_server shape",
    defaults=("", 1.0, 1, None, False, 12))
Doc = collections.namedtuple("Doc", "header rows trailer baked_rev")

_VEC = re.compile(r"\[\[([-\d.eE,]+)\],\[([-\d.eE,]+)\]\]$")
# baked_rev is the header's rev whatever the header calls it: AP_mapBakedRev was the v2
# name inside the mission PBO, AP_mapSnapshotRev is the v3 snapshot outside it.
_REV = re.compile(r"AP_map(?:Snapshot|Baked)Rev\s*=\s*(\d+)\s*;")


def _split_top(text):
    """Split an SQF element list at depth-0 commas. Strings ("" escapes a quote) and
    nested arrays are opaque, so a loadout array or a quoted model path never splits."""
    parts, depth, i, start, n = [], 0, 0, 0, len(text)
    while i < n:
        ch = text[i]
        if ch == '"':
            i += 1
            while i < n:
                if text[i] == '"':
                    if i + 1 < n and text[i + 1] == '"':
                        i += 2
                        continue
                    break
                i += 1
        elif ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
        elif ch == "," and depth == 0:
            parts.append(text[start:i])
            start = i + 1
        i += 1
    parts.append(text[start:])
    return parts


def _unquote(s):
    if len(s) < 2 or s[0] != '"' or s[-1] != '"':
        raise ValueError("not an SQF string: %s" % s[:60])
    return s[1:-1].replace('""', '"')


def _parse_tail(tail):
    """',<loadout>,<id>[,<model>,<scale>,<lod>,<streamR>,<onServer>]' ->
    (loadout_text, id, model, scale, lod, stream_r, on_server, shape). '' -> the v2 defaults."""
    if not tail:
        return "", None, "", 1.0, 1, None, False, 5
    parts = _split_top(tail[1:] if tail.startswith(",") else tail)
    if len(parts) == 2:
        return parts[0], int(parts[1]), "", 1.0, 1, None, False, 7
    if len(parts) == 7:
        lo, rid, model, scale, lod, sr, os_ = parts
        srf = float(sr)
        return (lo, int(rid), _unquote(model), float(scale), int(lod),
                None if srf < 0 else srf, os_.strip() == "true", 12)
    raise ValueError("row tail has %d elements, expected 2 (v2) or 7 (v3): %s" % (len(parts), tail[:100]))


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        src = fh.read()
    rows = mapdata_migrate.parse_rows(src)
    k = src.index("allLocalMapEntities")
    header = src[:k]
    pos = src.index("[", k) + 1
    out = []
    for r in rows:
        at = src.index(r["raw"], pos)
        gap = src[pos:at]
        pos = at + len(r["raw"])
        m = _VEC.match(r["vec"])
        if not m:
            raise ValueError("row has a scalar direction, not vectors: %s" % r["raw"][:100])
        vdir = tuple(float(v) for v in m.group(1).split(","))
        vup = tuple(float(v) for v in m.group(2).split(","))
        loadout, rid, model, scale, lod, stream_r, on_server, shape = _parse_tail(r["tail"])
        out.append(Row(r["cls"], r["pos"], vdir, vup, r["init"], r["server"] == "true",
                       loadout, rid, r["raw"], gap, model, scale, lod, stream_r, on_server, shape))
    trailer = src[pos:]
    rm = _REV.search(header)
    return Doc(header, out, trailer, int(rm.group(1)) if rm else 0)


def emit(header, pieces, trailer):
    body = []
    for i, (gap, text) in enumerate(pieces):
        if i == 0:
            # The first surviving row must not open with the comma that separated it
            # from a row that no longer exists -- nor with the whitespace that comma
            # dragged along. A comment in that gap survives; it just moves up.
            gap = re.sub(r"^\s*,\s*", "", gap, count=1)
        body.append(gap + text)
    return header + "allLocalMapEntities=[" + "".join(body) + trailer


def format_row(cls, pos, vdir, vup, init, is_server, loadout, rid,
               model="", scale=1.0, lod=1, stream_r=None, on_server=False):
    """The v3 row text, byte-identical to AP_fnc_mapRowText for the same values.
    stream_r None (SQL NULL) is written as -1.0, the wire sentinel for "default"."""
    return ('["%s",[%.3f,%.3f,%.3f],[[%.4f,%.4f,%.4f],[%.4f,%.4f,%.4f]],"%s",%s,%s,%d,"%s",%.3f,%d,%.1f,%s]'
            % (cls.replace('"', '""'), pos[0], pos[1], pos[2],
               vdir[0], vdir[1], vdir[2], vup[0], vup[1], vup[2],
               init.replace('"', '""'), "true" if is_server else "false", loadout or "[]", rid,
               model.replace('"', '""'), scale, int(lod),
               -1.0 if stream_r is None else float(stream_r), "true" if on_server else "false"))


def splice_id(raw, rid):
    """Append ',[],<id>' to a five-element row. Refuses a row that already carries one."""
    if not raw.endswith("]"):
        raise ValueError("not a row: %s" % raw[:60])
    if re.search(r",(true|false),.*\]$", raw):
        raise ValueError("row already has a tail: %s" % raw[:60])
    return raw[:-1] + ",[],%d]" % rid
