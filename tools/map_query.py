#!/usr/bin/env python3
"""Ask the map table spatial questions (PostGIS, deploy/postgis.sql). Read-only.

    map_query.py near X Y R            rows within R m of (X,Y), nearest first
    map_query.py bbox X1 Y1 X2 Y2      rows inside the box
    map_query.py cell KEY              rows in a streamer cell ("7_10", "far"), via map_cell_key()
    map_query.py cells                 row count per cell, largest first
    map_query.py territories           rows inside each fixer polygon (ST_Contains)
    map_query.py nearest X Y [N]       the N nearest rows to (X,Y)

Every command prints: id  class-or-model  x  y  z  lod  stream_r  [distance].
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apdb_dsn  # noqa: E402

COLS = "id, COALESCE(NULLIF(model,''), classname) AS what, x, y, z, lod, stream_r"


def _print(rows, dist=False):
    for r in rows:
        line = "%6d  %-40s %9.3f %9.3f %8.3f  lod=%d r=%s" % (r[0], r[1][:40], r[2], r[3], r[4], r[5], "-" if r[6] is None else "%g" % r[6])
        if dist:
            line += "  d=%.1f" % r[7]
        print(line)
    print("-- %d row(s)" % len(rows), file=sys.stderr)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["near", "bbox", "cell", "cells", "territories", "nearest"])
    ap.add_argument("args", nargs="*")
    ap.add_argument("--world", default="Malden")
    a = ap.parse_args(argv)
    conn = apdb_dsn.connect()
    try:
        cur = conn.cursor()
        live = "world = %s AND NOT deleted"
        if a.cmd == "near":
            x, y, r = map(float, a.args[:3])
            cur.execute(f"SELECT {COLS}, ST_Distance(geom, ST_MakePoint(%s,%s)) AS d FROM map_objects WHERE {live}"
                        " AND ST_DWithin(geom, ST_MakePoint(%s,%s), %s) ORDER BY d", (x, y, a.world, x, y, r))
            _print(cur.fetchall(), dist=True)
        elif a.cmd == "bbox":
            x1, y1, x2, y2 = map(float, a.args[:4])
            cur.execute(f"SELECT {COLS} FROM map_objects WHERE {live} AND geom && ST_MakeEnvelope(%s,%s,%s,%s,0) ORDER BY id",
                        (a.world, x1, y1, x2, y2))
            _print(cur.fetchall())
        elif a.cmd == "cell":
            cur.execute(f"SELECT {COLS} FROM map_objects WHERE {live} AND map_cell_key(x, y, stream_r) = %s ORDER BY id", (a.world, a.args[0]))
            _print(cur.fetchall())
        elif a.cmd == "cells":
            cur.execute(f"SELECT map_cell_key(x, y, stream_r) AS k, count(*) FROM map_objects WHERE {live} GROUP BY k ORDER BY 2 DESC", (a.world,))
            for k, n in cur.fetchall():
                print("%-8s %5d" % (k, n))
        elif a.cmd == "territories":
            cur.execute(f"SELECT t.faction_id, ST_Area(t.geom) / 1e6 AS km2, count(o.id) FROM faction_territory t"
                        f" LEFT JOIN map_objects o ON o.{live} AND ST_Contains(t.geom, o.geom) GROUP BY t.faction_id, t.geom ORDER BY 1", (a.world,))
            for fid, km2, n in cur.fetchall():
                print("%-10s %6.2f km2  %5d row(s)" % (fid, km2, n))
        elif a.cmd == "nearest":
            x, y = map(float, a.args[:2]); n = int(a.args[2]) if len(a.args) > 2 else 5
            cur.execute(f"SELECT {COLS}, ST_Distance(geom, ST_MakePoint(%s,%s)) AS d FROM map_objects WHERE {live}"
                        " ORDER BY geom <-> ST_MakePoint(%s,%s) LIMIT %s", (x, y, a.world, x, y, n))
            _print(cur.fetchall(), dist=True)
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
