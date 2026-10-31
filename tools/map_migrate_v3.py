#!/usr/bin/env python3
"""map_objects v3 migration (mapdb.md D8). Dry-run by default; --write commits ONE transaction.

  1. applies deploy/map_objects_v3.sql (idempotent)
  2. the frozen custom_p3ds/malden_buildings.sqf placement lines (map_custom_p3d_placements.sqf)
     -> rows (model, scale, on_server, stream_r 0)
  3. detail tiers from the OLD streamer's lists (frozen in map_decor_lists.py): lod 3 for classes
     in both _decorObjects and _shitObjects (never spawned), lod 2 for the rest of _decorObjects
     (a random 20 % of rows spawned)
  4. stream_r 0 for rows the old AP_fnc_mapZoneFor called static: an `_isStatic = true` init,
     or within 110 m of the jail_marker_loonybin marker

Idempotent: refuses if any AP_CUSTOM_P3D row exists. Every parser asserts its count against the
source file's own rule, so a regex that silently stopped matching aborts instead of migrating a
partial set (the map pipeline's own lesson: a placement that does not parse is invisible with
no error).
"""
import argparse
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apdb_dsn   # noqa: E402
import map_decor_lists   # noqa: E402
import sqm_read   # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MIS = os.path.join(ROOT, "mission", "Armapunk2035.Malden")
# The 85 placement lines, frozen from custom_p3ds/malden_buildings.sqf at the commit that deleted
# it (74cb8aea). The migration's INPUT lives with the migration so any database can be stood up.
P3D_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "map_custom_p3d_placements.sqf")
SQM = os.path.join(MIS, "mission.sqm")
SQL = os.path.join(ROOT, "deploy", "map_objects_v3.sql")

# Measured 2026-09-04 against the files this migrates. A different count means the source
# changed under the migration -- stop and look, do not guess.
EXPECT_DECOR = 210
EXPECT_SHIT = 82
JAIL_MARKER = "jail_marker_loonybin"
JAIL_RADIUS = 110.0

_LINE = re.compile(
    r'^\s*_o\s*=\s*createSimpleObject\s*\[\s*_MALDEN\s*\+\s*"([^"]+\.p3d)"\s*,\s*'
    r'\[\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\]\s*,\s*true\s*\]\s*;'
    r'\s*_o\s+setDir\s+(-?[\d.]+)\s*;\s*_o\s+setObjectScale\s+([\d.]+)\s*;')


def parse_placements(src):
    """Every placement line as a dict. Aborts unless the count equals the file's own rule
    (non-comment lines that create a simple object) -- same gate map_codegen.parse_p3d used."""
    want = sum(1 for l in src.splitlines()
               if "createSimpleObject" in l and not l.strip().startswith("//"))
    rows = []
    for l in src.splitlines():
        m = _LINE.match(l)
        if m:
            rows.append({"model": "custom_p3ds\\" + m.group(1), "x": float(m.group(2)),
                         "y": float(m.group(3)), "z": float(m.group(4)),
                         "dir": float(m.group(5)), "scale": float(m.group(6))})
    if len(rows) != want:
        sys.exit("ABORT: %d placements parsed but %d lines create a simple object" % (len(rows), want))
    return rows


def dir_to_vectors(deg):
    """setDir D == setVectorDirAndUp [[sin D, cos D, 0], [0, 0, 1]] for a level object."""
    r = math.radians(deg)
    return (math.sin(r), math.cos(r), 0.0), (0, 0, 1)


def _arr(src, name):
    m = re.search(r'private\s+%s\s*=\s*\[(.*?)\];' % re.escape(name), src, re.S)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []


def decor_lists(src=None):
    """The old streamer's two lists: parsed from SQF source when given one, else the frozen copy."""
    if src is not None:
        return _arr(src, "_decorObjects"), _arr(src, "_shitObjects")
    return list(map_decor_lists.DECOR), list(map_decor_lists.SHIT)


def tier_updates(decor, shit):
    both = [c for c in decor if c in shit]
    return {3: both, 2: [c for c in decor if c not in shit]}


