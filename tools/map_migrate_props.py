#!/usr/bin/env python3
"""Move the plain props the shipped scenario still places itself into map_objects, so they are
live-editable like everything else (Eden Live / F12), and take them out of the scenario file in
the same step so nothing is placed twice.

    ~/pysqf-venv/bin/python tools/map_migrate_props.py                 # dry run: counts, exclusions
    ~/pysqf-venv/bin/python tools/map_migrate_props.py --apply         # write rows + strip the sqm
    ~/pysqf-venv/bin/python tools/map_migrate_props.py --undo LOG.json # soft-delete the rows, restore the sqm

What qualifies as a plain prop (pass 1, 2026-09-09):
  * dataType Object, NOT inside a Group (units and their vehicles live in groups)
  * no name, no init, not playable, no presence condition -- anything a script could reach by
    name, or that runs code where the engine places it, stays in the file for a later pass
  * a static class: Land_* or one of the decor classes in KEEP_PREFIXES; anything that carries
    cargo (crates, cargo nets, supply boxes, slingloads), an item, a boat or a scooter stays --
    as a streamed row each client would get its own local copy of it

Rows follow the table's conventions: world = sqm position through sqm_frame, vdir/vup from the
sqm angles, layer AP_MAPDATA, init '', on_server false, stream_r NULL (the client default), lod
from the frozen decor lists exactly as the original migration assigned it (map_migrate_v3).

The scenario edit deletes each chosen entity by its Eden id and renumbers ItemN inside every
touched Entities block -- the same code the 2026-09-07 designer merge used -- and refuses to
write a file that no longer parses. Everything is logged to an undo file: inserted row ids and
the pre-edit backup of the sqm, so --undo puts both back.
"""
import argparse
import collections
import datetime
import json
import os
import re
import shutil
import sys
import math

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import apdb_dsn            # noqa: E402
import map_codegen         # noqa: E402
import map_decor_lists     # noqa: E402
import sqm_frame           # noqa: E402
import sqm_read            # noqa: E402
import sqm_splice          # noqa: E402

WORLD = "Malden"
AUTHOR = "migrate-props-0909"        # varchar(20)
AUTHOR2 = "migrate-p2-0909"          # pass 2: server objects and tree anchors
UNDO_AUTHOR = "migrate-props-undo"     # varchar(20) too: the first undo failed on a 23-char author
KEEP_PREFIXES = ("Land_", "Oil_Spill", "Fridge_", "OfficeTable_", "ArrowDesk_", "PortableHelipadLight",
                 "Tire_", "DeconShower", "CamoNet_", "Leaflet_", "MapBoard_", "MemorialWreath_",
                 "GalleryDioramaUnit")
DROP_PREFIXES = ("Box_", "Item_", "C_Boat", "C_Scooter", "B_Slingload", "B_supplyCrate", "C_IDAP_supplyCrate")
DROP_SUBSTR = ("CargoNet",)


def is_static_class(cls):
    # prefixes, not substrings: "Box_" must not catch Land_PaperBox_*, which is a plain prop
    if cls.startswith(DROP_PREFIXES) or any(x in cls for x in DROP_SUBSTR):
        return False
    return cls.startswith(KEEP_PREFIXES)


