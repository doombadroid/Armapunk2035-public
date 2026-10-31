#!/usr/bin/env python3
"""merge_20260907.py -- one-off 3-way merge of the designer's 2026-09-07 mission.sqm delivery.

    BASE  = MAD_designer_kit_20260806.zip :: MaldenEdit.Malden/mission.sqm  (what the designer edited)
    THEIRS= ~/Downloads/mission(1).sqm  (binarized, sourceName MaldenFinal)
    OURS  = map_objects (live dev table) + mission/Armapunk2035.Malden/mission.sqm (shipped, text)

Owner decisions (AskUserQuestion, 2026-09-07):
  * accept EVERY object the designer deleted (palace r5, PalaceShops, 5-floor garage, 5 NPC anchors,
    decor, designer-layer objects, 4 Hide-Terrain modules)
  * skyscraper30: move ours (r17) to the designer's new spot; ignore the second tower they placed
  * wired spawn/respawn markers they deleted: KEEP (not applied); their 3 new pads renamed
    car_spawn_10 / car_spawn_11 / air_spawn_6; sheriff label + air_spawn_5 moves applied
  * the four map labels they deleted (Night Club, Grand Palace, Casino, Garage): drop
Everything else: designer adds -> table rows (dupes by class+pos skipped), PLB-layer removals -> soft
delete by class+pos, designer-layer removals -> delete from the shipped text sqm by Eden id (with
ItemN renumbering), new modules -> spliced. Dry-run by default; --apply writes. Undo log in JSON.
"""
import sys, os, re, json, math, shutil, collections, datetime
TOOLS = "/home/timb/Armapunk2035/tools"; sys.path.insert(0, TOOLS)
import sqm_read, sqm_frame, sqm_splice, map_codegen, apdb_dsn

KIT = "/tmp/claude-1000/-home-timb/82924563-99c1-4dfb-9ca1-31318f1f6b5e/scratchpad/kit/MaldenEdit.Malden/mission.sqm"
DEL = "/home/timb/Downloads/mission(1).sqm"
SHIP = map_codegen.SHIPPED_SQM
AUTHOR = "designer-20260907"          # varchar(20)
WORLD = "Malden"
TOL = 0.05
APPLY = "--apply" in sys.argv
LOG = {"deleted_rows": [], "inserted_rows": [], "updated_rows": [], "sqm_deleted_ids": [], "sqm_moved_markers": [],
       "sqm_new_markers": [], "sqm_new_modules": [], "skipped": [], "unmatched": []}

# ------------------------------------------------------------------ read both sqm -------------
def index(path):
    out = {}
    def rec(n, layer, in_group):
        p = n.get("props", {})
        dt = p.get("dataType")
        if dt == "Layer": layer = p.get("name", "?")
        ing = in_group or dt == "Group"
        if dt and dt != "Layer" and "id" in p:
            pos = None; ang = [0, 0, 0]
            ps = n["subs"].get("PositionInfo")
            if ps: pos = ps["props"].get("position"); ang = ps["props"].get("angles", [0, 0, 0])
            if dt == "Marker": pos = p.get("position")
            a = n["subs"].get("Attributes", {}).get("props", {})
            out[p["id"]] = dict(dt=dt, cls=p.get("type", ""), pos=tuple(float(v) for v in pos) if pos else None,
                                ang=[float(v) for v in ang], desc=a.get("description", ""), init=a.get("init", ""),
                                name=p.get("name", ""), layer=layer, ingroup=in_group, node=n)
        for s in n["subs"].values(): rec(s, layer, ing)
    rec(sqm_read.parse(path), "(root)", False); return out

def dist(a, b):
    if not a or not b: return 0 if a == b else 1e9
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))

def toks(desc): return map_codegen._tokens(desc)
def tok(desc, key):
    return next((t[len(key):] for t in toks(desc) if t.startswith(key)), None)
def is_p3d(e): return tok(e["desc"], "PLB_P3D=") is not None or tok(e["desc"], "AP_P3D=") is not None
def npc_cls(e): return tok(e["desc"], "PLB_NPC=") or tok(e["desc"], "AP_NPC=")
def eff_cls(e): return npc_cls(e) or e["cls"]

print("reading kit ..."); A = index(KIT)
print("reading delivery ..."); B = index(DEL)
added = [i for i in B if i not in A]; removed = [i for i in A if i not in B]
same = [i for i in B if i in A]
moved = [i for i in same if dist(A[i]["pos"], B[i]["pos"]) > TOL]

