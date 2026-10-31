#!/usr/bin/env python3
"""
mapdata_all.py -- FULL-MAP allLocalMapEntities round-trip (the whole ~7000-entry array at once).

    baseline             stage ONLY the mission's own Eden ids -> <editor mission>/mapBaseline_ids.sqf
                         (+ mapExportAll.sqf). This is all you need to ADD objects: place them in
                         3DEN, export, apply -- no import of the 8k-entry array, no selecting.
    extract              stage EVERY entry -> <editor mission>/mapImportAll_data.sqf and copy
                         mapImportAll.sqf + mapExportAll.sqf into the editor mission folder(s).
                         (also writes the baseline)
    delivery <old.sqm> <new.sqm>
                         what changed between two designer deliveries: ADDED / REMOVED / moved /
                         retyped, by Eden id. Run it before applying anything they send.
    apply <export.sqf>   REPLACE the entire allLocalMapEntities array in fn_mapData.sqf with the
                         3DEN export (writes fn_mapData.sqf.bak first). An export marked
                         AP_MAPALL_MODE_APPEND is APPENDED instead -- that is what an add-only
                         session produces, and no deletion guard applies to it.

    Flow:  extract -> open mission in 3DEN -> Debug Console:
               call compile preprocessFileLineNumbers "mapImportAll.sqf"
           (everything lands in layer 'MapDataAll', FULL tilt/bank preserved)
           edit -> select the whole layer (+ anything you added) -> run mapExportAll.sqf
           -> wl-paste > /tmp/mapdata_all_export.sqf
           -> python3 tools/mapdata_all.py apply /tmp/mapdata_all_export.sqf

    SAFETY: apply aborts on a net DELETION bigger than 2% of the staged count unless
    --allow-deletes is passed (the forgot-to-select-everything footgun at full-map scale
    would otherwise wipe the map). fn_mapData.sqf.bak is written before every apply.

    Unlike the region pipeline (eden_region.py), the import/export here carry vectorDir AND
    vectorUp end-to-end -- tilted kerbs/props round-trip exactly, no flattening.
"""
import sys, os, re, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mapdata_to_eden as M           # quote/bracket-aware array parser
import sqm_read                       # rapified mission.sqm reader (Eden ids)

MAP = os.path.join(HERE, "..", "mission", "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")
SQM = os.path.join(HERE, "..", "mission", "Armapunk2035.Malden", "mission.sqm")
EDITOR_DIRS = [p for p in [
    os.environ.get("AP_PROTON_MISSION", ""),
    "/home/timb/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/Documents/Arma 3/missions/Armapunk2035.Malden",
    "/home/timb/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/Documents/Arma 3/mpmissions/Armapunk2035.Malden",
    "/home/timb/.steam/steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/Documents/Arma 3/missions/Armapunk2035.Malden",
] if p and os.path.isdir(p)]
# dedupe by realpath (the two Steam roots are sometimes the same disk)
_seen = set(); DIRS = []
for d in EDITOR_DIRS:
    r = os.path.realpath(d)
    if r not in _seen:
        _seen.add(r); DIRS.append(d)


def _array_span(src):
    """(start,end) indexes of the inner allLocalMapEntities [ ... ] literal."""
    i = src.index('[', src.index('allLocalMapEntities'))
    j = M.matching_brace_sq(src, i)
    return i, j


def _entries(src):
    """split the inner array into top-level raw entry strings."""
    i, j = _array_span(src)
    inner = src[i + 1:j]
    out, depth, q, start = [], 0, False, 0
    k = 0
    while k < len(inner):
        c = inner[k]
        if c == '"':
            q = not q
        elif not q:
            if c == '[':
                if depth == 0:
                    start = k
                depth += 1
            elif c == ']':
                depth -= 1
                if depth == 0:
                    out.append(inner[start:k + 1])
        k += 1
    return out


def _baseline(sqm=None):
    """Stage a mission's Eden ids so the editor export can tell NEW objects from ones already there.

    Every entity in a .sqm carries an id that get3DENEntityID returns unchanged in the editor. Hand
    that set to mapExportAll and it picks up anything you placed without you selecting it.

    `sqm` defaults to our own mission. Point it at the DESIGNER'S PREVIOUS DELIVERY (--from) when the
    file you are about to open in 3DEN is their new one: ids are stable inside their mission too, so
    the ids their new file has and the old one doesn't are exactly what they added.
    """
    if not DIRS:
        sys.exit("no editor mission folder found (set AP_PROTON_MISSION)")
    sqm = sqm or SQM
    ids = sqm_read.entity_ids(sqm)
    body = "AP_sqmIds = [" + ",".join(str(i) for i in ids) + "];\n"
    for d in DIRS:
        open(os.path.join(d, "mapBaseline_ids.sqf"), "w", encoding="utf-8").write(body)
        shutil.copy(os.path.join(HERE, "mapExportAll.sqf"), os.path.join(d, "mapExportAll.sqf"))
    print("baseline: %d Eden ids from %s -> %s" % (len(ids), os.path.basename(sqm), ", ".join(DIRS)))
    return len(ids)


