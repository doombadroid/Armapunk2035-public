#!/usr/bin/env python3
"""
eden_region.py -- stage an allLocalMapEntities region for 3DEN editing, and apply the
edited objects back. The ENGINE does every height conversion (edenImport.sqf setPosATL,
edenExport.sqf getPosATL); this tool only filters by region and moves text. NO terrain math here.

  extract:   python3 tools/eden_region.py extract X Y R
             pulls array entries within R metres of X,Y, writes them as
             `AP_data = [ ... ];` into  <proton mission>/edenImport_data.sqf  and copies
             edenImport.sqf + edenExport.sqf into the mission folder.
             Reports how many carry an init string (shops/NPCs) and how many are TILTED
             (3DEN import flattens tilt -- see the note below).

  apply:     python3 tools/eden_region.py apply EXPORTFILE [--allow-deletes]
             EXPORTFILE = the edenExport.sqf output (clipboard dump / RPT slice).
             Removes from fn_mapData.sqf the EXACT originals that were imported (read back
             from the staged edenImport_data.sqf), then appends the edited entries. So only
             the imported objects are replaced; the rest of the array is never touched.
             Writes fn_mapData.sqf.bak first.

             SAFETY: if the export has FEWER entries than were imported (net deletion), the
             apply ABORTS unless you pass --allow-deletes. This catches the #1 footgun --
             forgetting to select part of the 'ArrayImport' layer before exporting, which
             would otherwise silently delete every object you left unselected.

             RULE: in 3DEN, export the WHOLE 'ArrayImport' layer (Edit > Select All in layer)
             plus anything you added. An imported object you don't re-export is treated as
             deleted -- intentional only with --allow-deletes.

TILT: edenImport applies YAW only (it flattens pitch/roll to upright). If a region has
      tilted objects and you DON'T re-orient them in 3DEN, the round-trip will un-tilt them.
      extract warns with a count; re-tilt those by hand in 3DEN or keep them out of the region.

PROTON mission folder: defaults to the Arma-3 Proton editor mission path; override with the
      env var AP_PROTON_MISSION=/path/to/mpmissions/Armapunk2035.Malden if yours differs.

Engine = heights. Python = format + region. Round-trips any size scene.
"""
import sys, os, re, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mapdata_to_eden as M           # reuse its quote/bracket-aware array parser

MAP  = os.path.join(HERE, "..", "mission", "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")
PROTON = os.environ.get("AP_PROTON_MISSION",
    "/home/timb/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/Documents/Arma 3/mpmissions/Armapunk2035.Malden")
STAGED = os.path.join(PROTON, "edenImport_data.sqf")

def _is_tilted(dirup, eps=1e-3):
    """dirup = '[[dx,dy,dz],[ux,uy,uz]]' -- tilted if the up vector isn't [0,0,1] (or dir has a z)."""
    nums = re.findall(r'[+-]?\d*\.?\d+(?:[eE][+-]?\d+)?', dirup or "")
    if len(nums) < 6:
        return False
    try:
        dx, dy, dz, ux, uy, uz = (float(n) for n in nums[:6])
    except ValueError:
        return False   # unparseable orientation -> don't claim tilt (and never crash the run)
    return abs(dz) > eps or abs(ux) > eps or abs(uy) > eps or abs(uz - 1.0) > eps

