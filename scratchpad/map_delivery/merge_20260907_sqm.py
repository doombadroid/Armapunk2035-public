#!/usr/bin/env python3
"""Phase 2 of the 2026-09-07 designer-delivery merge: the SHIPPED text mission.sqm.
Runs after merge_20260907.py's table phase (already committed). Recomputes the kit->delivery diff and:
  * deletes 113 designer-layer objects + 4 Hide-Terrain modules + 8 markers (4 labels, 4 stray pads) by id,
    with STRUCTURAL ItemN enumeration (brace-scanned, indentation-free: one root item has a 3-tab header)
  * moves marker_60 + air_spawn_5, splices car_spawn_10/11 + air_spawn_6 (renamed pads), 5 new modules
  * splices the designer's NEW init-carrying objects (Eden `this` inits: palm-tree anchors, _serverObject)
    as real entities -- rows run init with _this, so they cannot live in the table -- EXCEPT the three
    dead palace/shop anchors (createSimpleObject from a Windows absolute path): dropped, ours restored.
"""
import sys, os, re, json, math, shutil, collections, datetime
TOOLS = "/home/timb/Armapunk2035/tools"; sys.path.insert(0, TOOLS)
import sqm_read, sqm_splice, map_codegen
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "merge_20260907.py")).read().split("conn = apdb_dsn.connect()")[0].split("import sqm_read, sqm_frame, sqm_splice, map_codegen, apdb_dsn")[1])
APPLY = "--apply" in sys.argv
ship_ids = set(sqm_read.entity_ids(SHIP))

# ---- what to delete
sqm_deletes = [i for i in true_rem if (A[i]["dt"] == "Object" and not A[i]["ingroup"] and not is_p3d(A[i]) and not A[i]["layer"].startswith("PLB_") and not npc_cls(A[i])) or A[i]["dt"] == "Logic"]
ship_markers = {str(p.get("name", "")): p for p, _ in map_codegen._markers_in(SHIP)}
del_markers = {str(e["name"]): e for e in B.values() if e["dt"] == "Marker"}
label_drop = ["marker_190", "marker_191", "marker_192", "marker_225", "marker_226", "marker_227", "marker_228", "marker_229"]
for nm in label_drop: sqm_deletes.append(ship_markers[nm]["id"])
missing = [i for i in sqm_deletes if i not in ship_ids]
assert not missing, missing
marker_moves = ["marker_60", "air_spawn_5"]
rename_pads = {"marker_241": "car_spawn_10", "marker_242": "car_spawn_11", "marker_243": "air_spawn_6"}
ship_logic = [(n["props"].get("type"), map_codegen._node_pos(n)) for n in map_codegen._nodes_in(SHIP, "Logic")]
def logic_dup(ty, xy): return any(t == ty and abs(x - xy[0]) < 1 and abs(y - xy[1]) < 1 for t, (x, y) in ship_logic)
new_logic = [B[i]["node"] for i in true_add if B[i]["dt"] == "Logic" and not logic_dup(B[i]["cls"], map_codegen._node_pos(B[i]["node"]))]
# designer's new init-carrying objects -> entities (not rows)
init_objs, dead = [], []
for i in true_add:
    e = B[i]
    if e["dt"] != "Object" or e["ingroup"] or is_p3d(e) or npc_cls(e) or not e["init"] or "_this" in e["init"]: continue
    if "createSimpleObject" in e["init"] and re.search(r'"[A-Za-z]:\\', e["init"]): dead.append((i, e["init"][:70])); continue
    init_objs.append(e["node"])
print("deletes %d (%d obj, %d logic, %d marker) | moves %s | new pads %s | new modules %d | init objects -> entities %d | dead anchors dropped %d"
      % (len(sqm_deletes), sum(1 for i in sqm_deletes if A.get(i, {}).get("dt") == "Object"), sum(1 for i in sqm_deletes if A.get(i, {}).get("dt") == "Logic"),
         len(label_drop), marker_moves, list(rename_pads.values()), len(new_logic), len(init_objs), len(dead)))
for d in dead: print("   dropped:", d)
print("   init objects:", collections.Counter(n["subs"]["Attributes"]["props"]["init"][:30] for n in init_objs))

# ---- structural root-entities surgery
def root_children(text):
    """[(start, end_after_'};', item_name, top_level_id)] for every direct child of Mission>>Entities."""
    _, _, body_end = sqm_splice.find_mission_entities(text)
    m = re.search(r"\bclass\s+Mission\s*\{", text); i = m.end()
    ent = None
    while True:
        em = re.compile(r"\bclass\s+(\w+)\s*\{").search(text, i)
        be = sqm_splice._scan(text, em.end())
        if em.group(1) == "Entities": ent = (em, be); break
        i = be + 1
    em, be = ent
    out = []; pos = em.end()
    while True:
        cm = re.compile(r"\bclass\s+(Item\d+)\s*\{").search(text, pos, be)
        if not cm: break
        ce = sqm_splice._scan(text, cm.end())                 # offset of the child's closing brace
        assert text[ce:ce + 2] == "};"
        start = text.rindex("\n", 0, cm.start()) + 1          # start of the header line (any indentation)
        # top-level id: strip nested blocks first
        blk = text[cm.end():ce]; flat = []; j = 0
        while True:
            nm = re.compile(r"\bclass\s+\w+\s*\{").search(blk, j)
            if not nm: flat.append(blk[j:]); break
            flat.append(blk[j:nm.start()]); j = sqm_splice._scan(blk, nm.end()) + 1
        idm = re.search(r"\bid=(\d+);", "".join(flat))
        out.append((start, ce + 2, cm.group(1), int(idm.group(1)) if idm else None))
        pos = ce + 2
    return out, (em, be)

