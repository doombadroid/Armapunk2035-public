#!/usr/bin/env python3
"""Bake faction territory polygons out of Eden markers into the faction_territory table (PostGIS).

    The table is what the game reads (APS_fnc_territoryLoad publishes AP_factionPolys at boot and on
    the bot verb `territoryreload`; fn_factionCfg overlays its polygons). The SQF literal in
    fn_factionCfg.sqf is the FALLBACK for a boot without the table; refresh it with --sqf.
    One-off: --seed-from-cfg copies the literal into the table (2026-09-04).

WHY THIS EXISTS
    A territory is a polygon, and a polygon cannot be an Arma marker -- markers are
    ellipses and rectangles. So the shape has to live in code. But a shape that
    lives in code is a shape nobody can see while placing it, and the owner draws
    the map in 3DEN, not in a text editor with a calculator.

    So: draw the corners as ordinary markers, and let this turn them into the array.

USAGE
    Place a ring of markers in an AP_* layer of MaldenEdit.Malden, named

        aq_terr_<factionId>_p1, aq_terr_<factionId>_p2, ... aq_terr_<factionId>_pN

    where <factionId> is the id from fn_factionCfg.sqf (f_neon, f_dock, f_pharma).
    Order matters -- p1..pN is the order the polygon is wound in, so place them
    around the perimeter, not in the order you happen to think of them. Then:

        python3 tools/bake_territory.py MaldenEdit.Malden/mission.sqm
        python3 tools/bake_territory.py --check <sqm>     # report, change nothing

    Follow the map rules in CLAUDE.md: edit through tools/edit-map.sh, and never
    save the shipped mission.sqm from 3DEN.

WHAT IT REFUSES TO DO
    A partial bake is worse than no bake -- it would leave one faction's border
    redrawn and another's stale, and the disagreement would only surface in play.
    So a faction is rewritten only if its markers are COMPLETE and well formed:
    at least three points, numbered contiguously from 1, with no gaps. A faction
    with no markers at all is left exactly as it is, which is what makes it safe to
    redraw one town at a time.
"""
from __future__ import annotations

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import sqm_read                                                    # noqa: E402
import apdb_dsn                                                    # noqa: E402


def as_wkt(points):
    ring = list(points) + [points[0]]
    return "POLYGON((" + ", ".join("%g %g" % (x, y) for x, y in ring) + "))"


def write_db(polys, check_only=False):
    """Upsert one row per faction. Returns [(fid, npts, changed)]. A polygon PostGIS rejects
    (self-intersecting ring) is refused by the table's CHECK and reported, nothing else changes."""
    out = []
    conn = apdb_dsn.connect()
    try:
        with conn.cursor() as cur:
            for fid, points in sorted(polys.items()):
                cur.execute("SELECT points FROM faction_territory WHERE faction_id = %s", (fid,))
                row = cur.fetchone()
                new = as_sqf(points)
                changed = row is None or row[0] != new
                out.append((fid, len(points), changed))
                if changed and not check_only:
                    cur.execute("INSERT INTO faction_territory (faction_id, points, geom) VALUES (%s, %s, ST_GeomFromText(%s, 0))"
                                " ON CONFLICT (faction_id) DO UPDATE SET points = EXCLUDED.points, geom = EXCLUDED.geom,"
                                " rev = faction_territory.rev + 1, updated_at = now()", (fid, new, as_wkt(points)))
        if check_only:
            conn.rollback()
        else:
            conn.commit()
    finally:
        conn.close()
    return out


def polys_from_cfg(cfg_path):
    """The polygons currently in fn_factionCfg.sqf, by faction id (for --seed-from-cfg)."""
    text = open(cfg_path, encoding="utf-8").read()
    out = {}
    for fid in re.findall(r'^\s*\["(f_[a-z0-9_]+)",', text, re.M):
        at = _find_row(text, fid)
        spans = _row_elements(text, at)
        lit = text[spans[5][0]:spans[5][1]].strip()
        pts = [(float(x), float(y)) for x, y in re.findall(r"\[(-?[\d.]+),(-?[\d.]+)\]", lit)]
        if len(pts) >= 3:
            out[fid] = pts
    return out

MARKER_RE = re.compile(r"^aq_terr_(?P<fid>[A-Za-z0-9_]+?)_p(?P<idx>\d+)$")


def collect(sqm_path):
    """factionId -> {index: (x, y)} for every aq_terr_<id>_pN marker in the file."""
    out = {}
    for node in sqm_read.walk(sqm_read.parse(sqm_path)):
        props = node["props"]
        name = props.get("name")
        if not isinstance(name, str):
            continue
        m = MARKER_RE.match(name)
        if not m:
            continue
        pos = props.get("position")
        if not isinstance(pos, (list, tuple)) or len(pos) < 3:
            print("  ! %s has no usable position; ignored" % name, file=sys.stderr)
            continue
        # Eden stores [x, elevation, y]. The map coordinate pair is 0 and 2 --
        # taking 0 and 1 yields a polygon flattened onto the elevation axis, which
        # is a plausible-looking array of numbers that contains nobody.
        out.setdefault(m.group("fid"), {})[int(m.group("idx"))] = (
            round(float(pos[0]), 1), round(float(pos[2]), 1))
    return out


def as_sqf(points):
    return "[" + ",".join("[%g,%g]" % (x, y) for x, y in points) + "]"


