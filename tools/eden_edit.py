#!/usr/bin/env python3
"""
eden_edit.py -- make the custom .p3d buildings editable in 3DEN, and write the moves back.

    python3 tools/eden_edit.py list       # what is placed, and where
    python3 tools/eden_edit.py stage      # write the three Eden scripts into the mission
    python3 tools/eden_edit.py apply      # read the editor's export and rewrite the source

THE PROBLEM. 3DEN can only place entities that have a CfgVehicles class, and a mission-defined class
is not spawnable (that footgun is already recorded in this repo). The custom buildings are raw .p3d
files spawned with createSimpleObject, so they can never be 3DEN entities and their placements live
as literal coordinates in custom_p3ds/malden_buildings.sqf and custom_p3ds/load.sqf.

THE WAY ROUND, which is the designer's own: author the placement as an ANCHOR entity -- a
Land_HelipadEmpty_F -- and let a script spawn the real model at the anchor's transform. That is
exactly what malden_buildings.sqf's header describes ("authored by the map designer in Eden as
Land_HelipadEmpty_F anchors, stripped out of mission.sqm ... and re-created here"). This tool makes
that round-trip repeatable instead of a one-off, and adds the part that was missing: it can put the
EXISTING placements back into the editor, so a building can be MOVED and not just added.

WHAT YOU SEE IN THE EDITOR. Each placement gets an invisible anchor entity you drag, plus the real
.p3d drawn at that spot as a plain simple object so you can see the building you are moving. The
visual is NOT an entity -- 3DEN does not save it and it cannot be baked into mission.sqm. After
moving anchors, run the refresh line to snap the visuals to them.

FRAMES. Import writes the transform with setPosWorld and export reads it back with getPosWorld -- the
same command pair, so the round-trip is exact whatever 3DEN does internally. createSimpleObject and
getPosWorld are both in the model-centre frame, which is the frame the source coordinates are already
in; using 3DEN's own "position" attribute instead would introduce the ATL/model-centre offset that is
a per-class constant (Mil_WallBig_4m -1.700, LampHalogen -5.982) and silently sink every building.

ORDER IS LOAD-BEARING on the way out: setDir MUST come before setObjectScale, because setDir rewrites
a simple object's transform matrix and resets its scale to 1. That is verified in-engine and recorded
in malden_buildings.sqf; the emitter here preserves it.

NEVER plain-save the mission from 3DEN while the map layer is imported -- that re-bakes every
script-spawned object back into mission.sqm (it once took the file from 4,260 to 19,902 objects).
This tool never asks you to save: you export from the debug console instead.
"""
import argparse
import glob
import math
import os
import re
import shutil
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MISSION = os.path.join(REPO, "mission", "Armapunk2035.Malden")
BUILDINGS = os.path.join(MISSION, "custom_p3ds", "malden_buildings.sqf")
LOAD = os.path.join(MISSION, "custom_p3ds", "load.sqf")
RPT_DIR = os.path.expanduser(
    "~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/"
    "AppData/Local/Arma 3")

# _o = createSimpleObject [_MALDEN + "Name.p3d", [x, y, z], true]; _o setDir d; _o setObjectScale s;
PLACE = re.compile(
    r'_o\s*=\s*createSimpleObject\s*\[\s*_MALDEN\s*\+\s*"([^"]+)\.p3d"\s*,\s*'
    r'\[\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\]\s*,\s*true\s*\]\s*;'
    r'\s*_o\s+setDir\s+(-?[\d.]+)\s*;\s*_o\s+setObjectScale\s+(-?[\d.]+)\s*;')


def read_placements():
    """[(index, model, x, y, z, dir, scale, span)] in file order. span = byte range to rewrite."""
    s = open(BUILDINGS, encoding="utf-8", errors="surrogateescape").read()
    out = []
    for i, m in enumerate(PLACE.finditer(s)):
        out.append({"i": i, "model": m.group(1),
                    "x": float(m.group(2)), "y": float(m.group(3)), "z": float(m.group(4)),
                    "dir": float(m.group(5)), "scale": float(m.group(6)),
                    "span": (m.start(), m.end())})
    return s, out


def emit_line(p):
    # %.10g, not %.3f: it matches how the file already writes numbers (3765 stays "3765", not
    # "3765.000") so an apply only rewrites the lines that actually moved, and 10 significant digits
    # keeps full precision -- plain %g rounds 8512.527 to 8512.53.
    n = lambda v: "%.10g" % v
    return ('_o = createSimpleObject [_MALDEN + "%s.p3d", [%s, %s, %s], true]; '
            '_o setDir %s; _o setObjectScale %s;'
            % (p["model"], n(p["x"]), n(p["y"]), n(p["z"]), n(p["dir"]), n(p["scale"])))