# cut/paste re-ids: same dt+class(+marker name), same position -> not a change
key = lambda e: (e["dt"], e["cls"], e["name"] if e["dt"] == "Marker" else "")
byk = collections.defaultdict(list)
for i in added: byk[key(B[i])].append(i)
used = set(); reid = 0
for r in removed:
    best, bd = None, TOL
    for a in byk.get(key(A[r]), []):
        if a in used: continue
        d = dist(A[r]["pos"], B[a]["pos"])
        if d <= bd: bd, best = d, a
    if best is not None: used.add(best); reid += 1; A[r]["reid"] = best
true_add = [i for i in added if i not in used]
true_rem = [i for i in removed if "reid" not in A[i]]
print("kit %d, delivery %d, re-ids %d, true adds %d, true removes %d, moved %d"
      % (len(A), len(B), reid, len(true_add), len(true_rem), len(moved)))

conn = apdb_dsn.connect(); cur = conn.cursor()

# ------------------------------------------------------------------ TABLE: deletes -----------
def live_match(cls, pos, xy_tol, z_tol=0.5):
    cur.execute("SELECT id FROM map_objects WHERE world=%s AND NOT deleted AND classname=%s AND abs(x-%s)<%s AND abs(y-%s)<%s AND abs(z-%s)<%s",
                (WORLD, cls, pos[0], xy_tol, pos[2], xy_tol, pos[1], z_tol))
    return [r[0] for r in cur.fetchall()]
def live_p3d_match(pos, xy_tol=0.5):
    cur.execute("SELECT id, model FROM map_objects WHERE world=%s AND NOT deleted AND model IS NOT NULL AND model<>'' AND abs(x-%s)<%s AND abs(y-%s)<%s",
                (WORLD, pos[0], xy_tol, pos[2], xy_tol))
    return cur.fetchall()

row_deletes = []            # (row id, why)
sqm_deletes = []            # kit ids (== shipped ids) to remove from the shipped text sqm
for i in true_rem:
    e = A[i]
    if e["dt"] == "Object":
        if e["ingroup"]:
            LOG["skipped"].append(("kit-object-in-group", i, e["cls"])); continue
        if is_p3d(e):
            m = live_p3d_match(e["pos"])
            if len(m) == 1: row_deletes.append((m[0][0], "p3d %s -> live %s" % (tok(e["desc"], "PLB_P3D="), m[0][1])))
            else: LOG["unmatched"].append(("p3d", tok(e["desc"], "PLB_P3D="), e["pos"], [x[1] for x in m]))
        elif e["layer"].startswith("PLB_") or npc_cls(e):
            cls = eff_cls(e)
            m = live_match(cls, e["pos"], 0.1)
            if len(m) == 1: row_deletes.append((m[0], cls))
            else:
                m2 = live_match(cls, e["pos"], 2.0, 2.0)
                if len(m2) == 1: row_deletes.append((m2[0], cls + " (loose 2 m)"))
                else: LOG["unmatched"].append(("row", cls, e["pos"], m2))
        else:
            sqm_deletes.append(i)            # designer's own entity, lives in the shipped sqm
    elif e["dt"] == "Logic":
        sqm_deletes.append(i)
    elif e["dt"] == "Marker":
        pass                                 # handled below by explicit owner rules
    else:
        LOG["skipped"].append(("kit-removed-" + e["dt"], i, e["name"]))

# ------------------------------------------------------------------ TABLE: moves -------------
row_updates = []
for i in moved:
    a, b = A[i], B[i]
    if a["dt"] != "Object": LOG["skipped"].append(("moved-" + a["dt"], i, a["name"])); continue
    if is_p3d(a):
        m = live_p3d_match(a["pos"])
        if len(m) != 1: LOG["unmatched"].append(("moved-p3d", tok(a["desc"], "PLB_P3D="), a["pos"], m)); continue
        d, u = sqm_frame.angles_to_vectors(b["ang"]); w = sqm_frame.SQM_POS_TO_WORLD(list(b["pos"]))
        row_updates.append((m[0][0], w, d, u, "%s %s -> %s" % (m[0][1], tuple(round(x, 1) for x in a["pos"]), tuple(round(x, 1) for x in b["pos"]))))
    else:
        cls = eff_cls(a); m = live_match(cls, a["pos"], 0.1)
        if len(m) != 1: LOG["unmatched"].append(("moved-row", cls, a["pos"], m)); continue
        d, u = sqm_frame.angles_to_vectors(b["ang"]); w = sqm_frame.SQM_POS_TO_WORLD(list(b["pos"]))
        row_updates.append((m[0], w, d, u, cls))