def ordered(pts_by_idx):
    """Contiguous 1..N or None. Returns (points, complaint)."""
    if len(pts_by_idx) < 3:
        return None, "only %d point(s); a polygon needs at least 3" % len(pts_by_idx)
    want = set(range(1, len(pts_by_idx) + 1))
    have = set(pts_by_idx)
    if have != want:
        missing = sorted(want - have)
        extra = sorted(have - want)
        bits = []
        if missing:
            bits.append("missing p%s" % ", p".join(str(i) for i in missing))
        if extra:
            bits.append("out-of-range p%s" % ", p".join(str(i) for i in extra))
        return None, "numbering is not contiguous from 1 (%s)" % "; ".join(bits)
    return [pts_by_idx[i] for i in sorted(pts_by_idx)], None


def _row_elements(text, start):
    """Spans of the top-level elements of the SQF array literal opening at `start`.

    A row is [id, name, marker, fixer, blurb, poly, town] and the polygon is element
    5. Finding it by "the first bracketed thing after the id" is what the first cut
    of this tool did, and it was wrong twice over: `text.find` happily anchors
    inside this file's OWN header comment, and a regex permissive enough to match an
    empty polygon also matches the `[]` in a sentence like "the row, or []". It
    silently rewrote a comment. So the structure is walked instead of matched:
    depth-aware, quote-aware, and anchored at a real row.
    """
    assert text[start] == "["
    spans, depth, i, n = [], 0, start, len(text)
    elem_start = None
    while i < n:
        ch = text[i]
        if ch == '"':                       # SQF escapes a quote by doubling it;
            i += 1                          # either way, skipping to the next quote
            while i < n and text[i] != '"':  # and past it lands correctly.
                i += 1
            i += 1
            continue
        if ch == "[":
            depth += 1
            if depth == 1:
                elem_start = i + 1
            i += 1
            continue
        if ch == "]":
            depth -= 1
            if depth == 0:
                spans.append((elem_start, i))
                return spans
            i += 1
            continue
        if ch == "," and depth == 1:
            spans.append((elem_start, i))
            elem_start = i + 1
        i += 1
    return spans


def _find_row(text, fid):
    """Start offset of the ["<fid>", ...] row inside the _factions literal."""
    block = text.find("private _factions = [")
    if block == -1:
        return -1
    at = text.find('["%s",' % fid, block)
    return at


def rewrite(cfg_path, polys, check_only=False):
    """Replace the _poly element on each faction row. Returns list of changes."""
    with open(cfg_path, encoding="utf-8") as fh:
        text = fh.read()

    changes = []
    for fid, points in sorted(polys.items()):
        at = _find_row(text, fid)
        if at == -1:
            print("  ! %s is not a faction id in %s; skipped"
                  % (fid, os.path.basename(cfg_path)), file=sys.stderr)
            continue
        spans = _row_elements(text, at)
        if len(spans) < 6:
            print("  ! the %s row has %d element(s), expected at least 6; skipped"
                  % (fid, len(spans)), file=sys.stderr)
            continue
        lo, hi = spans[5]
        current = text[lo:hi].strip()
        if not (current == "[]" or current.startswith("[[")):
            print("  ! element 6 of the %s row is %r, which is not a polygon; skipped"
                  % (fid, current[:40]), file=sys.stderr)
            continue
        new = as_sqf(points)
        if current == new:
            continue
        changes.append((fid, len(points)))
        if not check_only:
            text = text[:lo] + text[lo:hi].replace(current, new, 1) + text[hi:]

    if changes and not check_only:
        with open(cfg_path, "w", encoding="utf-8") as fh:
            fh.write(text)
    return changes


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sqm", nargs="?", help="mission.sqm to read the aq_terr_* markers from")
    ap.add_argument("-c", "--cfg", default=os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "mission", "Armapunk2035.Malden", "core", "config", "fn_factionCfg.sqf"))
    ap.add_argument("--check", action="store_true",
                    help="report what would change and exit non-zero if anything would")
    ap.add_argument("--sqf", action="store_true",
                    help="ALSO rewrite the fallback literal in fn_factionCfg.sqf")
    ap.add_argument("--seed-from-cfg", action="store_true",
                    help="one-off: copy the polygons in fn_factionCfg.sqf into the table; sqm is ignored")
    args = ap.parse_args()
    if args.seed_from_cfg:
        polys = polys_from_cfg(args.cfg)
        for fid, n, changed in write_db(polys, check_only=args.check):
            print("  %s: %d point(s) %s" % (fid, n, "written" if changed and not args.check else ("would write" if changed else "unchanged")))
        return 0
    if not args.sqm:
        ap.error("sqm is required unless --seed-from-cfg")

    found = collect(args.sqm)
    if not found:
        print("no aq_terr_<id>_pN markers in %s -- nothing to bake." % args.sqm)
        return 0

    polys, refused = {}, 0
    for fid, pts in sorted(found.items()):
        points, complaint = ordered(pts)
        if complaint:
            print("  ! %s REFUSED: %s" % (fid, complaint), file=sys.stderr)
            refused += 1
            continue
        polys[fid] = points
        print("  %s: %d point(s)" % (fid, len(points)))

    db = write_db(polys, check_only=args.check)
    for fid, n, changed in db:
        print("  table %s: %d point(s) %s" % (fid, n, "written" if changed and not args.check else ("would write" if changed else "unchanged")))
    changes = rewrite(args.cfg, polys, check_only=args.check) if args.sqf else []
    if args.check:
        if changes:
            print("would rewrite: " + ", ".join("%s (%d pts)" % c for c in changes))
        else:
            print("fn_factionCfg.sqf is already up to date with the map.")
        return 1 if (changes or refused) else 0

    if changes:
        print("rewrote %s: %s" % (os.path.basename(args.cfg),
                                  ", ".join("%s (%d pts)" % c for c in changes)))
    else:
        print("no change -- the config already matches the map.")
    return 1 if refused else 0


if __name__ == "__main__":
    sys.exit(main())
