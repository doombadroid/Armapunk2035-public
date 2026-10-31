#!/usr/bin/env python3
"""The map pipeline: map_objects rows <-> a generated 3DEN edit mission. See mapedit.md, mapdb.md.

    ~/pysqf-venv/bin/python tools/map_codegen.py stage   # build MaldenEdit.Malden/mission.sqm from the table
    tools/edit-map.sh push                                # write the edits back BY ID (tools/map_push.py)

`apply` is retired (mapdb.md D7): it rewrote fn_mapData.sqf and custom_p3ds/malden_buildings.sqf,
and neither exists any more -- the table is the only source of placed objects. Every entity this
stages carries AP_ID=<table id> in its description, in BOTH layers (AP_MAPDATA class rows and
AP_CUSTOM_P3D model anchors), which is what lets push diff the editor against the table exactly.

MaldenEdit.Malden is GENERATED and NEVER PACKED. That is the whole safety argument: the shipped
mission.sqm never gains code-spawned content, so it cannot ship them twice -- once as engine
entities and once from the table. Stripping them at pack time would work too, but its failure
mode is a silent double-spawn of 9,000+ objects, and this repo has shipped that class of damage
twice already.
"""
import math
import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apdb_dsn        # stdlib until connect(): psycopg is imported lazily, so `python3` can still import this
import sqm_frame
import sqm_read
import sqm_splice

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MISSION = os.path.join(REPO, "mission", "Armapunk2035.Malden")
SHIPPED_SQM = os.path.join(MISSION, "mission.sqm")
EDIT_DIR = os.environ.get(
    "AP_EDIT_MISSION",
    os.path.expanduser("~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/"
                       "steamuser/Documents/Arma 3/mpmissions/MaldenEdit.Malden"))

LAYER_MAPDATA = "AP_MAPDATA"
LAYER_P3D = "AP_CUSTOM_P3D"
# Entity ids are allocated from the sqm's OWN EditorData >> ItemIDProvider >> nextID and it is
# bumped by the number of entities added, which is exactly what 3DEN does when you place something.
# A fixed "reserved band" high above nextID looks safer and is not: 3DEN refuses to load a scenario
# whose entities are numbered past its own allocator, which presents simply as "error when loading
# the scenario" with nothing in the RPT. Bisecting a 10-object layer against an untouched copy is
# what found it.
STAGE_META = "AP_stage.txt"      # records the id base so apply can match rows back

# A PERSON CANNOT BE A PLAIN sqm OBJECT.
#
# In a .sqm, a character belongs inside a dataType="Group"; emitting one as a standalone
# dataType="Object" with side="Empty" makes 3DEN refuse the whole scenario ("error when loading").
# The shop NPCs are 61 of the 8,717 rows and the first row in the layer is one of them, so this is
# not an edge case -- it stops the mission opening at all.
#
# They also must NOT become real Eden units even if that worked: an Eden-placed unit is one
# server-owned AI, while a shop NPC has to be a client-local row so every player instantiates
# their own copy and a scroll-wheel addAction works on it (see the repo's own edenNPC tooling).
#
# So a person is staged as a draggable Land_HelipadEmpty_F anchor carrying its real class in the
# description, which is exactly the trick already used for the custom .p3d buildings. The anchor
# renders as nothing, so use edenCB_refresh.sqf / edenNPC_refresh.sqf to draw the models.
ANCHOR_CLASS = "Land_HelipadEmpty_F"

# LIGHT-EMITTING classes. A simple object does not run built-in lights (BIKI, createSimpleObject:
# "Unsupported features include ... built-in lights"), and the array spawns init-less rows as
# simple objects -- so a lamp placed like any other prop comes out DARK. A row on this list with
# no init gets `_this switchLight 'ON';`, which does two jobs at once: a non-empty init makes the
# loader use createVehicleLocal (a real local object, lights functional, still zero network), and
# switchLight ON keeps a store lit in daytime too. Prefix allowlist, not a regex: Land_Cargo20_
# _light_blue_F is a container colour, not a light.
LIGHT_PREFIXES = ("Land_LampStreet", "Land_LampHalogen_F", "Land_LampHarbour",
                  "Land_LampDecor", "Land_LampShabby", "Land_LampSolar", "Land_LampAirport",
                  "Land_LampIndustrial", "Land_PortableLight", "Land_FloodLight",
                  "Land_runway_edgelight", "Land_NavigLight")


def is_light(cls):
    return cls.startswith(LIGHT_PREFIXES) and "_off_" not in cls
PERSON = re.compile(
    r"^(C_[Mm]an|C_Orestes|C_Nikos|C_Journalist|C_Marshal|C_Driver|C_Scientist"
    r"|B_Captain|B_T_Diver|O_Survivor"
    r"|[BOI]_\w*(Soldier|Diver|Survivor|Captain|Officer|Crew|Pilot|Medic|Engineer|Recon|Sniper))")


def is_person(cls):
    return bool(PERSON.match(cls))


def _tokens(desc):
    return [t for t in desc.split("|") if t]


def _anchor_name(e, i):
    """A findable, unique variable name for an anchor entity, or "" for an ordinary prop."""
    toks = _tokens(e.get("desc", ""))
    for tk in toks:
        if tk.startswith("AP_NPC="):
            return "AP_npc_%d" % i
        if tk.startswith("AP_P3D="):
            safe = re.sub(r"\W", "_", tk[8:])
            return "AP_bld_%d_%s" % (i, safe)
    return ""


def _q(s):
    """Quote for a .sqm string: a literal quote is doubled, never backslash-escaped.

    A config string CANNOT contain a literal newline. Arma writes a multi-line value as quoted
    segments joined by an unquoted ` \\n `, and so does this. Emitting the raw newline instead
    kills the config parser mid-file, and because it then discards everything after that point
    the editor silently opens a TRUNCATED mission -- which is exactly what the first real
    staging did, cutting the map layer off at the first of the four two-line NPC inits.
    """
    esc = s.replace('"', '""')
    if "\n" not in esc:
        return '"%s"' % esc
    return " \\n ".join('"%s"' % part for part in esc.split("\n"))


