#!/usr/bin/env python3
"""Revert a pavement z-fix from its before-file: tools/zfix_revert.py deploy/zfix_pavement_before.json

Writes every saved row's z, vdir and vup back by id (transform columns only -- init is never
touched, exactly like the fix). The running server broadcasts the revert within a poll tick.
"""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apdb_dsn
b = json.load(open(sys.argv[1]))
rows = b.get("rows", []) + b.get("sweep", []) + b.get("sweep2", [])
c = apdb_dsn.connect(); cur = c.cursor(); n = 0
for r in rows:
    cur.execute("UPDATE map_objects SET z=%s, vdir_x=%s, vdir_y=%s, vdir_z=%s, vup_x=%s, vup_y=%s, vup_z=%s, author_uid='zfix-revert' WHERE id=%s",
                (r["z"], *r["vdir"], *r["vup"], r["id"])); n += cur.rowcount
c.commit(); c.close(); print("reverted %d rows" % n)
