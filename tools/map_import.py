#!/usr/bin/env python3
"""ONE-TIME: import fn_mapData.sqf into map_objects, ids assigned by array order.

Follows mapdata_migrate.py's discipline: rows go in array order, the table must be
empty so the serial hands back exactly 1..N, and any deviation aborts. Nothing here
guesses, resyncs or skips -- a single silent shift moves thousands of objects.

    ~/pysqf-venv/bin/python tools/map_import.py --dry-run     # count only
    ~/pysqf-venv/bin/python tools/map_import.py               # import

After this, run tools/map_generate.py --migrate --write to put the ids into the file.
"""
import argparse
import os
import sys

import apdb_dsn
import mapdata_rows as mr

MAPDATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mission",
                       "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")

COLS = ("world, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, "
        "init, is_server, loadout, layer, author_uid")


def rows_to_params(rows, world):
    out = []
    for r in rows:
        if r.id is not None:
            raise ValueError("row already carries id %d -- this file has been migrated" % r.id)
        out.append((world, r.cls, r.pos[0], r.pos[1], r.pos[2],
                    r.vdir[0], r.vdir[1], r.vdir[2], r.vup[0], r.vup[1], r.vup[2],
                    r.init, r.is_server, r.loadout or None, "AP_MAPDATA", "migration"))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--world", default="Malden")
    args = ap.parse_args(argv)

    doc = mr.read(MAPDATA)
    params = rows_to_params(doc.rows, args.world)
    print("rows to import: %d" % len(params))
    if args.dry_run:
        return 0

    conn = apdb_dsn.connect()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM map_objects WHERE world = %s", (args.world,))
            (n,) = cur.fetchone()
            if n:
                sys.exit("refusing: map_objects already holds %d rows for %s. Ids are assigned "
                         "by insertion order and must come out 1..N; this is a one-time import "
                         "into an EMPTY table." % (n, args.world))
            # An empty table does not mean a fresh sequence: any probe row ever inserted and
            # deleted has advanced it, and the ids then come back 3..N+2 and the run aborts.
            # The table is empty (just checked), so restarting the sequence is safe.
            cur.execute("ALTER SEQUENCE map_objects_id_seq RESTART WITH 1")
            ids = []
            for p in params:
                cur.execute("INSERT INTO map_objects (%s) VALUES (%s) RETURNING id"
                            % (COLS, ",".join(["%s"] * 16)), p)
                ids.append(cur.fetchone()[0])
            if ids != list(range(1, len(params) + 1)):
                conn.rollback()
                sys.exit("refusing: ids came back %s..%s, not 1..%d. Rolled back."
                         % (ids[:1], ids[-1:], len(params)))
            cur.execute("SELECT rev FROM map_meta WHERE world = %s", (args.world,))
            (rev,) = cur.fetchone()
        conn.commit()
        print("imported %d rows, ids 1..%d, map_meta.rev = %d" % (len(ids), len(ids), rev))
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