def build_layer(name, entities, first_id, item_index):
    """One `class ItemN` Layer block holding `entities`, ready to splice as a root item.

    item_index is passed in rather than left as a %d in the returned text: init strings are full
    of format ["%1 ..."], so deferring the substitution would raise -- or worse, silently mangle
    an NPC's shop logic -- on the first row carrying one.
    """
    t = "\t"
    out = []
    layer_id = first_id
    out.append('%sclass Item%d\n%s{\n' % (t * 2, item_index, t * 2))
    out.append('%sdataType="Layer";\n' % (t * 3))
    out.append('%sname=%s;\n' % (t * 3, _q(name)))
    out.append('%sclass Entities\n%s{\n' % (t * 3, t * 3))
    out.append('%sitems=%d;\n' % (t * 4, len(entities)))
    for i, e in enumerate(entities):
        sx, sy, sz = sqm_frame.WORLD_TO_SQM_POS(e["world"])
        a0, a1, a2 = sqm_frame.vectors_to_angles(e["dir"], e["up"])
        out.append('%sclass Item%d\n%s{\n' % (t * 4, i, t * 4))
        out.append('%sdataType="Object";\n' % (t * 5))
        out.append('%sclass PositionInfo\n%s{\n' % (t * 5, t * 5))
        out.append('%sposition[]={%.4f,%.4f,%.4f};\n' % (t * 6, sx, sy, sz))
        out.append('%sangles[]={%.7f,%.7f,%.7f};\n' % (t * 6, a0, a1, a2))
        out.append('%s};\n' % (t * 5))
        out.append('%sside="Empty";\n' % (t * 5))
        out.append('%sflags=4;\n' % (t * 5))
        # EVERY Object carries a class Attributes, even an empty one. Measured, not assumed: the
        # shipped sqm has 4260 of 4260 (31 of them empty) and a file 3DEN wrote itself has
        # 4261 of 4261 (32 empty). Omitting it on the 8,643 rows with no init made 3DEN refuse the
        # scenario with a bare "error when loading" and nothing in the RPT.
        out.append('%sclass Attributes\n%s{\n' % (t * 5, t * 5))
        if e.get("init"):
            out.append('%sinit=%s;\n' % (t * 6, _q(e["init"])))
        if e.get("desc"):
            out.append('%sdescription=%s;\n' % (t * 6, _q(e["desc"])))
        # Name the ANCHORS. They render as nothing, so without a name they are anonymous
        # helipads in the entity list and there is no way to find the one you want. Props are
        # left unnamed: 8,656 generated names would be noise, and they are visible anyway.
        nm = _anchor_name(e, i)
        if nm:
            out.append('%sname=%s;\n' % (t * 6, _q(nm)))
        out.append('%s};\n' % (t * 5))
        out.append('%sid=%d;\n' % (t * 5, first_id + 1 + i))
        # a person is staged as an anchor; its real class rides in the description
        emit = ANCHOR_CLASS if any(x.startswith("AP_NPC=") for x in _tokens(e.get("desc", ""))) \
            else e["cls"]
        out.append('%stype=%s;\n' % (t * 5, _q(emit)))
        out.append('%s};\n' % (t * 4))
    out.append('%s};\n' % (t * 3))
    out.append('%sid=%d;\n' % (t * 3, layer_id))
    out.append('%satlOffset=0;\n' % (t * 3))   # all 34 designer layers carry one; match them
    out.append('%s};\n' % (t * 2))
    return "".join(out)


def model_name(path):
    """'custom_p3ds\\Bank.p3d' -> 'Bank': the AP_P3D= token is the model name without dir or ext.
    A built-in game model ('a3\\plants_f\\tree\\t_populusn3s_f.p3d', from the 2026-09-09 tree
    anchors) is not under custom_p3ds and keeps its whole path as the token; only a bare name
    means "one of ours"."""
    norm = path.replace("/", "\\")
    if not norm.lower().lstrip("\\").startswith("custom_p3ds\\"):
        return norm
    base = norm.rsplit("\\", 1)[-1]
    return base[:-4] if base.lower().endswith(".p3d") else base


def model_path(name):
    """The inverse of model_name: a bare name is custom_p3ds\\<Model>.p3d, anything with a path
    in it (a built-in game model) is used as it is."""
    if "\\" in name or "/" in name or name.lower().endswith(".p3d"):
        return name.replace("/", "\\")
    return "custom_p3ds\\%s.p3d" % name


def _db_fetch(world="Malden"):
    """(map_meta.rev, mapData entity dicts, custom-p3d anchor dicts) from ONE connection.

    The rev is read FIRST, the same order APS_fnc_mapLoad uses: a row written while the rows
    are being read then carries rev > staged_from_rev, and map_push refuses the stale staging
    instead of writing it back over the newer edit. That is the safe direction."""
    conn = apdb_dsn.connect()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT rev FROM map_meta WHERE world = %s", (world,))
            (rev,) = cur.fetchone()
            cur.execute("SELECT id, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z,"
                        " init, is_server, model, scale"
                        " FROM map_objects WHERE world = %s AND NOT deleted ORDER BY id", (world,))
            rows = cur.fetchall()
    finally:
        conn.close()
    ents, p3d = [], []
    for (rid, cls, x, y, z, dx, dy, dz, ux, uy, uz, init, srv, model, scale) in rows:
        world_pos = (float(x), float(y), float(z))
        vdir = (float(dx), float(dy), float(dz))
        vup = (float(ux), float(uy), float(uz))
        if model:
            # a model row is an ANCHOR: 3DEN can only place CfgVehicles classes, and these are raw
            # .p3d files inside the mission. Model and scale ride in the description, the field
            # 3DEN preserves verbatim; the orientation is the row's own frame (setVectorDirAndUp
            # at spawn), so a tilt pushed from the editor survives a re-stage.
            p3d.append({"cls": ANCHOR_CLASS, "world": world_pos, "dir": vdir, "up": vup, "init": "",
                        "desc": "AP_ID=%d|AP_P3D=%s|AP_SCALE=%s" % (rid, model_name(model), "%g" % float(scale)),
                        "ap_id": int(rid), "model": model, "scale": float(scale)})
            continue
        toks = ["AP_ID=%d" % rid]
        if is_person(cls):
            toks.append("AP_NPC=" + cls)
        if srv:
            toks.append("AP_SERVERSIDE")
        ents.append({"cls": cls, "world": world_pos, "dir": vdir, "up": vup,
                     "init": init, "desc": "|".join(toks), "ap_id": int(rid)})
    return int(rev), ents, p3d


def read_map_rev(world="Malden"):
    """map_meta.rev right now."""
    return _db_fetch(world)[0]


def read_mapdata_db(world="Malden"):
    """Live class rows of map_objects as entity dicts (the shape read_mapdata() returned from
    fn_mapData.sqf): cls, world, dir, up, init, desc (AP_ID= | AP_NPC= | AP_SERVERSIDE), ap_id."""
    return _db_fetch(world)[1]


