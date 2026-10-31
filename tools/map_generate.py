#!/usr/bin/env python3
"""Generate deploy/map_snapshot/map_objects.sqf from map_objects.

The table owns the rows (mapdb.md D7); this file is a committed SNAPSHOT of it, kept OUTSIDE
the mission so git keeps showing every map change as a diff without a byte of it shipping in
the PBO. Rows the table has not touched since the file was last generated are emitted
VERBATIM, comments and all -- a generated file from an unchanged table is byte-identical to
the last one. Nothing at runtime reads this file; the server loads the table at boot.

    ~/pysqf-venv/bin/python tools/map_generate.py --dry-run          # stats only
    ~/pysqf-venv/bin/python tools/map_generate.py --write            # (re)write the snapshot

Every row is written in the 12-element v3 shape (mapdata_rows.format_row). A missing file
is generated from scratch. There is no purge here any more: APS_fnc_mapLoad drops tombstones
older than 7 days at boot.
"""
import argparse
import os
import sys

import apdb_dsn
import mapdata_rows as mr

SNAPSHOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "deploy",
                        "map_snapshot", "map_objects.sqf")
HEADER = "AP_mapSnapshotRev = %d;\n"
EMPTY = mr.Doc("", [], "];\n", 0)


def _fmt(rid, d):
    return mr.format_row(d["classname"], (d["x"], d["y"], d["z"]), d["vdir"], d["vup"],
                         d["init"], d["is_server"], d["loadout"], rid,
                         d["model"], d["scale"], d["lod"], d["stream_r"], d["on_server"])


def plan(doc, db_rows, new_rev):
    pieces, st = [], {"kept": 0, "changed": 0, "dropped": 0, "added": 0}
    seen = set()
    for r in doc.rows:
        d = db_rows.get(r.id)
        if d is None or d["deleted"]:
            st["dropped"] += 1
            continue
        seen.add(r.id)
        # verbatim only for an untouched row that is ALREADY in the v3 shape: a v2 row is
        # rewritten once so the whole file is one shape (mapdb.md D7)
        if d["rev"] <= doc.baked_rev and r.shape == 12:
            pieces.append((r.gap, r.raw)); st["kept"] += 1
        else:
            pieces.append((r.gap, _fmt(r.id, d))); st["changed"] += 1
    for rid in sorted(db_rows):
        d = db_rows[rid]
        if rid in seen or d["deleted"]:
            continue
        pieces.append((",\n", _fmt(rid, d))); st["added"] += 1
    return pieces, st


def fetch(conn, world):
    with conn.cursor() as cur:
        cur.execute("SELECT rev FROM map_meta WHERE world = %s", (world,))
        (rev,) = cur.fetchone()
        # Both COALESCEs are aliased: two result columns named "coalesce" are refused by the
        # SQF bridge, and the same statement shape feeds APS_fnc_mapLoad.
        cur.execute("SELECT id, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z,"
                    " init, is_server, COALESCE(loadout,'') AS loadout, deleted, rev,"
                    " model, scale, lod, COALESCE(stream_r,-1) AS stream_r, on_server"
                    " FROM map_objects WHERE world = %s", (world,))
        rows = {}
        for (i, c, x, y, z, dx, dy, dz, ux, uy, uz, init, srv, lo, dele, rrev,
             model, scale, lod, sr, os_) in cur.fetchall():
            rows[i] = {"classname": c, "x": float(x), "y": float(y), "z": float(z),
                       "vdir": (float(dx), float(dy), float(dz)), "vup": (float(ux), float(uy), float(uz)),
                       "init": init, "is_server": bool(srv), "loadout": lo, "deleted": bool(dele), "rev": int(rrev),
                       "model": model, "scale": float(scale), "lod": int(lod),
                       "stream_r": None if float(sr) < 0 else float(sr), "on_server": bool(os_)}
    return rev, rows


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--world", default="Malden")
    args = ap.parse_args(argv)

    doc = mr.read(SNAPSHOT) if os.path.exists(SNAPSHOT) else EMPTY
    conn = apdb_dsn.connect()
    try:
        new_rev, db_rows = fetch(conn, args.world)
    finally:
        conn.close()
    pieces, st = plan(doc, db_rows, new_rev)
    out = mr.emit(HEADER % new_rev, pieces, doc.trailer)
    print("snapshot_rev %d -> %d | %s | %d rows | %d chars"
          % (doc.baked_rev, new_rev, st, len(pieces), len(out)), file=sys.stderr)
    if args.dry_run or not args.write:
        return 0
    os.makedirs(os.path.dirname(SNAPSHOT), exist_ok=True)
    with open(SNAPSHOT, "w", encoding="utf-8") as fh:
        fh.write(out)
    print("written %s" % os.path.relpath(SNAPSHOT), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