def select(sqm_path):
    """(chosen, skipped) entity dicts from the shipped sqm. chosen carry everything a row needs."""
    root = sqm_read.parse(sqm_path)
    chosen, skipped = [], collections.Counter()

    def rec(node, in_group, layer):
        p = node["props"]
        if p.get("dataType") == "Layer":
            layer = p.get("name")
        ing = in_group or p.get("dataType") == "Group"
        if p.get("dataType") == "Object":
            a = node["subs"].get("Attributes", {"props": {}})["props"]
            cls = p.get("type", "")
            why = None
            if ing: why = "in a group"
            elif a.get("name"): why = "named"
            elif a.get("init"): why = "has init"
            elif a.get("isPlayable"): why = "playable"
            elif "presence" in p or "presenceCondition" in a: why = "presence"
            elif not is_static_class(cls): why = "class kept: " + cls
            if why:
                skipped[why] += 1
            else:
                pi = node["subs"]["PositionInfo"]["props"]
                d, u = sqm_frame.angles_to_vectors([float(v) for v in pi.get("angles", [0, 0, 0])])
                chosen.append({"id": p["id"], "cls": cls, "layer": layer,
                               "world": sqm_frame.SQM_POS_TO_WORLD([float(v) for v in pi["position"]]),
                               "dir": d, "up": u})
        for c in node["subs"].values():
            rec(c, ing, layer)
    rec(root, False, None)
    return chosen, skipped


TREE_INIT = re.compile(
    r'(?P<var>_\w+)\s*=\s*createSimpleObject\s*\[\s*"(?P<p3d>[^"]+)"\s*,\s*\[\s*getPosASL this select 0\s*,'
    r'\s*getPosASL this select 1\s*,\s*(?:\(\s*getPosASL this select 2\s*\)\s*\+\s*(?P<dz>[-\d.]+)|getPosASL this select 2)\s*\]\s*\]\s*;',
    re.S)
TREE_ATTACH = re.compile(
    r'(?P<var>_\w+)\s*=\s*createSimpleObject\s*\[\s*"(?P<p3d>[^"]+)"\s*,\s*\[\s*0\s*,\s*0\s*,\s*0\s*\]\s*\]\s*;'
    r'\s*(?P=var)\s+attachTo\s*\[\s*this\s*,\s*\[\s*(?P<ox>[-\d.]+)\s*,\s*(?P<oy>[-\d.]+)\s*,\s*(?P<oz>[-\d.]+)\s*\]\s*\]\s*;',
    re.S)
SET_DIR = re.compile(r'(?P<var>_\w+)\s+setDir\s+(?P<val>getDir this|[-\d.]+)\s*;')
SET_SCALE = re.compile(r'(?P<var>_\w+)\s+setObjectScale\s+(?P<val>[-\d.]+)\s*;')
INVISIBLE_ANCHORS = ("Land_HelipadEmpty_F",)


def parse_tree_init(init):
    """The designer's tree anchors, two shapes:
      A. `_tree = createSimpleObject ["<p3d>", [x, y, z + dz]]; _tree setDir <getDir this|deg>;`
         -> the tree stands at the anchor plus dz, heading absolute (deg) or the anchor's own;
      B. `_tree = createSimpleObject ["<p3d>", [0,0,0]]; _tree attachTo [this, [ox, oy, oz]];
         _tree setDir deg;` -> offset in the anchor's own frame, heading RELATIVE to the anchor
         (that is what setDir means on an attached object).
    Returns (p3d, (ox, oy, oz), mode, deg, scale) with mode "abs" (deg absolute), "rel" (deg
    added to the anchor's heading) or "anchor" (the anchor's heading). setDir / setObjectScale
    only count when they name the variable the object was created into: several inits say
    `_tree1 setDir 90` about a `_tree` they never created, and in the engine that line did
    nothing, so it does nothing here. None when the init is neither shape."""
    m = TREE_ATTACH.search(init)
    if m:
        var, p3d = m.group("var"), m.group("p3d")
        off = (float(m.group("ox")), float(m.group("oy")), float(m.group("oz")))
        mode, deg = "rel", 0.0
    else:
        m = TREE_INIT.search(init)
        if not m:
            return None
        var, p3d = m.group("var"), m.group("p3d")
        off = (0.0, 0.0, float(m.group("dz")) if m.group("dz") else 0.0)
        mode, deg = "abs", 0.0
    for sm in SET_DIR.finditer(init):
        if sm.group("var") == var:
            if sm.group("val") == "getDir this":
                mode, deg = "anchor", 0.0
            else:
                deg = float(sm.group("val"))
            break
    scale = 1.0
    for sm in SET_SCALE.finditer(init):
        if sm.group("var") == var:
            scale = float(sm.group("val"))
            break
    return p3d, off, mode, deg, scale