# ------------------------------------------------------------------ TABLE: inserts -----------
row_inserts = []            # dicts of columns
skip_models = {"skyscraper30_r6"}    # owner: one tower only -- ours is moved, the extra one is dropped
# BUG FOUND AFTER THE RUN (2026-09-07, owner: "tiles not placed like the sqm"): the dupe checks below read
# the LIVE table, which still held the rows this same plan was about to soft-delete. A designer tile re-laid
# on an old tile's XY was therefore skipped as a duplicate and its twin then deleted -- 42 holes. The check
# must exclude rows scheduled for deletion; fixed here for the record (the 42 were re-inserted separately).
_scheduled = {rid for rid, _ in row_deletes}
def _live_alive(cls, pos, tol):
    return [rid for rid in live_match(cls, pos, tol) if rid not in _scheduled]
def _p3d_alive(pos):
    return [m for m in live_p3d_match(pos) if m[0] not in _scheduled]
for i in true_add:
    e = B[i]
    if e["dt"] != "Object" or e["ingroup"]: continue
    d, u = sqm_frame.angles_to_vectors(e["ang"]); w = sqm_frame.SQM_POS_TO_WORLD(list(e["pos"]))
    if is_p3d(e):
        model = tok(e["desc"], "PLB_P3D=") or tok(e["desc"], "AP_P3D=")
        scale = float(tok(e["desc"], "PLB_SCALE=") or tok(e["desc"], "AP_SCALE=") or 1)
        if model in skip_models: LOG["skipped"].append(("second-tower", i, model, w)); continue
        if _p3d_alive(e["pos"]): LOG["skipped"].append(("p3d-dupe", i, model, w)); continue
        cols = {"world": WORLD, "classname": "", "model": map_codegen.model_path(model), "scale": scale,
                "x": w[0], "y": w[1], "z": w[2], "vdir_x": d[0], "vdir_y": d[1], "vdir_z": d[2],
                "vup_x": u[0], "vup_y": u[1], "vup_z": u[2]}
        cols.update(map_codegen.__dict__.get("P3D_DEFAULTS", {"on_server": True, "stream_r": 0.0, "lod": 0, "layer": map_codegen.LAYER_P3D}))
    else:
        cls = eff_cls(e)
        if _live_alive(cls, e["pos"], 0.1): LOG["skipped"].append(("dupe", i, cls, tuple(round(x, 1) for x in w))); continue
        cols = {"world": WORLD, "classname": cls, "x": w[0], "y": w[1], "z": w[2],
                "vdir_x": d[0], "vdir_y": d[1], "vdir_z": d[2], "vup_x": u[0], "vup_y": u[1], "vup_z": u[2],
                "init": e["init"]}
    cols["author_uid"] = AUTHOR
    row_inserts.append(cols)

# ------------------------------------------------------------------ SQM: markers ------------
ship_markers = {str(p.get("name", "")): p for p, _ in map_codegen._markers_in(SHIP)}
del_markers = {str(e["name"]): e for e in B.values() if e["dt"] == "Marker"}
label_drop = ["marker_190", "marker_191", "marker_192", "marker_225",           # owner: drop labels
              "marker_226", "marker_227", "marker_228", "marker_229"]           # stray unwired pads at the OLD HQ (text-only, type Empty)
marker_moves = ["marker_60", "air_spawn_5"]                                      # owner: apply
rename_pads = {"marker_241": "car_spawn_10", "marker_242": "car_spawn_11", "marker_243": "air_spawn_6"}
for nm in label_drop:
    assert nm in ship_markers, nm
    sqm_deletes.append(ship_markers[nm]["id"])
for nm in rename_pads.values(): assert nm not in ship_markers, "name taken: " + nm
kept_wired = sorted(str(A[i]["name"]) for i in true_rem if A[i]["dt"] == "Marker" and str(A[i]["name"]) not in label_drop)

# ------------------------------------------------------------------ SQM: modules ------------
ship_logic = [(n["props"].get("type"), map_codegen._node_pos(n)) for n in map_codegen._nodes_in(SHIP, "Logic")]
def logic_dup(ty, xy): return any(t == ty and abs(x - xy[0]) < 1 and abs(y - xy[1]) < 1 for t, (x, y) in ship_logic)
new_logic = [B[i]["node"] for i in true_add if B[i]["dt"] == "Logic" and not logic_dup(B[i]["cls"], map_codegen._node_pos(B[i]["node"]))]