def _stage(src):
    rows = _entries(src)
    if not DIRS:
        sys.exit("no editor mission folder found (set AP_PROTON_MISSION)")
    staged = "AP_dataAll = [" + ",".join(r.strip() for r in rows) + "];\n"
    for d in DIRS:
        open(os.path.join(d, "mapImportAll_data.sqf"), "w", encoding="utf-8").write(staged)
        for t in ("mapImportAll.sqf", "mapExportAll.sqf"):
            shutil.copy(os.path.join(HERE, t), os.path.join(d, t))
        print("staged -> %s" % d)
    _baseline()
    open(os.path.join(HERE, ".mapdata_all_count"), "w").write(str(len(rows)))
    print("staged %d entries (full map). In 3DEN Debug Console:" % len(rows))
    print('    call compile preprocessFileLineNumbers "mapImportAll.sqf"')


def apply_export(exp, allow_deletes=False):
    """Fold a 3DEN export into fn_mapData.sqf. Returns a human-readable summary; raises ValueError
    on anything that looks like an accident (that is what the watcher turns into a loud line)."""
    src = open(MAP, encoding="utf-8").read()
    # accept either the bare [entry],[entry],... blob or a PLB marker block
    if "AP_MAPALL_BEGIN" in exp:
        exp = exp.split("AP_MAPALL_BEGIN", 1)[1].split("AP_MAPALL_END", 1)[0]
    append = "AP_MAPALL_MODE_APPEND" in exp
    exp = exp.strip().strip('";').strip()
    new_rows = []
    depth, q, start = 0, False, 0
    for k, c in enumerate(exp):
        if c == '"':
            q = not q
        elif not q:
            if c == '[':
                if depth == 0:
                    start = k
                depth += 1
            elif c == ']':
                depth -= 1
                if depth == 0:
                    new_rows.append(exp[start:k + 1])
    if not new_rows:
        raise ValueError("no entries parsed from the export")

    rows = _entries(src)
    i, j = _array_span(src)

    # ADD-ONLY export (mapExportAll ran with nothing imported): the rows are things you just placed,
    # so APPEND them -- there is nothing here to compare a deletion against.
    if append:
        if len(new_rows) > 2000:
            raise ValueError("add-only export carries %d entries -- that is not a handful of new "
                             "objects. Re-run 'mapdata_all.py baseline' so the export knows what the "
                             "mission already has." % len(new_rows))
        body = "[\n" + ",\n".join([r.strip() for r in rows] + new_rows) + "\n]"
        shutil.copy(MAP, MAP + ".bak")
        open(MAP, "w", encoding="utf-8").write(src[:i] + body + src[j + 1:])
        _stage(src[:i] + body + src[j + 1:])
        return ("appended %d new entries (array %d -> %d). Backup: fn_mapData.sqf.bak"
                % (len(new_rows), len(rows), len(rows) + len(new_rows)))

    try:
        staged_n = int(open(os.path.join(HERE, ".mapdata_all_count")).read().strip())
    except OSError:
        staged_n = len(rows)
    if len(new_rows) < staged_n * 0.98 and not allow_deletes:
        raise ValueError("export has %d entries vs %d staged (net deletion > 2%%). Nothing written. "
                         "Pass --allow-deletes if the deletion is deliberate."
                         % (len(new_rows), staged_n))
    body = "[\n" + ",\n".join(new_rows) + "\n]"
    shutil.copy(MAP, MAP + ".bak")
    open(MAP, "w", encoding="utf-8").write(src[:i] + body + src[j + 1:])
    _stage(src[:i] + body + src[j + 1:])
    return "applied %d entries (was %d). Backup: fn_mapData.sqf.bak" % (len(new_rows), staged_n)


def _sqm_objects(path):
    """{id: (class, x, y, height)} for every Object in a .sqm, plus a list for id-less compares."""
    try:
        root = sqm_read.parse(path)
    except ValueError as e:
        sys.exit("%s\n(Eden writes binarized .sqm -- if this is a hand-written text mission, open and "
                 "re-save it in 3DEN first.)" % e)
    by_id, flat = {}, []
    for n in sqm_read.walk(root):
        pr = n["props"]
        if pr.get("dataType") != "Object":
            continue
        pos = n["subs"].get("PositionInfo", {}).get("props", {}).get("position")
        if not pos or len(pos) < 3:
            continue
        rec = (pr.get("type", "?"), pos[0], pos[2], pos[1])
        flat.append(rec)
        if isinstance(pr.get("id"), int):
            by_id[pr["id"]] = rec
    return by_id, flat