def delete_root_items(text, ids):
    kids, (em, be) = root_children(text)
    byid = {k[3]: k for k in kids}
    for i in ids: assert i in byid, "not a root item: %d" % i
    ids = set(ids)
    keep = [k for k in kids if k[3] not in ids]
    # rebuild the Entities body: items=N + renumbered children, headers normalised to two tabs
    parts = ["\n\t\titems=%d;\n" % len(keep)]
    for n, (s, e, name, i) in enumerate(keep):
        blk = text[s:e]
        blk = re.sub(r"^[ \t]*class\s+Item\d+", "\t\tclass Item%d" % n, blk, 1)
        parts.append(blk + "\n")
    body_start = em.end()
    return text[:body_start] + "".join(parts) + "\t" + text[be:]     # be points at the Entities' closing brace

s = open(SHIP).read()
kids0, _ = root_children(s)
print("root items:", len(kids0), "ids resolved:", sum(1 for k in kids0 if k[3] is not None))
assert len(kids0) == sqm_splice.find_mission_entities(s)[0], "structural child count != items="
s2 = delete_root_items(s, sqm_deletes)
sqm_read._parse_text(s2)
ids2 = set(sqm_read.entity_ids_text(s2)) if hasattr(sqm_read, "entity_ids_text") else None
if not APPLY:
    open("/tmp/claude-1000/-home-timb/82924563-99c1-4dfb-9ca1-31318f1f6b5e/scratchpad/sqm_after_delete.sqm", "w").write(s2)
    ids2 = set(sqm_read.entity_ids("/tmp/claude-1000/-home-timb/82924563-99c1-4dfb-9ca1-31318f1f6b5e/scratchpad/sqm_after_delete.sqm"))
    print("dry: after delete ids %d (expect %d); exact set ok: %s" % (len(ids2), len(ship_ids) - len(sqm_deletes), ids2 == ship_ids - set(sqm_deletes)))
    k2, _ = root_children(s2); print("dry: root items now", len(k2), "items= says", sqm_splice.find_mission_entities(s2)[0])
    print("(dry run -- pass --apply)"); sys.exit(0)

stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
bak = SHIP + ".pre-delivery-" + stamp; shutil.copy(SHIP, bak); print("backup", bak)
open(SHIP, "w").write(s2)
ids2 = set(sqm_read.entity_ids(SHIP)); assert ids2 == ship_ids - set(sqm_deletes), "delete pass changed the wrong ids"
print("deleted %d entities, parse OK" % len(sqm_deletes))

# ---- marker moves
s = open(SHIP).read()
for nm in marker_moves:
    p = del_markers[nm]["node"]["props"]; cur_p = ship_markers[nm]
    i = s.index('name="%s"' % nm); start = s.rindex("class Item", 0, i); end = sqm_splice._scan(s, s.index("{", start) + 1)
    block = s[start:end]
    block = re.sub(r"position\[\]=\{[^}]*\};", "position[]=%s;" % map_codegen._fmt_val([float(v) for v in p["position"]]), block, 1)
    if "angle=" in block: block = re.sub(r"angle=[^;]*;", "angle=%s;" % map_codegen._fmt_val(float(p.get("angle", 0))), block, 1)
    elif p.get("angle") is not None: block = block.replace("name=", "angle=%s;\n\t\t\tname=" % map_codegen._fmt_val(float(p["angle"])), 1)
    s = s[:start] + block + s[end:]
    print("  marker %s: %s -> %s" % (nm, [round(float(v), 1) for v in cur_p["position"]], [round(float(v), 1) for v in p["position"]]))
sqm_read._parse_text(s); open(SHIP, "w").write(s)

# ---- splices: renamed pads, modules, init objects
s = open(SHIP).read()
new_marker_props = []
for old, new in rename_pads.items():
    p = dict(del_markers[old]["node"]["props"]); p["name"] = new; p["text"] = ""; new_marker_props.append(p)
n_new = len(new_marker_props) + len(new_logic) + len(init_objs)
base, _ = sqm_splice.item_id_provider(s); s = sqm_splice.set_next_id(s, base + n_new)
n_items, _, _ = sqm_splice.find_mission_entities(s)
blocks = [map_codegen._emit_marker(p, n_items + k, base + k) for k, p in enumerate(new_marker_props)]
for n in new_logic + init_objs:
    blocks.append(map_codegen._emit_node(n, n_items + len(blocks), base + len(blocks)))
s = sqm_splice.splice_layers(s, blocks); open(SHIP, "w").write(s)
final = set(sqm_read.entity_ids(SHIP)); assert len(final) == len(ids2) + n_new and ids2 <= final
print("spliced +%d markers +%d modules +%d init objects; entities %d -> %d" % (len(new_marker_props), len(new_logic), len(init_objs), len(ship_ids), len(final)))
json.dump({"backup": bak, "deleted_ids": sqm_deletes, "moved": marker_moves, "new_markers": list(rename_pads.values()),
           "new_modules": len(new_logic), "init_objects": len(init_objs), "dead_dropped": dead}, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "undo_sqm_%s.json" % stamp), "w"), indent=1, default=str)
