#!/usr/bin/env python3
"""map_push -- Eden edits into map_objects, by id. Both layers.

Second authoring surface. The in-game editor is the first; both write the same table
and the running server broadcasts either within seconds (mapdb.md D7).

Every entity staged into MaldenEdit carries AP_ID=<id> in its description (the field
3DEN preserves verbatim) -- class rows in AP_MAPDATA and custom-model anchors alike. The
diff is therefore EXACT:
    staged id, transform / init / scale changed  -> UPDATE
    entity with no AP_ID                          -> INSERT (a new placement)
    id that was staged and is now absent          -> soft DELETE
An id that was never staged into this edit mission is never touched.

Custom buildings are ANCHORS (Land_HelipadEmpty_F) whose description names the model:
AP_P3D=<Model>|AP_SCALE=<s>. They are matched by that token wherever they sit in the
file, not by layer -- 3DEN drops a placed Custom Composition into a layer of its own, so a
layer-scoped read would silently ignore every building added the easy way. A new anchor
becomes a model row: classname '', model custom_p3ds\\<Model>.p3d, on_server true (the
server needs its collision), stream_r 0 (always loaded), lod 0.

Two optional description tokens work on ANY entity and set the v3 columns:
    AP_LOD=<0-3>       detail tier (0 always, 1 normal, 2 decor, 3 never by default)
    AP_R=<metres>      stream-in radius, 0 = always loaded
A token that does not validate is ignored with a warning; the row's other changes still
land. A token that is absent leaves the column alone.

This tool runs on the box with database access and is a TRUSTED writer: it may write
init. The in-game path may not.
"""
import argparse
import math
import os
import sys

import apdb_dsn
import map_codegen

EPS = 0.0005   # a millimetre; the wire stores three decimals
P3D_DEFAULTS = {"on_server": True, "stream_r": 0.0, "lod": 0, "layer": map_codegen.LAYER_P3D}


def _close(a, b):
    return all(abs(x - y) < EPS for x, y in zip(a, b))


def desc_flags(desc):
    """(lod, stream_r, warnings) from the AP_LOD= / AP_R= tokens of a description.
    None = the token is absent or invalid (invalid ones are reported in warnings)."""
    lod = stream_r = None
    warns = []
    for t in map_codegen._tokens(desc or ""):
        if t.startswith("AP_LOD="):
            v = t[len("AP_LOD="):].strip()
            if v.isdigit() and 0 <= int(v) <= 3:
                lod = int(v)
            else:
                warns.append("ignoring %s: the detail tier is an integer 0-3" % t)
        elif t.startswith("AP_R="):
            v = t[len("AP_R="):].strip()
            try:
                f = float(v)
            except ValueError:
                f = float("nan")
            if math.isfinite(f) and f >= 0:
                stream_r = f
            else:
                warns.append("ignoring %s: the radius is a number of metres >= 0" % t)
    return lod, stream_r, warns


def anchor_model(e):
    """(model path, scale) for a custom-building anchor, from its AP_P3D= / AP_SCALE= tokens.
    None when the description names no model; a ValueError names a scale that is not a number."""
    toks = map_codegen._tokens(e.get("desc", ""))
    model = next((t[len("AP_P3D="):].strip() for t in toks if t.startswith("AP_P3D=")), None)
    if not model:
        return None
    scale_s = next((t[len("AP_SCALE="):].strip() for t in toks if t.startswith("AP_SCALE=")), "1")
    try:
        scale = float(scale_s)
    except ValueError:
        raise ValueError("AP_SCALE=%s is not a number" % scale_s)
    if not (math.isfinite(scale) and scale > 0):
        raise ValueError("AP_SCALE=%s is not a positive scale" % scale_s)
    return map_codegen.model_path(model), scale