# ------------------------------------------------------------------ report -------------------
ship_ids = set(sqm_read.entity_ids(SHIP))
missing = [i for i in sqm_deletes if i not in ship_ids]
print("\n== PLAN")
print("table soft-deletes: %d" % len(row_deletes)); print("   ", collections.Counter(w.split(" (")[0] for _, w in row_deletes).most_common(6))
print("table updates (moves): %d" % len(row_updates)); [print("   ", r[4]) for r in row_updates]
print("table inserts: %d  (%d class rows, %d p3d anchors)" % (len(row_inserts), sum(1 for c in row_inserts if c["classname"]), sum(1 for c in row_inserts if not c["classname"])))
print("   p3d:", collections.Counter(os.path.basename(c["model"]) for c in row_inserts if not c["classname"]))
print("shipped sqm deletes by id: %d (%d Object, %d Logic, %d Marker)  missing-from-shipped: %d" % (
    len(sqm_deletes), sum(1 for i in sqm_deletes if A.get(i, {}).get("dt") == "Object"),
    sum(1 for i in sqm_deletes if A.get(i, {}).get("dt") == "Logic"), len(label_drop), len(missing)))
print("shipped sqm marker moves:", marker_moves, " new pads:", rename_pads)
print("shipped sqm new modules: %d" % len(new_logic))
print("wired markers the designer deleted, KEPT:", kept_wired)
print("skipped:", collections.Counter(s[0] for s in LOG["skipped"]))
print("unmatched:", len(LOG["unmatched"])); [print("   ", u) for u in LOG["unmatched"]]
if missing: sys.exit("ABORT: %d ids to delete are not in the shipped sqm: %s" % (len(missing), missing[:10]))

if not APPLY:
    print("\n(dry run -- pass --apply to write)"); sys.exit(0)

# ================================================================== APPLY ====================
stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
bak = SHIP + ".pre-delivery-" + stamp; shutil.copy(SHIP, bak); print("\nshipped sqm backed up to", bak)

# ---- table
for rid, why in row_deletes:
    cur.execute("UPDATE map_objects SET deleted=true, author_uid=%s WHERE id=%s AND world=%s AND NOT deleted", (AUTHOR, rid, WORLD))
    LOG["deleted_rows"].append(rid)
for rid, w, d, u, why in row_updates:
    cur.execute("SELECT x,y,z,vdir_x,vdir_y,vdir_z,vup_x,vup_y,vup_z FROM map_objects WHERE id=%s", (rid,)); old = [float(v) for v in cur.fetchone()]
    cur.execute("UPDATE map_objects SET x=%s,y=%s,z=%s,vdir_x=%s,vdir_y=%s,vdir_z=%s,vup_x=%s,vup_y=%s,vup_z=%s,author_uid=%s WHERE id=%s AND world=%s",
                (w[0], w[1], w[2], d[0], d[1], d[2], u[0], u[1], u[2], AUTHOR, rid, WORLD))
    LOG["updated_rows"].append({"id": rid, "old": old, "why": why})
for cols in row_inserts:
    cur.execute("INSERT INTO map_objects (%s) VALUES (%s) RETURNING id" % (", ".join(cols), ", ".join(["%s"] * len(cols))), tuple(cols.values()))
    LOG["inserted_rows"].append(cur.fetchone()[0])
conn.commit(); print("table: %d soft-deleted, %d updated, %d inserted" % (len(LOG["deleted_rows"]), len(LOG["updated_rows"]), len(LOG["inserted_rows"])))

# ---- shipped sqm: delete entities by id, renumbering ItemN inside each touched Entities block
s = open(SHIP).read()
def entity_block(text, eid):
    m = re.search(r"\n(\t+)id=%d;\n" % eid, text)
    if not m: raise KeyError(eid)
    d = len(m.group(1))
    hdr = re.compile(r"\n" + "\t" * (d - 1) + r"class Item(\d+)\n" + "\t" * (d - 1) + r"\{\n")
    last = None
    for h in hdr.finditer(text, 0, m.start() + 1): last = h
    start = last.start()                       # the newline before "class ItemN"
    brace = text.index("{", last.end() - 2)
    end = sqm_splice._scan(text, brace + 1)    # offset of matching "}"
    assert text[end:end + 2] == "};"
    end += 2
    # parent Entities header (depth d-2)
    ph = re.compile(r"\n" + "\t" * (d - 2) + r"class Entities\n" + "\t" * (d - 2) + r"\{\n")
    par = None
    for h in ph.finditer(text, 0, start + 1): par = h
    pstart = par.start(); pbrace = text.index("{", par.end() - 2); pend = sqm_splice._scan(text, pbrace + 1)
    assert pend > end, "parent does not enclose entity"
    return start, end, pstart, d