def _rest_of_init(init):
    """The init with the tree part removed; anything left is code we would be dropping."""
    rest = TREE_ATTACH.sub("", init)
    rest = TREE_INIT.sub("", rest)
    rest = SET_DIR.sub("", rest); rest = SET_SCALE.sub("", rest)
    rest = re.sub(r"_serverObject\s*=\s*true\s*;", "", rest)
    return rest.strip()


def select_pass2(sqm_path):
    """Pass 2 (2026-09-09): the objects pass 1 left because they carried an init or a name.

    Two shapes, both from the designer:
      * init `_serverObject = true;` -- a local variable, so it never did anything at run time,
        but it marks what the designer meant to exist on the server (fed gates and safes, the
        evidence lockup, the jewelry emporium, the gang compounds). Those become is_server rows:
        the server spawns them with a global createVehicle, so scripts that animate their doors
        (fn_fedLockdown) or find them with nearestObjects keep working, and clients never stream
        a second copy. No behaviour change, and now they move in Eden.
      * a tree anchor: an invisible helipad or a visible tree grate / bin whose init plants a
        game-model tree with createSimpleObject. The tree becomes a MODEL row at the anchor's
        spot plus the init's height offset, heading and scale; a visible anchor becomes a plain
        class row of its own; an invisible one is dropped. Names on these (tree1.., treetall_..)
        are referenced by no script and are dropped.
    Anything else stays: units, player slots, vehicles, crates, the named boat."""
    root = sqm_read.parse(sqm_path)
    rows, skipped, dropped_code = [], collections.Counter(), []

    def rec(node, in_group, layer):
        p = node["props"]
        if p.get("dataType") == "Layer":
            layer = p.get("name")
        ing = in_group or p.get("dataType") == "Group"
        if p.get("dataType") == "Object":
            a = node["subs"].get("Attributes", {"props": {}})["props"]
            cls = p.get("type", ""); init = a.get("init") or ""; name = a.get("name") or ""
            why = None
            if ing: why = "in a group"
            elif a.get("isPlayable"): why = "playable"
            elif "presence" in p or "presenceCondition" in a: why = "presence"
            elif not init and not name: why = "plain (pass 1)"
            elif not is_static_class(cls): why = "class kept: " + cls
            if why:
                skipped[why] += 1
            else:
                pi = node["subs"]["PositionInfo"]["props"]
                d, u = sqm_frame.angles_to_vectors([float(v) for v in pi.get("angles", [0, 0, 0])])
                w = sqm_frame.SQM_POS_TO_WORLD([float(v) for v in pi["position"]])
                tree = parse_tree_init(init) if "createSimpleObject" in init else None
                if tree:
                    p3d, (ox, oy, oz), mode, deg, scale = tree
                    heading = math.degrees(math.atan2(d[0], d[1]))          # the anchor's own, from its dir vector
                    if mode == "abs":
                        final = deg
                    elif mode == "rel":
                        final = heading + deg
                    else:
                        final = heading
                    r = math.radians(final)
                    td, tu = (math.sin(r), math.cos(r), 0.0), (0.0, 0.0, 1.0)
                    # a model-frame offset (attachTo) turns with the anchor; the shapes here are all
                    # straight up, but the maths is kept general
                    h = math.radians(heading)
                    wx = w[0] + ox * math.cos(h) + oy * math.sin(h)
                    wy = w[1] - ox * math.sin(h) + oy * math.cos(h)
                    rows.append({"id": p["id"], "kind": "model", "model": p3d, "scale": scale, "layer": layer,
                                 "world": (wx, wy, w[2] + oz), "dir": td, "up": tu, "src_cls": cls, "name": name})
                    if cls not in INVISIBLE_ANCHORS:
                        rows.append({"id": None, "kind": "class", "cls": cls, "layer": layer, "world": w, "dir": d, "up": u,
                                     "is_server": False, "src_id": p["id"]})
                    rest = _rest_of_init(init)
                    if rest:
                        dropped_code.append((p["id"], cls, rest[:80]))
                elif "createSimpleObject" in init:
                    skipped["tree init not understood"] += 1
                elif name and not init:
                    skipped["named, no init: " + cls] += 1        # the boat; scripts may read the name
                else:
                    rest = _rest_of_init(init)
                    if rest:
                        skipped["init not understood: " + rest[:40]] += 1
                    else:
                        rows.append({"id": p["id"], "kind": "class", "cls": cls, "layer": layer, "world": w, "dir": d, "up": u,
                                     "is_server": True, "src_id": p["id"]})
        for c in node["subs"].values():
            rec(c, ing, layer)
    rec(root, False, None)
    return rows, skipped, dropped_code