def prepare(class_ents, anchors):
    """Annotate entities for diff(): anchors gain model/scale, every entity gains lod/stream_r
    (None = leave the column alone). Returns (entities, warnings); an anchor whose scale does
    not parse is dropped with a warning rather than written as something else."""
    out, warns = [], []
    for e in class_ents:
        e = dict(e)
        e["lod"], e["stream_r"], w = desc_flags(e.get("desc", ""))
        warns += w
        out.append(e)
    for e in anchors:
        e = dict(e)
        try:
            ms = anchor_model(e)
        except ValueError as err:
            warns.append("skipping anchor at %.1f, %.1f: %s" % (e["world"][0], e["world"][1], err))
            continue
        if ms is None:
            continue
        e["model"], e["scale"] = ms
        e["lod"], e["stream_r"], w = desc_flags(e.get("desc", ""))
        warns += w
        out.append(e)
    return out, warns


def _flag_changed(e, t):
    if e.get("lod") is not None and e["lod"] != t.get("lod"):
        return True
    sr = e.get("stream_r")
    if sr is not None and (t.get("stream_r") is None or abs(sr - t["stream_r"]) > 0.01):
        return True
    return False


def diff(staged_ids, table, target):
    ops = {"update": [], "insert": [], "delete": []}
    seen = set()
    for e in target:
        rid = e.get("ap_id")
        if rid is None:
            ops["insert"].append(e)
            continue
        seen.add(rid)
        t = table.get(rid)
        if t is None or t["deleted"]:
            ops["insert"].append(e)   # purged or deleted under it; re-create
            continue
        if e.get("model"):
            changed = (e["model"] != t.get("model", "") or abs(e["scale"] - t.get("scale", 1.0)) > 1e-3
                       or not _close(e["world"], (t["x"], t["y"], t["z"]))
                       or not _close(e["dir"], t["vdir"]) or not _close(e["up"], t["vup"]))
        else:
            changed = (e["cls"] != t["classname"] or e.get("init", "") != t["init"]
                       or not _close(e["world"], (t["x"], t["y"], t["z"]))
                       or not _close(e["dir"], t["vdir"]) or not _close(e["up"], t["vup"]))
        if changed or _flag_changed(e, t):
            ops["update"].append((rid, e))
    for rid in sorted(staged_ids - seen):
        if rid in table and not table[rid]["deleted"]:
            ops["delete"].append(rid)
    return ops


def read_table(conn, world):
    with conn.cursor() as cur:
        cur.execute("SELECT id, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, init, deleted,"
                    " model, scale, lod, stream_r"
                    " FROM map_objects WHERE world = %s", (world,))
        return {i: {"classname": c, "x": float(x), "y": float(y), "z": float(z),
                    "vdir": (float(dx), float(dy), float(dz)), "vup": (float(ux), float(uy), float(uz)),
                    "init": init, "deleted": bool(d),
                    "model": model, "scale": float(scale), "lod": int(lod),
                    "stream_r": None if sr is None else float(sr)}
                for (i, c, x, y, z, dx, dy, dz, ux, uy, uz, init, d, model, scale, lod, sr) in cur.fetchall()}


def _transform_cols(e):
    return {"x": e["world"][0], "y": e["world"][1], "z": e["world"][2],
            "vdir_x": e["dir"][0], "vdir_y": e["dir"][1], "vdir_z": e["dir"][2],
            "vup_x": e["up"][0], "vup_y": e["up"][1], "vup_z": e["up"][2]}


def _flag_cols(e):
    cols = {}
    if e.get("lod") is not None:
        cols["lod"] = e["lod"]
    if e.get("stream_r") is not None:
        cols["stream_r"] = e["stream_r"]
    return cols