def read_p3d_db(world="Malden"):
    """Live model rows of map_objects as anchor dicts (the shape parse_p3d() returned from
    malden_buildings.sqf): cls = the anchor class, world, dir, up, init "", desc
    (AP_ID= | AP_P3D=<Model> | AP_SCALE=<s>), plus ap_id, model (the row's path) and scale."""
    return _db_fetch(world)[2]


def assert_no_raw_newlines(text, path):
    """Fail if any quoted string in `text` contains a literal newline.

    This is the invariant the ENGINE enforces and Python does not. A raw newline inside a config
    string stops Arma's parser dead, and it then discards the rest of the file -- so the editor
    opens a silently truncated mission. Python's own reader is happy with it, so the generated
    file parsed, round-tripped and tested green while being unloadable; the only thing that
    caught it was opening the mission. Checking it here means the tool catches it instead.
    """
    i, n, line = 0, len(text), 1
    while i < n:
        ch = text[i]
        if ch == "\n":
            line += 1
        elif ch == '"':
            i += 1
            start = line
            while i < n:
                if text[i] == '"':
                    if i + 1 < n and text[i + 1] == '"':
                        i += 2
                        continue
                    break
                if text[i] == "\n":
                    sys.exit("ABORT: literal newline inside a string starting at line %d of %s.\n"
                             "       A .sqm config string cannot contain one -- it must be split "
                             "into segments joined by ` \\\\n `. Nothing was written." % (start, path))
                i += 1
        i += 1


def _sqm_digest(path):
    import hashlib
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def read_staged_rev():
    """staged_from_rev from AP_stage.txt, or -1 for a staging that predates the guard."""
    p = os.path.join(EDIT_DIR, STAGE_META)
    try:
        for line in open(p, encoding="utf-8"):
            if line.startswith("staged_from_rev="):
                return int(line.split("=", 1)[1].strip())
    except OSError:
        pass
    return -1


def read_staged_ids():
    """The table ids staged into the current edit mission, from AP_stage.txt. Empty if none."""
    p = os.path.join(EDIT_DIR, STAGE_META)
    try:
        for line in open(p, encoding="utf-8"):
            if line.startswith("ids="):
                return {int(t) for t in line[4:].strip().split(",") if t}
    except OSError:
        pass
    return set()


def _refuse_to_clobber(path):
    """Refuse to re-stage over edits 3DEN has saved but nobody has applied yet.

    stage() overwrites the edit mission wholesale. If someone has been dragging things around and
    saved, re-staging silently throws that work away with no warning and no copy -- the editor is
    the source of truth in this design, so its unapplied state is the ONLY place those edits exist.
    Staging records the digest of what it wrote; if the file no longer matches, 3DEN has saved
    over it and the edits must be applied (or deliberately discarded) first.
    """
    meta = os.path.join(EDIT_DIR, STAGE_META)
    if not (os.path.exists(path) and os.path.exists(meta)):
        return
    want = None
    for line in open(meta):
        if line.startswith("digest="):
            want = line.split("=", 1)[1].strip()
    if want and want != _sqm_digest(path):
        sys.exit(
            "ABORT: %s has been saved from 3DEN since it was staged, and those edits are not in\n"
            "       the code yet. Re-staging would discard them.\n\n"
            "       Keep them:     tools/edit-map.sh push\n"
            "       Discard them:  AP_FORCE_STAGE=1 tools/edit-map.sh\n" % path)


