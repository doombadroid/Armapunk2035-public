#!/usr/bin/env python3
"""
mapdata_all.py -- FULL-MAP allLocalMapEntities round-trip (the whole ~7000-entry array at once).

    extract              stage EVERY entry -> <editor mission>/mapImportAll_data.sqf and copy
                         mapImportAll.sqf + mapExportAll.sqf into the editor mission folder(s).
    apply <export.sqf>   REPLACE the entire allLocalMapEntities array in fn_mapData.sqf with the
                         3DEN export (writes fn_mapData.sqf.bak first).

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

MAP = os.path.join(HERE, "..", "mission", "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")
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
    open(os.path.join(HERE, ".mapdata_all_count"), "w").write(str(len(rows)))
    print("staged %d entries (full map). In 3DEN Debug Console:" % len(rows))
    print('    call compile preprocessFileLineNumbers "mapImportAll.sqf"')


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("extract", "apply"):
        sys.exit(__doc__)
    src = open(MAP, encoding="utf-8").read()

    if sys.argv[1] == "extract":
        _stage(src)
        return

    # apply
    if len(sys.argv) < 3:
        sys.exit("apply needs the exported file (wl-paste > /tmp/mapdata_all_export.sqf)")
    exp = open(sys.argv[2], encoding="utf-8").read()
    # accept either the bare [entry],[entry],... blob or a PLB marker block
    if "AP_MAPALL_BEGIN" in exp:
        exp = exp.split("AP_MAPALL_BEGIN", 1)[1].split("AP_MAPALL_END", 1)[0]
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
        sys.exit("no entries parsed from %s" % sys.argv[2])
    try:
        staged_n = int(open(os.path.join(HERE, ".mapdata_all_count")).read().strip())
    except OSError:
        staged_n = len(_entries(src))
    if len(new_rows) < staged_n * 0.98 and "--allow-deletes" not in sys.argv:
        sys.exit("ABORT: export has %d entries vs %d staged (net deletion > 2%%). "
                 "Select the WHOLE MapDataAll layer before exporting, or pass --allow-deletes."
                 % (len(new_rows), staged_n))
    shutil.copy(MAP, MAP + ".bak")
    i, j = _array_span(src)
    body = "[\n" + ",\n".join(new_rows) + "\n]"
    open(MAP, "w", encoding="utf-8").write(src[:i] + body + src[j + 1:])
    print("applied %d entries (was %d). Backup: fn_mapData.sqf.bak" % (len(new_rows), staged_n))
    # re-stage immediately: the editor's import snapshot must never lag the applied array
    _stage(src[:i] + body + src[j + 1:])
    print("Repack/reload to see it in game; commit via the normal PR flow.")


if __name__ == "__main__":
    main()