def sql_ops(world, ops, author):
    """The statements apply_ops runs, as [(sql, params)] -- pure, so every branch is testable.
    rev is never supplied: the map_objects_stamp trigger sets it on every INSERT/UPDATE."""
    out = []
    for rid, e in ops["update"]:
        cols = _transform_cols(e)
        if e.get("model"):
            cols.update({"model": e["model"], "scale": e["scale"]})
        else:
            cols.update({"classname": e["cls"], "init": e.get("init", "")})
        cols.update(_flag_cols(e))
        cols["author_uid"] = author
        out.append(("UPDATE map_objects SET %s WHERE id=%%s AND world=%%s" % ", ".join("%s=%%s" % k for k in cols),
                    tuple(cols.values()) + (rid, world)))
    for e in ops["insert"]:
        cols = {"world": world}
        if e.get("model"):
            cols.update({"classname": "", "model": e["model"], "scale": e["scale"]})
            cols.update(_transform_cols(e))
            cols.update(P3D_DEFAULTS)
            cols.update(_flag_cols(e))          # a token on a new anchor overrides the p3d defaults
        else:
            cols.update({"classname": e["cls"]})
            cols.update(_transform_cols(e))
            cols["init"] = e.get("init", "")
            cols.update(_flag_cols(e))          # absent -> the column defaults (lod 1, stream_r NULL)
        cols["author_uid"] = author
        out.append(("INSERT INTO map_objects (%s) VALUES (%s)" % (", ".join(cols), ", ".join(["%s"] * len(cols))),
                    tuple(cols.values())))
    for rid in ops["delete"]:
        out.append(("UPDATE map_objects SET deleted=true, author_uid=%s WHERE id=%s AND world=%s", (author, rid, world)))
    return out


def apply_ops(conn, world, ops, author):
    with conn.cursor() as cur:
        for sql, params in sql_ops(world, ops, author):
            cur.execute(sql, params)
    conn.commit()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--world", default="Malden")
    ap.add_argument("--author", default="map_push")
    ap.add_argument("--force", action="store_true", help="push even though the table has changed since staging")
    args = ap.parse_args(argv)

    edit_sqm = os.path.join(map_codegen.EDIT_DIR, "mission.sqm")
    if not os.path.exists(edit_sqm):
        sys.exit("no edit mission at %s -- stage it first with tools/edit-map.sh" % edit_sqm)
    class_ents = map_codegen.read_layer(edit_sqm, map_codegen.LAYER_MAPDATA)
    anchors = map_codegen.read_p3d_anchors(edit_sqm)
    if not class_ents:
        sys.exit("ABORT: layer %s is empty or missing -- refusing to soft-delete the map" % map_codegen.LAYER_MAPDATA)
    target, warns = prepare(class_ents, anchors)
    for w in warns:
        print("WARNING: " + w, file=sys.stderr)
    staged = map_codegen.read_staged_ids()

    conn = apdb_dsn.connect()
    try:
        # STALENESS GUARD -- a refusal, not a warning. The edit mission is a snapshot of the
        # table it was staged from. Any row the table has touched since (an in-game move, a
        # delete, another push) is unknown to it, and pushing would write the snapshot back
        # over that edit. This happened on 2026-09-01: a push from a staging made before the
        # owner's first in-game edits reverted his move and re-created his delete.
        staged_rev = map_codegen.read_staged_rev()
        with conn.cursor() as cur:
            cur.execute("SELECT count(*), COALESCE(max(rev),0) FROM map_objects WHERE world = %s AND rev > %s",
                        (args.world, staged_rev))
            (newer, top) = cur.fetchone()
        if staged_rev < 0 or newer:
            msg = ("refusing: the table has %d row(s) newer than this staging (staged_from_rev=%d, table rev=%d).\n"
                   "A push would write the stale snapshot over them. Re-stage first:\n"
                   "    tools/edit-map.sh stage\n"
                   "or --force if you really mean to overwrite." % (newer, staged_rev, top))
            if not args.force:
                sys.exit(msg)
            print("WARNING (forced): " + msg.split("\n")[0], file=sys.stderr)
        ops = diff(staged, read_table(conn, args.world), target)
        n_model = sum(1 for _, e in ops["update"] if e.get("model")) + sum(1 for e in ops["insert"] if e.get("model"))
        print("diff: %d update, %d insert, %d delete (%d of them custom-model anchors)"
              % (len(ops["update"]), len(ops["insert"]), len(ops["delete"]), n_model))
        if args.dry_run:
            return 0
        apply_ops(conn, args.world, ops, args.author)
        print("pushed. the server picks it up on its next poll (<=10s).")
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