def tiers():
    decor, shit = map_decor_lists.DECOR, map_decor_lists.SHIT
    both = set(decor) & set(shit)
    return {c: 3 for c in both} | {c: 2 for c in decor if c not in both}


# ---- scenario surgery (verbatim from scratchpad/map_delivery/merge_20260907.py, proven 2026-09-07)
def entity_block(text, eid):
    m = re.search(r"\n(\t+)id=%d;\n" % eid, text)
    if not m:
        raise KeyError(eid)
    d = len(m.group(1))
    hdr = re.compile(r"\n" + "\t" * (d - 1) + r"class Item(\d+)\n" + "\t" * (d - 1) + r"\{\n")
    last = None
    for h in hdr.finditer(text, 0, m.start() + 1):
        last = h
    start = last.start()
    brace = text.index("{", last.end() - 2)
    end = sqm_splice._scan(text, brace + 1)
    assert text[end:end + 2] == "};"
    end += 2
    ph = re.compile(r"\n" + "\t" * (d - 2) + r"class Entities\n" + "\t" * (d - 2) + r"\{\n")
    par = None
    for h in ph.finditer(text, 0, start + 1):
        par = h
    pstart = par.start()
    pbrace = text.index("{", par.end() - 2)
    pend = sqm_splice._scan(text, pbrace + 1)
    assert pend > end, "parent does not enclose entity"
    return start, end, pstart, d


def renumber_entities(text, pstart, d):
    pbrace = text.index("{", pstart + 1)
    pend = sqm_splice._scan(text, pbrace + 1)
    body = text[pbrace + 1:pend]
    hdr = re.compile(r"(\n" + "\t" * (d - 1) + r"class Item)(\d+)(\n" + "\t" * (d - 1) + r"\{\n)")
    n = [0]

    def sub(m):
        r = "%s%d%s" % (m.group(1), n[0], m.group(3))
        n[0] += 1
        return r
    body2 = hdr.sub(sub, body)
    body2, k = re.subn(r"(\n" + "\t" * (d - 1) + r"items=)\d+;", lambda m: "%s%d;" % (m.group(1), n[0]), body2, count=1)
    assert k == 1, "items= not found in parent Entities"
    return text[:pbrace + 1] + body2 + text[pend:], n[0]