def renumber_entities(text, pstart, d):
    pbrace = text.index("{", pstart + 1); pend = sqm_splice._scan(text, pbrace + 1)
    body = text[pbrace + 1:pend]
    hdr = re.compile(r"(\n" + "\t" * (d - 1) + r"class Item)(\d+)(\n" + "\t" * (d - 1) + r"\{\n)")
    n = [0]
    def sub(m): r = "%s%d%s" % (m.group(1), n[0], m.group(3)); n[0] += 1; return r
    body2 = hdr.sub(sub, body)
    body2, k = re.subn(r"(\n" + "\t" * (d - 1) + r"items=)\d+;", lambda m: "%s%d;" % (m.group(1), n[0]), body2, 1)
    assert k == 1, "items= not found in parent Entities"
    return text[:pbrace + 1] + body2 + text[pend:], n[0]
blocks = []
for eid in sqm_deletes:
    st, en, ps, d = entity_block(s, eid); blocks.append((ps, st, en, d, eid))
parents = collections.defaultdict(list)
for ps, st, en, d, eid in blocks: parents[(ps, d)].append((st, en, eid))
for (ps, d), lst in sorted(parents.items(), key=lambda kv: -kv[0][0]):      # deepest/latest parent first
    for st, en, eid in sorted(lst, key=lambda t: -t[0]):
        s = s[:st] + s[en:]; LOG["sqm_deleted_ids"].append(eid)
    s, cnt = renumber_entities(s, ps, d)
    print("  Entities block @%d: removed %d, renumbered to %d items" % (ps, len(lst), cnt))
sqm_read._parse_text(s)
open(SHIP, "w").write(s)
ids_after = set(sqm_read.entity_ids(SHIP))
assert ids_after == ship_ids - set(sqm_deletes), "delete pass changed the wrong ids"
print("shipped sqm: %d entities deleted, parse OK" % len(sqm_deletes))

# ---- marker moves (same logic as map_codegen.update_moved_markers, restricted by name)
s = open(SHIP).read()
for nm in marker_moves:
    p = del_markers[nm]["node"]["props"]; cur_p = ship_markers[nm]
    i = s.index('name="%s"' % nm); start = s.rindex("class Item", 0, i); end = sqm_splice._scan(s, s.index("{", start) + 1)
    block = s[start:end]
    block = re.sub(r"position\[\]=\{[^}]*\};", "position[]=%s;" % map_codegen._fmt_val([float(v) for v in p["position"]]), block, 1)
    if "angle=" in block: block = re.sub(r"angle=[^;]*;", "angle=%s;" % map_codegen._fmt_val(float(p.get("angle", 0))), block, 1)
    elif p.get("angle") is not None: block = block.replace("name=", "angle=%s;\n\t\t\tname=" % map_codegen._fmt_val(float(p["angle"])), 1)
    s = s[:start] + block + s[end:]
    LOG["sqm_moved_markers"].append({"name": nm, "old": cur_p.get("position"), "new": p["position"]})
    print("  marker %s: %s -> %s" % (nm, [round(float(v), 1) for v in cur_p["position"]], [round(float(v), 1) for v in p["position"]]))
sqm_read._parse_text(s); open(SHIP, "w").write(s)

# ---- new markers (renamed pads) + new modules, spliced as root items
s = open(SHIP).read()
new_marker_props = []
for old, new in rename_pads.items():
    p = dict(del_markers[old]["node"]["props"]); p["name"] = new; p["text"] = ""      # the class was only in text
    new_marker_props.append(p)
n_new = len(new_marker_props) + len(new_logic)
base, _ = sqm_splice.item_id_provider(s); s = sqm_splice.set_next_id(s, base + n_new)
n_items, _, _ = sqm_splice.find_mission_entities(s)
blocks = [map_codegen._emit_marker(p, n_items + k, base + k) for k, p in enumerate(new_marker_props)]
blocks += [map_codegen._emit_node(n, n_items + len(blocks) + k, base + len(blocks) + k) for k, n in enumerate(new_logic)]
s = sqm_splice.splice_layers(s, blocks); open(SHIP, "w").write(s)
final_ids = set(sqm_read.entity_ids(SHIP))
assert len(final_ids) == len(ids_after) + n_new and ids_after <= final_ids, "splice id check failed"
LOG["sqm_new_markers"] = list(rename_pads.values()); LOG["sqm_new_modules"] = [n["props"].get("type") for n in new_logic]
print("shipped sqm: +%d markers %s, +%d modules; entities %d -> %d" % (len(new_marker_props), list(rename_pads.values()), len(new_logic), len(ship_ids), len(final_ids)))
LOG["backup"] = bak
lp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "undo_%s.json" % stamp)
json.dump(LOG, open(lp, "w"), indent=1, default=str); print("undo log:", lp)