def do_list():
    _, ps = read_placements()
    print(f"{'#':>3s}  {'model':30s} {'x':>10s} {'y':>10s} {'z':>8s} {'dir':>7s} {'scale':>6s}")
    print("-" * 78)
    for p in ps:
        print(f"{p['i']:3d}  {p['model']:30s} {p['x']:10.2f} {p['y']:10.2f} "
              f"{p['z']:8.2f} {p['dir']:7.1f} {p['scale']:6.2f}")
    print(f"\n{len(ps)} custom building placements in {os.path.relpath(BUILDINGS, REPO)}")


def do_stage():
    _, ps = read_placements()
    data = ",\n    ".join('["%s", [%.3f, %.3f, %.3f], %g, %g]'
                          % (p["model"], p["x"], p["y"], p["z"], p["dir"], p["scale"]) for p in ps)

    common = ('// GENERATED by tools/eden_edit.py -- do not hand-edit, re-run `stage` instead.\n')

    open(os.path.join(MISSION, "edenCB_data.sqf"), "w", encoding="utf-8").write(
        common + "AP_cbData = [\n    " + data + "\n];\nAP_cbData\n")

    open(os.path.join(MISSION, "edenCB_import.sqf"), "w", encoding="utf-8").write(common + '''
// Put every custom building into the editor as a draggable anchor + a visible model.
// Run in the 3DEN debug console:  call compile preprocessFileLineNumbers "edenCB_import.sqf";
call compile preprocessFileLineNumbers "edenCB_data.sqf";
if (!isNil "AP_cbVis") then { { deleteVehicle _x } forEach AP_cbVis; };
AP_cbVis = []; AP_cbAnchors = [];
private _p = getMissionPath "";
{
    _x params ["_model", "_pos", "_dir", "_scale"];
    // the anchor: a real 3DEN entity, so it drags, snaps and survives undo like anything else
    private _a = create3DENEntity ["Object", "Land_HelipadEmpty_F", _pos];
    _a setPosWorld _pos;                      // same command pair as the export -> exact round-trip
    _a setDir _dir;
    _a set3DENAttribute ["name", format ["cb_%1", _forEachIndex]];
    _a setVariable ["AP_cbModel", _model];
    _a setVariable ["AP_cbScale", _scale];
    AP_cbAnchors pushBack _a;
    // the visual: a plain simple object, NOT an entity -- 3DEN will not save or bake it
    private _v = createSimpleObject [_p + _model + ".p3d", _pos, true];
    _v setDir _dir; _v setObjectScale _scale;   // setDir resets scale, so scale must come second
    AP_cbVis pushBack _v;
} forEach AP_cbData;
systemChat format ["edenCB: %1 anchors placed. Move them, then run edenCB_refresh.sqf to redraw.", count AP_cbAnchors];
''')

    open(os.path.join(MISSION, "edenCB_refresh.sqf"), "w", encoding="utf-8").write(common + '''
// Snap the visible models onto the anchors after you have moved them.
// Run in the 3DEN debug console:  call compile preprocessFileLineNumbers "edenCB_refresh.sqf";
if (isNil "AP_cbAnchors") exitWith { systemChat "edenCB: run edenCB_import.sqf first"; };
{ deleteVehicle _x } forEach AP_cbVis;
AP_cbVis = [];
private _p = getMissionPath "";
{
    private _v = createSimpleObject [_p + (_x getVariable ["AP_cbModel", ""]) + ".p3d", getPosWorld _x, true];
    _v setDir (getDir _x); _v setObjectScale (_x getVariable ["AP_cbScale", 1]);
    AP_cbVis pushBack _v;
} forEach (AP_cbAnchors select { !isNull _x });
systemChat "edenCB: models redrawn on the anchors.";
''')

    open(os.path.join(MISSION, "edenCB_export.sqf"), "w", encoding="utf-8").write(common + '''
// Write the anchors back out. Run in the 3DEN debug console:
//     call compile preprocessFileLineNumbers "edenCB_export.sqf";
// then, in a terminal:  python3 tools/eden_edit.py apply
if (isNil "AP_cbAnchors") exitWith { systemChat "edenCB: run edenCB_import.sqf first"; };
private _n = 0;
{
    if (!isNull _x) then {
        private _w = getPosWorld _x;          // model-centre frame, matching createSimpleObject
        diag_log format ["-CBEXPORT- %1|%2|%3|%4|%5|%6",
            _x getVariable ["AP_cbModel", "?"],
            (_w select 0) toFixed 3, (_w select 1) toFixed 3, (_w select 2) toFixed 3,
            (getDir _x) toFixed 2, _x getVariable ["AP_cbScale", 1]];
        _n = _n + 1;
    };
} forEach AP_cbAnchors;
diag_log format ["-CBEXPORT- END %1", _n];
systemChat format ["edenCB: %1 exported. Now run: python3 tools/eden_edit.py apply", _n];
''')
    print("staged into", os.path.relpath(MISSION, REPO) + ":")
    for f in ("edenCB_data.sqf", "edenCB_import.sqf", "edenCB_refresh.sqf", "edenCB_export.sqf"):
        print("   ", f)
    print(f"\n{len(ps)} placements staged.\n")
    # Every line below is valid SQF, including the prose: commands are ";"-terminated and the
    # commentary is "//". So pasting the whole block into the debug console is harmless -- which is
    # what people actually do. Printing a bare command with prose trailing it on the same line cost a
    # round: the console compiled `...preprocessFileLineNumbers "edenCB_import.sqf"   models` and
    # threw "Missing ;", which reads like the SCRIPT is broken when nothing had run at all.
    print("In 3DEN (the editor mission is a symlink to the repo, so these are already there).")
    print("Paste ONE line at a time, or the whole block -- both are safe:\n")
    print('    call compile preprocessFileLineNumbers "edenCB_import.sqf";')
    print("    // ... now drag the anchors in the editor ...")
    print('    call compile preprocessFileLineNumbers "edenCB_refresh.sqf";   // redraw the models')
    print('    call compile preprocessFileLineNumbers "edenCB_export.sqf";')
    print("\nThen:  python3 tools/eden_edit.py apply")
    print("\nDo NOT save the mission from 3DEN.")