def strip_entities(text, ids):
    """Delete the entities with these Eden ids and renumber ItemN in every Entities block.

    One pass, not one scan per entity: the first version located each block from the top of a
    5.8 MB file and took minutes for four thousand ids. Every `id=` line and every `class ItemN`
    / `class Entities` header is found once; an entity's block is the nearest header of the
    right depth before its id line, its end the matching brace. Blocks are removed from the end
    of the file backwards, so earlier offsets stay valid whatever the nesting, and only then is
    every Entities block renumbered, again from the end backwards. Renumbering an untouched
    block is a no-op, so no bookkeeping of "which parents were touched" is needed."""
    import bisect
    want = set(ids)
    id_lines = {}
    for m in re.finditer(r"\n(\t+)id=(\d+);\n", text):
        eid = int(m.group(2))
        if eid in want and eid not in id_lines:
            id_lines[eid] = (m.start(), len(m.group(1)))
    missing = want - set(id_lines)
    if missing:
        raise KeyError("ids not in the scenario: %s" % sorted(missing)[:10])
    headers = {}
    spans = []
    for eid, (off, d) in id_lines.items():
        if d not in headers:
            pat = re.compile(r"\n" + "\t" * (d - 1) + r"class Item\d+\n" + "\t" * (d - 1) + r"\{\n")
            headers[d] = [h.start() for h in pat.finditer(text)]
        hs = headers[d]
        i = bisect.bisect_right(hs, off) - 1
        assert i >= 0, "no ItemN header before id %d" % eid
        st = hs[i]
        brace = text.index("{", st + 1)
        en = sqm_splice._scan(text, brace + 1)
        assert text[en:en + 2] == "};", "entity %d does not end with };" % eid
        spans.append((st, en + 2))
    spans.sort(reverse=True)
    for st, en in spans:
        text = text[:st] + text[en:]
    ents = [(m.start(), len(m.group(1))) for m in re.finditer(r"\n(\t*)class Entities\n\t*\{\n", text)]
    touched = 0
    for pstart, dpar in sorted(ents, reverse=True):
        before = text
        text, cnt = renumber_entities(text, pstart, dpar + 2)
        if text != before:
            touched += 1
    sqm_read._parse_text(text)
    return text, [("all", len(spans), touched)]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true", help="write the rows and strip the scenario (default: dry run)")
    ap.add_argument("--sqm", default=map_codegen.SHIPPED_SQM, help="scenario to read and (with --apply) rewrite")
    ap.add_argument("--world", default=WORLD)
    ap.add_argument("--undo", metavar="LOG", help="reverse a previous --apply from its undo log")
    ap.add_argument("--pass2", action="store_true", help="the init-bearing and named objects pass 1 left (see select_pass2)")
    ap.add_argument("--log-dir", default=os.path.join(TOOLS, "..", "scratchpad", "map_delivery"))
    a = ap.parse_args(argv)

    if a.undo:
        log = json.load(open(a.undo))
        conn = apdb_dsn.connect()
        with conn, conn.cursor() as cur:
            cur.execute("UPDATE map_objects SET deleted=true, author_uid=%s WHERE world=%s AND id = ANY(%s) AND NOT deleted",
                        (UNDO_AUTHOR, log["world"], log["inserted_rows"]))
            print("soft-deleted %d rows" % cur.rowcount)
        shutil.copy(log["sqm_backup"], log["sqm"])
        print("restored %s from %s" % (log["sqm"], log["sqm_backup"]))
        return 0

    author = AUTHOR2 if a.pass2 else AUTHOR
    tier = tiers()
    print("scenario: %s" % a.sqm)
    if a.pass2:
        rows, skipped, dropped_code = select_pass2(a.sqm)
        srv = [r for r in rows if r["kind"] == "class" and r.get("is_server")]
        trees = [r for r in rows if r["kind"] == "model"]
        anchors = [r for r in rows if r["kind"] == "class" and not r.get("is_server")]
        print("pass 2: %d server objects (is_server), %d trees (model rows), %d visible tree anchors" % (len(srv), len(trees), len(anchors)))
        print("server objects by class:", collections.Counter(r["cls"] for r in srv).most_common(8))
        print("trees by model:", collections.Counter(r["model"].rsplit("\\", 1)[-1] for r in trees).most_common())
        print("skipped:", dict(sorted(skipped.items(), key=lambda kv: -kv[1])))
        if dropped_code:
            print("init code that would be DROPPED (refusing):", dropped_code[:5])
            return 1
        chosen = rows
        del_ids = sorted({r["id"] for r in rows if r["id"] is not None} | {r["src_id"] for r in rows if r.get("src_id")})
    else:
        chosen, skipped = select(a.sqm)
        by_cls = collections.Counter(e["cls"] for e in chosen)
        by_layer = collections.Counter(e["layer"] or "<root>" for e in chosen)
        print("chosen: %d props, %d classes; lod2=%d lod3=%d, the rest lod1" % (
            len(chosen), len(by_cls), sum(1 for e in chosen if tier.get(e["cls"]) == 2), sum(1 for e in chosen if tier.get(e["cls"]) == 3)))
        print("by layer:", dict(by_layer.most_common()))
        print("skipped:", dict(sorted(skipped.items(), key=lambda kv: -kv[1])))
        del_ids = [e["id"] for e in chosen]
    if not a.apply:
        print("\n(dry run -- pass --apply to write)")
        return 0

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    os.makedirs(a.log_dir, exist_ok=True)
    bak = a.sqm + ".pre-props-" + stamp
    shutil.copy(a.sqm, bak)
    log = {"world": a.world, "author": author, "sqm": a.sqm, "sqm_backup": bak, "when": stamp,
           "inserted_rows": [], "sqm_deleted_ids": del_ids}

    # the scenario edit first, in memory: if it cannot be done cleanly no row is written
    text = open(a.sqm).read()
    before = set(sqm_read.entity_ids(a.sqm))
    text, report = strip_entities(text, log["sqm_deleted_ids"])
    after = set(sqm_read.entity_ids_text(text)) if hasattr(sqm_read, "entity_ids_text") else {
        n["props"]["id"] for n in sqm_read.walk(sqm_read._parse_text(text)) if isinstance(n["props"].get("id"), int)}
    assert after == before - set(log["sqm_deleted_ids"]), "delete pass changed the wrong ids"

    conn = apdb_dsn.connect()
    with conn, conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM map_objects WHERE world=%s AND author_uid=%s AND NOT deleted", (a.world, author))
        if cur.fetchone()[0]:
            sys.exit("refusing: rows by %s already exist in %s (migration already applied?)" % (author, a.world))
        for e in chosen:
            w, d, u = e["world"], e["dir"], e["up"]
            if e.get("kind") == "model":
                cur.execute(
                    "INSERT INTO map_objects (world, classname, model, scale, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z,"
                    " init, is_server, layer, lod, stream_r, on_server, author_uid)"
                    " VALUES (%s, '', %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, '', false, 'AP_CUSTOM_P3D', 1, NULL, false, %s) RETURNING id",
                    (a.world, e["model"], e["scale"], w[0], w[1], w[2], d[0], d[1], d[2], u[0], u[1], u[2], author))
            else:
                cur.execute(
                    "INSERT INTO map_objects (world, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z,"
                    " init, is_server, layer, lod, stream_r, on_server, author_uid)"
                    " VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, '', %s, 'AP_MAPDATA', %s, NULL, false, %s) RETURNING id",
                    (a.world, e["cls"], w[0], w[1], w[2], d[0], d[1], d[2], u[0], u[1], u[2], bool(e.get("is_server")), tier.get(e["cls"], 1), author))
            log["inserted_rows"].append(cur.fetchone()[0])
    print("table: inserted %d rows (ids %d..%d)" % (len(log["inserted_rows"]), min(log["inserted_rows"]), max(log["inserted_rows"])))

    open(a.sqm, "w").write(text)
    assert set(sqm_read.entity_ids(a.sqm)) == after, "written scenario does not match the checked text"
    for _, n, touched in report:
        print("  removed %d entity blocks, renumbered %d Entities block(s)" % (n, touched))
    print("scenario: %d entities removed, parse OK, backup %s" % (len(log["sqm_deleted_ids"]), bak))

    logp = os.path.join(a.log_dir, "undo_props_%s.json" % stamp)
    json.dump(log, open(logp, "w"), indent=1)
    print("undo log:", logp)
    return 0


if __name__ == "__main__":
    sys.exit(main())