def main():
    if len(sys.argv) < 2: sys.exit(__doc__)
    mode = sys.argv[1]
    s = open(MAP, encoding="latin1").read()
    _, close, ents = M.parse_array(s)      # each: cls,x,y,z,dirup,init,raw,abs_start,abs_end

    if mode == "extract":
        X, Y, R = float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
        skip_tilted = "--skip-tilted" in sys.argv[5:]
        hits = [e for e in ents if (e['x']-X)**2 + (e['y']-Y)**2 <= R*R]
        if not hits: sys.exit("no entries within %g m of [%g,%g]" % (R, X, Y))
        tilted = [e for e in hits if _is_tilted(e['dirup'])]
        skipped = 0
        if skip_tilted and tilted:
            # leave tilted objects OUT of the round-trip entirely -> they stay verbatim in the array
            # (never imported -> not in the staged set -> apply never removes them). Perfect preservation.
            hits = [e for e in hits if not _is_tilted(e['dirup'])]
            skipped = len(tilted)
            if not hits: sys.exit("every entry in the region is tilted -- nothing to round-trip with --skip-tilted")
        if not os.path.isdir(PROTON):
            sys.exit("proton mission folder missing: %s\n(set AP_PROTON_MISSION to your 3DEN editor mission folder)" % PROTON)
        open(STAGED, "w", encoding="latin1").write(
            "AP_data = [" + ",".join(e['raw'].strip() for e in hits) + "];\n")
        for f in ("edenImport.sqf", "edenExport.sqf"):
            shutil.copy(os.path.join(HERE, f), os.path.join(PROTON, f))
        withinit = [e for e in hits if e['init']]
        print("staged %d entries -> edenImport_data.sqf  (these EXACT %d are the originals replaced on apply)" % (len(hits), len(hits)))
        print("  with an init string (shops/NPCs -- keep their init on export): %d" % len(withinit))
        if skipped:
            print("  --skip-tilted: %d tilted object(s) left UNTOUCHED in the array (not imported, not editable this pass)" % skipped)
        elif tilted:
            print("  !! TILTED objects: %d -- 3DEN import FLATTENS tilt. Re-orient them in 3DEN, or re-run with" % len(tilted))
            print("     --skip-tilted to leave them verbatim in the array. Examples:")
            for e in tilted[:8]:
                print("       %-34s [%g,%g]" % (e['cls'], e['x'], e['y']))
            if len(tilted) > 8: print("       ... and %d more" % (len(tilted) - 8))
        print("copied edenImport.sqf + edenExport.sqf into the mission folder")
        print('in 3DEN Debug Console:  call compile preprocessFileLineNumbers "edenImport.sqf"')

    elif mode == "apply":
        if len(sys.argv) < 3: sys.exit("apply needs the export file:  apply EXPORTFILE [--allow-deletes]")
        EXP = sys.argv[2]
        allow_deletes = "--allow-deletes" in sys.argv[3:]
        if not os.path.exists(STAGED):
            sys.exit("no staged edenImport_data.sqf -- run 'extract' first (needed to know which originals to replace)")
        new = open(EXP, encoding="latin1").read().strip().strip(",").strip()
        if not new.startswith("["):
            sys.exit('export file doesn\'t look like array entries (expected ["class",...],...)')
        added = len(M.split_top(new))
        # originals that were imported (exact raw text)
        ds = open(STAGED, encoding="latin1").read()
        di = ds.index('[', ds.index('AP_data')); dj = M.matching_brace_sq(ds, di)
        imported = [t.strip() for t, _, _ in M.split_top(ds[di+1:dj])]
        imported_set = set(imported)
        rem = [e for e in ents if e['raw'].strip() in imported_set]
        removed = len(rem)
        net = added - removed
        print("edit summary:  removed %d original(s)  ->  adding %d edited  =  net %+d" % (removed, added, net))
        if removed < len(imported):
            print("  (note: %d imported originals already gone from the array -- ok if you applied before)" % (len(imported) - removed))
        if net < 0 and not allow_deletes:
            sys.exit(
                "\nABORT: the export has %d FEWER entries than were imported -- this would DELETE %d object(s).\n"
                "If you meant to delete them, re-run with  --allow-deletes .\n"
                "Otherwise: in 3DEN, Edit > Select All in the 'ArrayImport' layer (you likely missed some), re-export, retry.\n"
                "Nothing was written." % (-net, -net))
        shutil.copy(MAP, MAP+".bak")
        out = s
        for e in sorted(rem, key=lambda e: e['abs_start'], reverse=True):
            lo, hi = e['abs_start'], e['abs_end']
            if out[hi:hi+1] == ',': hi += 1
            elif out[lo-1:lo] == ',': lo -= 1
            out = out[:lo] + out[hi:]
        _, close2, _ = M.parse_array(out)
        inner = out[out.index('[', out.index('allLocalMapEntities'))+1:close2]
        sep = "" if inner.strip() == "" else ","
        out = out[:close2] + sep + new + out[close2:]
        open(MAP, "w", encoding="latin1").write(out)
        # verify the result still parses to the expected count before trusting it
        _, _, ents_after = M.parse_array(open(MAP, encoding="latin1").read())
        print("done: array %d -> %d entries. backup fn_mapData.sqf.bak. reboot to apply." % (len(ents), len(ents_after)))
        if len(ents_after) != len(ents) + net:
            print("  !! WARNING: entry-count delta (%+d) != expected net (%+d) -- inspect the diff before committing!"
                  % (len(ents_after) - len(ents), net))
    else:
        sys.exit(__doc__)

if __name__ == "__main__":
    main()