def _ensure_text(path):
    """Return a parseable TEXT path for the edit sqm, derapifying if 3DEN saved it binarized.

    2026-08-02: the owner's editor session (new mods incl. 3DEN Enhanced / Deformer) flipped the
    editor's save-binarized preference and MaldenEdit/mission.sqm arrived as raP binary; sqm_read
    only speaks text. The preference lives in the editor PROFILE, not the file, so any future save
    can regress -- the pipeline self-heals instead of relying on anyone remembering a checkbox.
    Digest bookkeeping stays on the ORIGINAL file (the thing 3DEN rewrites), never this temp.
    """
    with open(path, "rb") as f:
        magic = f.read(4)
    if magic != b"\x00raP":
        return path
    exe = shutil.which("armake2") or os.path.expanduser("~/.cargo/bin/armake2")
    if not os.path.exists(exe):
        sys.exit("ABORT: %s is BINARIZED (3DEN 'save binarized' preference) and armake2 is not\n"
                 "       available to derapify it. Install:\n"
                 "         cargo install --git https://github.com/KoffeinFlummi/armake2 --locked\n"
                 "       (or untick Save Binarized in 3DEN preferences and save again)." % path)
    out = path + ".derap.txt"
    import subprocess
    r = subprocess.run([exe, "derapify", path, out], capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(out):
        sys.exit("ABORT: armake2 derapify failed on %s:\n%s" % (path, (r.stderr or "")[-800:]))
    print("  note: edit sqm was BINARIZED (3DEN preference) -- derapified to %s" % out)
    return out


def stage():
    # rev first, rows second (see _db_fetch): staged_from_rev is what map_push's staleness
    # guard compares the table against.
    rev, ents, p3d = _db_fetch()
    if not ents:
        sys.exit("ABORT: map_objects has no live class rows -- refusing to stage an empty map")
    check_frames(ents, "mapData")
    check_frames(p3d, LAYER_P3D)
    src = open(SHIPPED_SQM).read()
    id_base, _ = sqm_splice.item_id_provider(src)
    # one id for the layer itself plus one per entity
    src = sqm_splice.set_next_id(src, id_base + 2 + len(ents) + len(p3d))
    n_items, _, _ = sqm_splice.find_mission_entities(src)
    block = build_layer(LAYER_MAPDATA, ents, id_base, n_items)
    p3d_base = id_base + 1 + len(ents)
    block2 = build_layer(LAYER_P3D, p3d, p3d_base, n_items + 1)
    out = sqm_splice.splice_layers(src, [block, block2])

    # Everything except mission.sqm is SYMLINKED, not copied. description.ext #includes files in
    # subdirectories (dialog\MasterHandler.h, core\chatcom\..., and more), so a top-level file copy
    # opens in 3DEN with every include broken; and a deep copy would be a stale second copy of the
    # mission that silently drifts. Symlinks also match how the real mpmissions entries already
    # point at this repo. Only mission.sqm is a real file here, and it is the only thing 3DEN writes.
    os.makedirs(EDIT_DIR, exist_ok=True)
    for fname in os.listdir(MISSION):
        if fname == "mission.sqm":
            continue
        link = os.path.join(EDIT_DIR, fname)
        if os.path.islink(link):
            os.unlink(link)
        elif os.path.isdir(link):
            shutil.rmtree(link)
        elif os.path.exists(link):
            os.unlink(link)
        os.symlink(os.path.join(MISSION, fname), link)
    path = os.path.join(EDIT_DIR, "mission.sqm")
    if not os.environ.get("AP_FORCE_STAGE"):
        _refuse_to_clobber(path)
    open(path, "w").write(out)
    # ids= is the list of table ids this staging put into the edit mission -- BOTH layers, class
    # rows and model anchors alike. map_push deletes ONLY an id that was staged and is now absent
    # -- an id that was never staged into this edit mission (added in-game after staging, say)
    # is never touched.
    open(os.path.join(EDIT_DIR, STAGE_META), "w").write(
        "id_base=%d\nrows=%d\np3d_base=%d\np3d_rows=%d\ndigest=%s\nids=%s\nstaged_from_rev=%d\n"
        % (id_base, len(ents), p3d_base, len(p3d), _sqm_digest(path),
           ",".join(str(e["ap_id"]) for e in ents + p3d if e.get("ap_id")),
           rev))

    assert_no_raw_newlines(out, path)

    ids_before = set(sqm_read.entity_ids(SHIPPED_SQM))
    ids_after = set(sqm_read.entity_ids(path))
    added = ids_after - ids_before
    expected = len(ents) + len(p3d) + 2          # every entity, plus one id per layer
    if len(added) != expected:
        sys.exit("ABORT: expected %d new ids, got %d" % (expected, len(added)))
    if ids_before - ids_after:
        sys.exit("ABORT: staging lost %d designer ids" % len(ids_before - ids_after))
    npcs = sum(1 for e in ents if is_person(e["cls"]))
    print("staged %d mapData rows into %s (map_objects rev %d)" % (len(ents), path, rev))
    print("  entity ids %d..%d, nextID bumped to %d"
          % (id_base, id_base + 1 + len(ents) + len(p3d), id_base + 2 + len(ents) + len(p3d)))
    print("  %d of them are people, staged as %s anchors" % (npcs, ANCHOR_CLASS))
    print("  %d custom .p3d placements staged as anchors in %s, each carrying its AP_ID" % (len(p3d), LAYER_P3D))
    print("designer entities preserved: %d" % len(ids_before))
    return path


def read_layer(sqm_path, name):
    """Every Object directly inside the named layer, as entity dicts in file order."""
    root = sqm_read.parse(sqm_path)
    for node in sqm_read.walk(root):
        p = node["props"]
        if p.get("dataType") != "Layer" or p.get("name") != name:
            continue
        ents = []
        holder = node["subs"].get("Entities")
        if not holder:
            return ents
        for key in sorted(holder["subs"], key=lambda k: int(k[4:]) if k[4:].isdigit() else 0):
            n = holder["subs"][key]
            q = n["props"]
            if q.get("dataType") != "Object":
                continue
            pi = n["subs"]["PositionInfo"]["props"]
            d, u = sqm_frame.angles_to_vectors(
                [float(v) for v in pi.get("angles", [0, 0, 0])])
            attrs = n["subs"].get("Attributes", {"props": {}})["props"]
            desc = attrs.get("description", "")
            npc = next((x[len("AP_NPC="):] for x in _tokens(desc) if x.startswith("AP_NPC=")), None)
            ap_id = next((int(x[len("AP_ID="):]) for x in _tokens(desc) if x.startswith("AP_ID=")), None)
            ents.append({"cls": npc or q["type"],
                         "ap_id": ap_id,
                         "world": sqm_frame.SQM_POS_TO_WORLD(
                             [float(v) for v in pi["position"]]),
                         "dir": d, "up": u,
                         "init": attrs.get("init", ""),
                         "desc": desc,
                         "id": q.get("id")})
        return ents
    return []


def warn_designer_drift(edit_path):
    """Report entities from the SHIPPED sqm that were moved, rotated or deleted in the editor.

    apply only reads the AP_* layers, so an edit to one of the designer's own entities is written
    to no file at all -- it lives on in the edit mission and nowhere else, and the next stage
    discards it. That silence is dangerous: the first real edit session moved and deleted three
    designer objects believing they were map-array rows, and nothing said otherwise.

    This does not fail. Designer content legitimately belongs to the designer and is changed by
    re-delivering mission.sqm; the point is that it must never happen invisibly.
    """
    # Only ids that existed when the mission was STAGED are designer content. After apply has
    # spliced new markers into the shipped sqm, both files allocate ids from overlapping ranges,
    # and comparing a freshly spliced shipped marker against an unrelated edit entity with the
    # same number produced phantom "moved" warnings on the second apply of a session.
    id_base = None
    meta = os.path.join(EDIT_DIR, STAGE_META)
    if os.path.exists(meta):
        for line in open(meta):
            if line.startswith("id_base="):
                id_base = int(line.split("=", 1)[1])
    ship = {}
    for n in sqm_read.walk(sqm_read.parse(SHIPPED_SQM)):
        i = n["props"].get("id")
        if isinstance(i, int) and (id_base is None or i < id_base):
            ship[i] = n
    edit = {}
    for n in sqm_read.walk(sqm_read.parse(edit_path)):
        i = n["props"].get("id")
        if isinstance(i, int):
            edit[i] = n

    deleted = sorted(set(ship) - set(edit))
    moved = []
    for i in sorted(set(ship) & set(edit)):
        if ship[i]["props"].get("dataType") == "Marker":
            continue          # marker moves are SYNCED by update_moved_markers now, not dropped
        pa = ship[i]["subs"].get("PositionInfo")
        pb = edit[i]["subs"].get("PositionInfo")
        if not pa or not pb:
            continue
        va = [float(x) for x in pa["props"].get("position", [0, 0, 0])]
        vb = [float(x) for x in pb["props"].get("position", [0, 0, 0])]
        ra = [float(x) for x in pa["props"].get("angles", [0, 0, 0])]
        rb = [float(x) for x in pb["props"].get("angles", [0, 0, 0])]
        if (max(abs(x - y) for x, y in zip(va, vb)) > 0.05
                or max(abs(x - y) for x, y in zip(ra, rb)) > 0.01):
            moved.append((i, ship[i]["props"].get("type")))
    if not deleted and not moved:
        return
    print("")
    print("  ** %d designer entities were edited. THOSE CHANGES ARE NOT BEING SAVED. **"
          % (len(deleted) + len(moved)))
    print("     apply only writes the AP_* layers; the designer's own entities live in the")
    print("     shipped mission.sqm and are changed by re-delivering it, not from here.")
    for i, ty in moved[:8]:
        print("       moved/rotated  id=%-6d %s" % (i, ty))
    for i in deleted[:8]:
        print("       deleted        id=%-6d %s" % (i, ship[i]["props"].get("type")))
    print("")


def read_p3d_anchors(sqm_path):
    """Every anchor whose description names a .p3d model, wherever it sits in the file.

    Deliberately NOT layer-scoped. 3DEN drops each placed Custom Composition into a layer of its
    own unless "Automatic Composition Layering" is off, so requiring AP_CUSTOM_P3D would silently
    ignore every building added the easy way. The description is the thing that actually identifies
    a placement, so that is what this matches on; the layer is organisation, not meaning.
    """
    ents = []
    for n in sqm_read.walk(sqm_read.parse(sqm_path)):
        q = n["props"]
        if q.get("dataType") != "Object":
            continue
        attrs = n["subs"].get("Attributes", {"props": {}})["props"]
        desc = attrs.get("description", "")
        if not any(t.startswith("AP_P3D=") for t in _tokens(desc)):
            continue
        pi = n["subs"]["PositionInfo"]["props"]
        d, u = sqm_frame.angles_to_vectors([float(v) for v in pi.get("angles", [0, 0, 0])])
        ap_id = next((int(x[len("AP_ID="):]) for x in _tokens(desc) if x.startswith("AP_ID=")), None)
        ents.append({"cls": q["type"],
                     "ap_id": ap_id,
                     "world": sqm_frame.SQM_POS_TO_WORLD([float(v) for v in pi["position"]]),
                     "dir": d, "up": u, "init": attrs.get("init", ""),
                     "desc": desc, "id": q.get("id")})
    return ents


def new_content_outside_layers(sqm_path, exclude_ids, ship_ids):
    """Objects ADDED in the editor that sit outside the PLB layers -- dragged from the vanilla
    asset browser or dropped as a Custom Composition and left wherever 3DEN put them.

    This is not an edge case, it is the MAIN path: 3DEN gives every placed composition a fresh
    layer of its own (unless "Automatic Composition Layering" is off), so the easy way of adding
    an NPC or prop never lands inside AP_MAPDATA. Requiring the layer would silently discard
    exactly the placements the composition workflow exists to enable.

    New = an Object whose id is neither in the shipped sqm (designer content), nor already counted
    (exclude_ids: the staged layer's rows), skipping AP_P3D anchors (handled by
    read_p3d_anchors) and anything inside a Group -- a unit placed from the asset browser is a
    Group wrapping an Object, and a real AI unit is mission content, not a map row.
    """
    out = []

    def rec(node, in_group):
        p = node["props"]
        dt = p.get("dataType")
        ing = in_group or dt == "Group"
        if dt == "Object" and not ing:
            i = p.get("id")
            if isinstance(i, int) and i not in ship_ids and i not in exclude_ids:
                attrs = node["subs"].get("Attributes", {"props": {}})["props"]
                desc = attrs.get("description", "")
                toks = _tokens(desc)
                pi = node["subs"].get("PositionInfo")
                if pi and not any(t.startswith("AP_P3D=") for t in toks):
                    d, u = sqm_frame.angles_to_vectors(
                        [float(v) for v in pi["props"].get("angles", [0, 0, 0])])
                    npc = next((t[len("AP_NPC="):] for t in toks if t.startswith("AP_NPC=")), None)
                    out.append({"cls": npc or p["type"],
                                "world": sqm_frame.SQM_POS_TO_WORLD(
                                    [float(v) for v in pi["props"]["position"]]),
                                "dir": d, "up": u, "init": attrs.get("init", ""),
                                "desc": desc, "id": i})
        for c in node["subs"].values():
            rec(c, ing)

    rec(sqm_read.parse(sqm_path), False)
    return out


def _fmt_val(v):
    if isinstance(v, str):
        return _q(v)
    if isinstance(v, list):
        return "{%s}" % ",".join(_fmt_val(x) for x in v)
    if isinstance(v, float):
        return ("%.10g" % v)
    return str(v)


def _emit_node(node, item_index, new_id, indent=2):
    """A full `class ItemN` block from any parsed node -- props, nested subclasses, arrays, the
    lot -- with only the id rewritten. This is what lets MODULES round-trip: a
    ModuleHideTerrainObjects_F carries PositionInfo plus a CustomAttributes tree three classes
    deep, and a flat props-only emitter would silently strip the attributes that make the module
    do anything."""
    t = "\t" * indent
    out = ["%sclass Item%d\n%s{\n" % (t, item_index, t)]

    def rec(n, depth):
        ti = "\t" * depth
        for k, v in n["props"].items():
            if depth == indent + 1 and k == "id":
                continue
            if isinstance(v, list):
                out.append("%s%s[]=%s;\n" % (ti, k, _fmt_val(v)))
            else:
                out.append("%s%s=%s;\n" % (ti, k, _fmt_val(v)))
        for name, sub in n["subs"].items():
            out.append("%sclass %s\n%s{\n" % (ti, name, ti))
            rec(sub, depth + 1)
            out.append("%s};\n" % ti)

    rec(node, indent + 1)
    out.append("%sid=%d;\n" % ("\t" * (indent + 1), new_id))
    out.append("%s};\n" % t)
    return "".join(out)


def _emit_marker(props, item_index, new_id):
    """One root `class ItemN` Marker block from a parsed marker's props, verbatim except the id.

    Generic on purpose: props are re-emitted in their original order, so whatever fields the
    editor wrote (angle, shape, a/b, colorName, text, atlOffset...) survive without this code
    having to know the full marker schema.
    """
    t = "\t"
    out = ['%sclass Item%d\n%s{\n' % (t * 2, item_index, t * 2)]
    for k, v in props.items():
        if k == "id":
            continue
        if isinstance(v, list):
            out.append('%s%s[]={%s};\n' % (t * 3, k, ",".join(str(x) for x in v)))
        elif isinstance(v, str):
            out.append('%s%s=%s;\n' % (t * 3, k, _q(v)))
        else:
            out.append('%s%s=%s;\n' % (t * 3, k, v))
    out.append('%sid=%d;\n' % (t * 3, new_id))
    out.append('%s};\n' % (t * 2))
    return "".join(out)


def _markers_in(sqm_path):
    """[(props, nearest enclosing layer id or None)] for every Marker in the file."""
    out = []

    def rec(node, lkey):
        p = node["props"]
        if p.get("dataType") == "Layer":
            lkey = p.get("id")
        elif p.get("dataType") == "Marker":
            out.append((p, lkey))
        for c in node["subs"].values():
            rec(c, lkey)

    rec(sqm_read.parse(sqm_path), None)
    return out


def _object_layers(sqm_path):
    """object id -> nearest enclosing layer id (None at root)."""
    out = {}

    def rec(node, lkey):
        p = node["props"]
        if p.get("dataType") == "Layer":
            lkey = p.get("id")
        elif p.get("dataType") == "Object" and isinstance(p.get("id"), int):
            out[p["id"]] = lkey
        for c in node["subs"].values():
            rec(c, lkey)

    rec(sqm_read.parse(sqm_path), None)
    return out


def autowire_spawns(ents, edit_path, ship_ids):
    """Fill each 'SETME' spawn-marker list from the NEW markers dropped in the same layer.

    The garage compositions ship NPC + spawn-pad markers together, and 3DEN puts each placed
    composition into a layer of its own -- so "the markers that arrived with this NPC" IS the
    layer, and the editor's own auto-renaming of duplicate marker names is irrelevant because
    the ACTUAL names are read back here. Only NEW markers count: with composition layering off
    everything lands in one layer, and designer markers must never be swept into an init.
    """
    by_layer = {}
    for props, lkey in _markers_in(edit_path):
        if isinstance(props.get("id"), int) and props["id"] not in ship_ids:
            by_layer.setdefault(lkey, []).append(str(props.get("name", "")))
    obj_layer = _object_layers(edit_path)
    wired = 0
    for e in ents:
        if "'SETME'" not in e.get("init", ""):
            continue
        names = sorted(n for n in by_layer.get(obj_layer.get(e.get("id")), []) if n)
        if not names:
            continue
        e["init"] = e["init"].replace(
            "['SETME']", "[%s]" % ",".join("'%s'" % n for n in names))
        wired += 1
        print("  wired %s at %.1f, %.1f -> spawns %s"
              % (e["cls"], e["world"][0], e["world"][1], names))
    return wired


def sync_new_markers(edit_path):
    """Copy markers ADDED in the editor into the SHIPPED mission.sqm.

    Markers belong in the shipped sqm -- that is the standing rule, and it is where every
    consumer (getMarkerPos in the garage code, spawn selection, the map) reads them from. The
    edit mission is generated and never packed, so a marker left only there would vanish on the
    next stage. Identity is by NAME (marker names are globally unique and are what the inits
    reference), so a marker whose name the shipped file already has is never spliced twice.
    """
    ship_ids = set(sqm_read.entity_ids(SHIPPED_SQM))
    ship_names = {str(p.get("name", "")) for p, _ in _markers_in(SHIPPED_SQM)}
    new = [p for p, _ in _markers_in(edit_path)
           if isinstance(p.get("id"), int) and p["id"] not in ship_ids
           and str(p.get("name", "")) and str(p.get("name", "")) not in ship_names]
    if not new:
        return 0
    src = open(SHIPPED_SQM).read()
    base, _ = sqm_splice.item_id_provider(src)
    src = sqm_splice.set_next_id(src, base + len(new))
    n_items, _, _ = sqm_splice.find_mission_entities(src)
    blocks = [_emit_marker(p, n_items + i, base + i) for i, p in enumerate(new)]
    out = sqm_splice.splice_layers(src, blocks)
    shutil.copy(SHIPPED_SQM, SHIPPED_SQM + ".bak")
    open(SHIPPED_SQM, "w").write(out)
    after = set(sqm_read.entity_ids(SHIPPED_SQM))
    if len(after) != len(ship_ids) + len(new) or (ship_ids - after):
        sys.exit("ABORT: marker splice into the shipped sqm did not add exactly %d ids -- "
                 "restore from %s.bak" % (len(new), SHIPPED_SQM))
    for p in new:
        print("  marker '%s' -> shipped mission.sqm" % p.get("name"))
    return len(new)


def _nodes_in(sqm_path, data_type):
    out = []

    def rec(node, in_group):
        p = node["props"]
        ing = in_group or p.get("dataType") == "Group"
        if p.get("dataType") == data_type and not ing:
            out.append(node)
        for c in node["subs"].values():
            rec(c, ing)

    rec(sqm_read.parse(sqm_path), False)
    return out


def _node_pos(node):
    pi = node["subs"].get("PositionInfo")
    if pi and pi["props"].get("position"):
        v = pi["props"]["position"]
    else:
        v = node["props"].get("position", [0, 0, 0])
    return float(v[0]), float(v[2])


def sync_new_logics(edit_path):
    """Copy MODULES placed in the editor into the shipped mission.sqm.

    Terrain-clearing (Hide/Edit Terrain Objects) and every other module is a dataType="Logic"
    entity that only does anything as a real mission entity -- the map array cannot express it,
    and until this existed a placed module was silently ignored, which is how a cleared compound
    stayed full of bushes. Dedup is by (type, position within 1 m): modules have no names, and a
    stale-session re-save must not stack a second copy of every module.
    """
    ship_ids = set(sqm_read.entity_ids(SHIPPED_SQM))
    have = [(n["props"].get("type"), _node_pos(n)) for n in _nodes_in(SHIPPED_SQM, "Logic")]

    def dup(ty, xy):
        return any(t == ty and abs(x - xy[0]) < 1 and abs(y - xy[1]) < 1 for t, (x, y) in have)

    new = [n for n in _nodes_in(edit_path, "Logic")
           if isinstance(n["props"].get("id"), int) and n["props"]["id"] not in ship_ids
           and not dup(n["props"].get("type"), _node_pos(n))]
    if not new:
        return 0
    src = open(SHIPPED_SQM).read()
    base, _ = sqm_splice.item_id_provider(src)
    src = sqm_splice.set_next_id(src, base + len(new))
    n_items, _, _ = sqm_splice.find_mission_entities(src)
    blocks = [_emit_node(n, n_items + i, base + i) for i, n in enumerate(new)]
    out = sqm_splice.splice_layers(src, blocks)
    shutil.copy(SHIPPED_SQM, SHIPPED_SQM + ".bak")
    open(SHIPPED_SQM, "w").write(out)
    after = set(sqm_read.entity_ids(SHIPPED_SQM))
    if len(after) != len(ship_ids) + len(new) or (ship_ids - after):
        sys.exit("ABORT: module splice did not add exactly %d ids -- restore %s.bak"
                 % (len(new), SHIPPED_SQM))
    for n in new:
        x, y = _node_pos(n)
        print("  module %s at %.1f, %.1f -> shipped mission.sqm" % (n["props"].get("type"), x, y))
    return len(new)


def _emit_plain(name, node, indent=0):
    """Verbatim `class <name>` block from any parsed node. Scenario-attribute trees carry no
    entity ids, so this is _emit_node without the id surgery -- props and nested classes
    round-trip exactly (the Deformer heightfield string included)."""
    t = "\t" * indent
    out = ["%sclass %s\n%s{\n" % (t, name, t)]

    def rec(n, depth):
        ti = "\t" * depth
        for k, v in n["props"].items():
            if isinstance(v, list):
                out.append("%s%s[]=%s;\n" % (ti, k, _fmt_val(v)))
            else:
                out.append("%s%s=%s;\n" % (ti, k, _fmt_val(v)))
        for nm, sub in n["subs"].items():
            out.append("%sclass %s\n%s{\n" % (ti, nm, ti))
            rec(sub, depth + 1)
            out.append("%s};\n" % ti)

    rec(node, indent + 1)
    out.append("%s};\n" % t)
    return "".join(out)


def sync_scenario_attrs(edit_path):
    """Carry ROOT-level scenario CustomAttributes (Deformer terrain data et al) into the shipped sqm.

    The Deformer mod stores its whole heightfield in a mission attribute (GF_deformMission >>
    GF_deformString) and terrainDeform.sqf reads it back at runtime via getMissionConfigValue --
    so the block must ship, or every deformation exists only inside 3DEN. Sync is per-category by
    NAME: a category present in the editor save replaces the shipped copy wholesale (attribute
    edits are always whole-category saves), shipped-only categories are kept. The root block sits
    BEFORE `class Mission`; entity-level CustomAttributes live inside it and are never touched --
    guarded by asserting the located block starts before the Mission block.
    """
    edit_ca = sqm_read.parse(edit_path)["subs"].get("CustomAttributes")
    if not edit_ca or not edit_ca["subs"]:
        return 0
    src = open(SHIPPED_SQM).read()
    ship_ca = sqm_read.parse(SHIPPED_SQM)["subs"].get("CustomAttributes")
    keep = []
    if ship_ca:
        edit_names = {c["props"].get("name") for c in edit_ca["subs"].values()}
        keep = [c for c in ship_ca["subs"].values() if c["props"].get("name") not in edit_names]
    cats = keep + list(edit_ca["subs"].values())
    block = "class CustomAttributes\n{\n%s};\n" % "".join(
        _emit_plain("Category%d" % i, c, 1) for i, c in enumerate(cats))
    ids_before = set(sqm_read.entity_ids(SHIPPED_SQM))
    m_idx = src.index("class Mission")
    if ship_ca:
        i = src.index("class CustomAttributes")
        if i >= m_idx:
            sys.exit("ABORT: root CustomAttributes not found before class Mission -- refusing to "
                     "touch an entity-level block. Nothing was written.")
        close = sqm_splice._scan(src, src.index("{", i) + 1)
        end = close + 2 if src[close + 1:close + 2] == ";" else close + 1
        if src[end:end + 1] == "\n":
            end += 1
        out = src[:i] + block + src[end:]
    else:
        out = src[:m_idx] + block + src[m_idx:]
    shutil.copy(SHIPPED_SQM, SHIPPED_SQM + ".bak")
    open(SHIPPED_SQM, "w").write(out)
    after = set(sqm_read.entity_ids(SHIPPED_SQM))
    if after != ids_before:
        sys.exit("ABORT: scenario-attribute splice changed entity ids -- restore from %s.bak"
                 % SHIPPED_SQM)
    for c in cats:
        print("  scenario attributes '%s' -> shipped mission.sqm" % c["props"].get("name"))
    return len(cats)


def update_moved_markers(edit_path):
    """Carry MOVES of already-synced markers into the shipped sqm.

    sync_new_markers dedupes by name, which is correct for creation and wrong for edits: raising
    air_spawn_1 to a rooftop was silently dropped because the name already existed, and the next
    helicopter spawned at ground level inside the building. A NEW-id marker whose name the shipped
    file already has is that marker moved, so its position, angle and atlOffset are patched onto
    the shipped copy in place (same id, same everything else).
    """
    ship = {str(p.get("name", "")): p for p, _ in _markers_in(SHIPPED_SQM)}
    ship_by_id = {p.get("id"): p for p, _ in _markers_in(SHIPPED_SQM) if isinstance(p.get("id"), int)}
    ship_ids = set(sqm_read.entity_ids(SHIPPED_SQM))
    moved = []
    for p, _ in _markers_in(edit_path):
        nm = str(p.get("name", ""))
        if not nm or not isinstance(p.get("id"), int):
            continue
        # FRESH session: ids line up, so an edited marker arrives with the SAME id as the shipped
        # copy. The first version only handled the stale-session case (new id, existing name), so a
        # rooftop raise made in a clean session was dropped all over again -- with a polite drift
        # warning instead of a sync. Same id and same name are both just "this marker, moved".
        cur = ship_by_id.get(p["id"]) if p["id"] in ship_ids else ship.get(nm)
        if not cur or str(cur.get("name", "")) != nm:
            continue
        dx = abs(float(cur["position"][0]) - float(p["position"][0]))
        dz = abs(float(cur["position"][1]) - float(p["position"][1]))
        dy = abs(float(cur["position"][2]) - float(p["position"][2]))
        da = abs(float(cur.get("angle", 0)) - float(p.get("angle", 0)))
        if max(dx, dy, dz) < 0.05 and da < 0.5:
            continue
        moved.append((nm, p))
    if not moved:
        return 0
    s = open(SHIPPED_SQM).read()
    for nm, p in moved:
        i = s.index('name="%s"' % nm)
        start = s.rindex("class Item", 0, i)
        end = sqm_splice._scan(s, s.index("{", start) + 1)
        block = s[start:end]
        block = re.sub(r"position\[\]=\{[^}]*\};",
                       "position[]=%s;" % _fmt_val([float(v) for v in p["position"]]), block, 1)
        if "angle=" in block:
            block = re.sub(r"angle=[^;]*;", "angle=%s;" % _fmt_val(float(p.get("angle", 0))),
                           block, 1)
        elif p.get("angle") is not None:
            block = block.replace("name=", "angle=%s;\n\t\t\tname=" % _fmt_val(float(p["angle"])), 1)
        if "atlOffset=" in block and p.get("atlOffset") is not None:
            block = re.sub(r"atlOffset=[^;]*;", "atlOffset=%s;" % _fmt_val(float(p["atlOffset"])),
                           block, 1)
        s = s[:start] + block + s[end:]
        print("  marker '%s' moved -> %.1f, %.1f (z %.2f) in shipped mission.sqm"
              % (nm, float(p["position"][0]), float(p["position"][2]), float(p["position"][1])))
    shutil.copy(SHIPPED_SQM, SHIPPED_SQM + ".bak")
    open(SHIPPED_SQM, "w").write(s)
    sqm_read.parse(SHIPPED_SQM)
    return len(moved)


def apply(allow_deletes=False):
    """Retired 2026-09-04 (mapdb.md D7). apply rewrote fn_mapData.sqf and
    custom_p3ds/malden_buildings.sqf; neither exists -- the table is the only source of placed
    objects, and the editor's last mile is `tools/edit-map.sh push` (tools/map_push.py), which
    diffs both layers against map_objects by id. The shipped-sqm helpers below (marker, module
    and scenario-attribute sync, spawn autowiring, dezfight) are kept for push to adopt."""
    sys.exit("apply is retired: use push (mapdb.md D7)")


_SURF_RE = re.compile(r'CobblestoneSquare|Sidewalk|Tarmac|Pavement|ConcreteSlab|ConcreteTile|'
                      r'AsphaltSquare|WoodenFloor|Land_Concrete_\d', re.I)


def _surf_dims(cls):
    """Approx footprint (length, width) for flat SURFACE-PLATE classes; None = not a plate."""
    if not _SURF_RE.search(cls):
        return None
    m = re.search(r'_(\d+)m', cls)
    size = float(m.group(1)) if m else 2.4
    if 'Sidewalk' in cls:
        return (size, 1.2 if 'narrow' in cls else 2.4)
    return (size, size)


def dezfight(ents):
    """Separate coplanar overlapping surface plates so they stop z-fighting ("rapidly blinking").

    Designers tile plaza compounds from Cobblestone/Sidewalk plates and overlaps land within
    millimetres of each other -- the ER HQ plaza flickered at view distance (owner 2026-08-02).
    For every pair of plates whose ORIENTED footprints genuinely overlap (SAT on the plate's own
    axes, >0.3 m penetration on both) with |dz| < 6 cm, the higher-id plate is lifted onto its
    own plane: base + 1.5 cm per layer within the overlap cluster. Deterministic (id order), so
    every apply converges to the same output; a 1.5 cm step at a seam is invisible and
    collision-irrelevant, a flicker war is not. Runs before row emission on every apply.
    """
    plates = []
    for e in ents:
        d = _surf_dims(e["cls"])
        if not d:
            continue
        dx, dy = e["dir"][0], e["dir"][1]
        n = math.hypot(dx, dy) or 1.0
        plates.append({"e": e, "dims": d, "ax": (dx / n, dy / n)})

    def overlap(a, b):
        pa, pb = a["e"]["world"], b["e"]["world"]
        if abs(pa[2] - pb[2]) >= 0.06:
            return False
        rel = (pb[0] - pa[0], pb[1] - pa[1])
        for p in (a, b):
            ax = p["ax"]; ay = (-ax[1], ax[0])
            for axis, own_half in ((ax, p["dims"][0] / 2), (ay, p["dims"][1] / 2)):
                c = abs(rel[0] * axis[0] + rel[1] * axis[1])
                other = a if p is b else b
                oh = (abs(other["ax"][0] * axis[0] + other["ax"][1] * axis[1]) * other["dims"][0] / 2
                      + abs(-other["ax"][1] * axis[0] + other["ax"][0] * axis[1]) * other["dims"][1] / 2)
                if c > own_half + oh - 0.3:
                    return False
        return True

    # Overlap graph + greedy coloring: only plates that DIRECTLY overlap need different planes.
    # Union-find + linear stacking turned overlap-TILED sidewalk rows (each plate lapping its
    # neighbour) into a rising staircase, ~1.5 cm per tile down the whole row. Colouring keeps
    # any chain at 2-3 planes total (max ~4.5 cm), and isolated laps at exactly 2.
    adj = {i: set() for i in range(len(plates))}
    pairs = 0
    for i in range(len(plates)):
        for j in range(i + 1, len(plates)):
            if abs(plates[i]["e"]["world"][0] - plates[j]["e"]["world"][0]) > 12:
                continue
            if overlap(plates[i], plates[j]):
                pairs += 1
                adj[i].add(j)
                adj[j].add(i)
    lifted = 0
    color = {}
    for i in sorted(adj, key=lambda i: plates[i]["e"].get("id") or 0):
        if not adj[i]:
            continue
        used = {color[n] for n in adj[i] if n in color}
        c = 0
        while c in used:
            c += 1
        color[i] = c
        if c:
            # lift onto plane c relative to the LOWEST directly-overlapping neighbour's base
            base = min(plates[n]["e"]["world"][2] for n in adj[i] | {i})
            w = plates[i]["e"]["world"]           # world is a TUPLE -- rebuild, don't mutate
            plates[i]["e"]["world"] = (w[0], w[1], round(base + 0.015 * c, 3))
            lifted += 1
    if lifted:
        maxc = max(color.values(), default=0)
        print("  dezfight: %d overlapping pair(s) -> lifted %d plate(s), %d plane(s) max"
              % (pairs, lifted, maxc + 1))
    return lifted


def check_frames(ents, label):
    """Warn about rows whose dir/up are not a valid rotation frame.

    The sqm stores orientation as Euler angles, which can only express a proper rotation. A row
    whose vectors are not unit length or not perpendicular therefore cannot survive the trip --
    it snaps to the nearest valid rotation, silently re-aiming that object. That is worth a loud
    warning rather than an abort: as of 2026-07-31 exactly one row of 8,717 is affected
    (Land_RepairDepot_01_civ_F, |up| = 0.410, dir.up = -0.079), and it is pre-existing damage in
    the array rather than anything this pipeline did.
    """
    import math
    bad = []
    for i, e in enumerate(ents):
        dn = math.sqrt(sum(v * v for v in e["dir"]))
        un = math.sqrt(sum(v * v for v in e["up"]))
        dot = abs(sum(p * q for p, q in zip(e["dir"], e["up"])))
        if abs(dn - 1) > 0.01 or abs(un - 1) > 0.01 or dot > 0.01:
            bad.append((i, e["cls"], dn, un, dot))
    for i, cls, dn, un, dot in bad:
        print("  WARNING %s row %d %s: |dir|=%.3f |up|=%.3f dir.up=%.3f -- not a valid rotation, "
              "it will snap to the nearest one" % (label, i, cls, dn, un, dot))
    return bad


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("stage", "apply"):
        sys.exit(__doc__)
    if sys.argv[1] == "stage":
        stage()
    else:
        apply("--allow-deletes" in sys.argv)


if __name__ == "__main__":
    main()