def marker_pos(sqm_path, name):
    """(x, y) of a named marker. Same walk tools/bake_territory.py uses; Eden stores the
    position as [x, elevation, y], so the map pair is indices 0 and 2."""
    for node in sqm_read.walk(sqm_read.parse(sqm_path)):
        props = node["props"]
        if props.get("name") == name and isinstance(props.get("position"), (list, tuple)):
            pos = props["position"]
            return (float(pos[0]), float(pos[2]))
    sys.exit("ABORT: marker %s not found in mission.sqm" % name)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--write", action="store_true", help="commit (default: dry-run, rolled back)")
    ap.add_argument("--world", default="Malden")
    a = ap.parse_args(argv)

    p3d = parse_placements(open(P3D_FILE, encoding="utf-8").read())
    decor, shit = decor_lists()
    if (len(decor), len(shit)) != (EXPECT_DECOR, EXPECT_SHIT):
        sys.exit("ABORT: decor/shit lists are %d/%d, expected %d/%d" % (len(decor), len(shit), EXPECT_DECOR, EXPECT_SHIT))
    tiers = tier_updates(decor, shit)
    jail = marker_pos(SQM, JAIL_MARKER)
    print("placements=%d decor=%d shit=%d jail=%s" % (len(p3d), len(decor), len(shit), jail), file=sys.stderr)

    conn = apdb_dsn.connect()
    try:
        with conn.cursor() as cur:
            cur.execute(open(SQL, encoding="utf-8").read())
            cur.execute("SELECT count(*) FROM map_objects WHERE world=%s AND layer='AP_CUSTOM_P3D'", (a.world,))
            if cur.fetchone()[0]:
                sys.exit("refusing: AP_CUSTOM_P3D rows already exist (migration already ran)")
            for r in p3d:
                d, u = dir_to_vectors(r["dir"])
                cur.execute(
                    "INSERT INTO map_objects (world, classname, model, x, y, z, vdir_x, vdir_y, vdir_z,"
                    " vup_x, vup_y, vup_z, scale, lod, stream_r, on_server, layer, author_uid)"
                    " VALUES (%s, '', %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 0, 0, true, 'AP_CUSTOM_P3D', 'migration')",
                    (a.world, r["model"], r["x"], r["y"], r["z"], d[0], d[1], d[2], u[0], u[1], u[2], r["scale"]))
            print("inserted %d model rows" % len(p3d), file=sys.stderr)
            for tier in (3, 2):
                cur.execute("UPDATE map_objects SET lod=%s WHERE world=%s AND NOT deleted AND classname = ANY(%s)",
                            (tier, a.world, tiers[tier]))
                print("lod=%d: %d rows (%d classes)" % (tier, cur.rowcount, len(tiers[tier])), file=sys.stderr)
            cur.execute("UPDATE map_objects SET stream_r=0 WHERE world=%s AND stream_r IS NULL AND init LIKE %s",
                        (a.world, "%_isStatic = true%"))
            print("static by init tag: %d" % cur.rowcount, file=sys.stderr)
            cur.execute("UPDATE map_objects SET stream_r=0 WHERE world=%s AND stream_r IS NULL"
                        " AND sqrt((x-%s)^2 + (y-%s)^2) <= %s", (a.world, jail[0], jail[1], JAIL_RADIUS))
            print("static by jail radius: %d" % cur.rowcount, file=sys.stderr)
            cur.execute("SELECT count(*), count(*) FILTER (WHERE model<>''), count(*) FILTER (WHERE stream_r=0),"
                        " count(*) FILTER (WHERE lod=2), count(*) FILTER (WHERE lod=3)"
                        " FROM map_objects WHERE world=%s AND NOT deleted", (a.world,))
            print("rows=%d model=%d always=%d lod2=%d lod3=%d" % cur.fetchone(), file=sys.stderr)
        if a.write:
            conn.commit()
            print("COMMITTED", file=sys.stderr)
        else:
            conn.rollback()
            print("dry-run: rolled back (use --write)", file=sys.stderr)
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