def do_apply(dry):
    rpts = sorted(glob.glob(os.path.join(RPT_DIR, "*.rpt")), key=os.path.getmtime)
    if not rpts:
        print("no client RPT found")
        return 1
    rows, saw_end = [], False
    for line in open(rpts[-1], encoding="utf-8", errors="replace"):
        if "-CBEXPORT- END" in line:
            rows, saw_end = rows, True
            continue
        m = re.search(r"-CBEXPORT- ([^|]+)\|([-\d.]+)\|([-\d.]+)\|([-\d.]+)\|([-\d.]+)\|([\d.]+)", line)
        if m:
            if saw_end:                     # a newer block started: drop the older one
                rows, saw_end = [], False
            rows.append({"model": m.group(1), "x": float(m.group(2)), "y": float(m.group(3)),
                         "z": float(m.group(4)), "dir": float(m.group(5)), "scale": float(m.group(6))})
    if not rows:
        print("no -CBEXPORT- lines in", os.path.basename(rpts[-1]))
        return 1
    src, ps = read_placements()
    if len(rows) != len(ps):
        print(f"REFUSING: editor exported {len(rows)} placements, the source has {len(ps)}.")
        print("Adding or deleting anchors is not supported yet -- this only moves existing ones.")
        return 2
    changed = []
    for old, new in zip(ps, rows):
        if old["model"] != new["model"]:
            print(f"REFUSING: order changed -- #{old['i']} is {old['model']} in source, "
                  f"{new['model']} in the export.")
            return 2
        if (abs(old["x"] - new["x"]) > 0.005 or abs(old["y"] - new["y"]) > 0.005
                or abs(old["z"] - new["z"]) > 0.005 or abs(old["dir"] - new["dir"]) > 0.05):
            changed.append((old, new))
    print(f"{len(changed)} of {len(ps)} placements moved.")
    for old, new in changed:
        print(f"  #{old['i']:3d} {old['model']:26s} [{old['x']:.2f},{old['y']:.2f},{old['z']:.2f}] "
              f"dir {old['dir']:g}  ->  [{new['x']:.2f},{new['y']:.2f},{new['z']:.2f}] dir {new['dir']:g}")
    if not changed or dry:
        print("(nothing written)" if dry else "")
        return 0
    out = src
    for old, new in sorted(changed, key=lambda t: -t[0]["span"][0]):   # back to front: spans stay valid
        p = dict(old); p.update({k: new[k] for k in ("x", "y", "z", "dir", "scale")})
        a, b = old["span"]
        out = out[:a] + emit_line(p) + out[b:]
    shutil.copy(BUILDINGS, BUILDINGS + ".bak-eden")
    open(BUILDINGS, "w", encoding="utf-8", errors="surrogateescape").write(out)
    _, after = read_placements()
    print(f"\nwritten. placements still parse: {len(after)} (was {len(ps)})")
    print("deploy:  bash /home/timb/arma3server_dev/reload-armapunk2035.sh")
    return 0 if len(after) == len(ps) else 3


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["list", "stage", "apply"])
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    return {"list": lambda: (do_list(), 0)[1],
            "stage": lambda: (do_stage(), 0)[1],
            "apply": lambda: do_apply(a.dry_run)}[a.cmd]()


if __name__ == "__main__":
    sys.exit(main())