def _delivery(old_path, new_path, samples=8):
    """What changed between two designer deliveries. Run this BEFORE applying one."""
    old, old_flat = _sqm_objects(old_path)
    new, new_flat = _sqm_objects(new_path)
    print("%-8s %6d objects  %s" % ("old:", len(old_flat), old_path))
    print("%-8s %6d objects  %s" % ("new:", len(new_flat), new_path))

    common = set(old) & set(new)
    if not common:
        # Different lineage (they rebuilt the mission, or it came from another file): ids are
        # meaningless across the two, so fall back to counting identical class+position rows.
        import collections
        co = collections.Counter((c, round(x, 2), round(y, 2), round(h, 2)) for c, x, y, h in old_flat)
        cn = collections.Counter((c, round(x, 2), round(y, 2), round(h, 2)) for c, x, y, h in new_flat)
        add = sum((cn - co).values())
        rem = sum((co - cn).values())
        print("\nNO SHARED EDEN IDS -- these files are not the same lineage, so this is a "
              "class+position compare and a moved object counts as one removed + one added.")
        print("  added   %d\n  removed %d" % (add, rem))
        print("\nThe id-based baseline (--from) will NOT work across this pair; import the new file "
              "and export the whole array instead.")
        return

    added = [i for i in new if i not in old]
    removed = [i for i in old if i not in new]
    moved, retyped = [], []
    for i in common:
        oc, ox, oy, oh = old[i]
        nc, nx, ny, nh = new[i]
        if oc != nc:
            retyped.append((i, oc, nc))
        elif abs(ox - nx) > 0.05 or abs(oy - ny) > 0.05 or abs(oh - nh) > 0.05:
            moved.append((i, nc, ((nx - ox) ** 2 + (ny - oy) ** 2 + (nh - oh) ** 2) ** 0.5))
    print("\n  shared ids %d\n  ADDED   %d\n  REMOVED %d\n  moved   %d\n  retyped %d"
          % (len(common), len(added), len(removed), len(moved), len(retyped)))

    def show(title, rows):
        if not rows:
            return
        print("\n%s:" % title)
        for r in rows[:samples]:
            print("   %s" % (r,))
        if len(rows) > samples:
            print("   ... and %d more" % (len(rows) - samples))

    show("added (id, class, x, y, height)", [(i,) + new[i] for i in added])
    show("REMOVED (id, class, x, y, height)", [(i,) + old[i] for i in removed])
    show("moved (id, class, distance m)", sorted(moved, key=lambda r: -r[2]))
    show("retyped (id, was, now)", retyped)

    if removed:
        print("\n!! %d object(s) DISAPPEARED in this delivery. An add-only apply will not notice that "
              "-- decide deliberately whether they should also go from the array." % len(removed))
    if added:
        print("\nTo pull the %d added object(s) in:" % len(added))
        print("   python3 tools/mapdata_all.py baseline --from %s" % old_path)
        print("   # open %s in 3DEN, then Debug Console:" % os.path.basename(new_path))
        print('   call compile preprocessFileLineNumbers "mapExportAll.sqf"')


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("extract", "apply", "baseline", "delivery"):
        sys.exit(__doc__)

    if sys.argv[1] == "delivery":
        if len(sys.argv) < 4:
            sys.exit("delivery <their PREVIOUS .sqm> <their NEW .sqm>")
        _delivery(sys.argv[2], sys.argv[3])
        return

    if sys.argv[1] == "baseline":
        frm = None
        if "--from" in sys.argv:
            frm = sys.argv[sys.argv.index("--from") + 1]
            if not os.path.isfile(frm):
                sys.exit("--from: no such file: %s" % frm)
        _baseline(frm)
        print("Now: open the mission in 3DEN, place your objects, and in the Debug Console run")
        print('    call compile preprocessFileLineNumbers "mapExportAll.sqf"')
        return

    src = open(MAP, encoding="utf-8").read()

    if sys.argv[1] == "extract":
        _stage(src)
        return

    # apply
    if len(sys.argv) < 3:
        sys.exit("apply needs the exported file (wl-paste > /tmp/mapdata_all_export.sqf)")
    print(apply_export(open(sys.argv[2], encoding="utf-8").read(),
                       allow_deletes="--allow-deletes" in sys.argv))

if __name__ == "__main__":
    main()
