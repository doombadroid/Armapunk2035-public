#!/usr/bin/env python3
"""
eden_sqf_to_mapdata.py -- convert a BIS_fnc_3DENExportSQF dump into LooneyBin
allLocalMapEntities entries (fn_mapData.sqf format).

This is the clean pipeline: build/edit in Eden -> SELECT the objects you want ->
Tools>Debug Console -> [true,false] call BIS_fnc_3DENExportSQF -> save the result
to a file (e.g.  wl-paste > /tmp/export.sqf ) -> run this.

  python3 tools/eden_sqf_to_mapdata.py /tmp/export.sqf          # print entries
  python3 tools/eden_sqf_to_mapdata.py /tmp/export.sqf --insert # append to fn_mapData.sqf (.bak first)

Why it works cleanly: BIS export writes  createVehicle ["Cls",[x,y,z],...]  where z is
ABOVE-GROUND (ATL) -- exactly what the array's setPosATL wants. No terrain math.
Markers / groups / logics / modules are ignored (only Objects + Units become entries).
Init code is taken from the export's Inits section, with `this` -> `_this`.
"""
import sys, re, os, argparse, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
MAP  = os.path.join(HERE, "..", "mission", "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")

CREATE = re.compile(
    r'(_item\d+)\s*=\s*(?:_item\d+\s+)?create(?:Vehicle|SimpleObject|Unit)\s*\[\s*"([^"]+)"\s*,\s*'
    r'\[\s*([-0-9.eE]+)\s*,\s*([-0-9.eE]+)\s*,\s*([-0-9.eE]+)\s*\]')
VDU = re.compile(
    r'setVectorDirAndUp\s*\[\s*\[\s*([-0-9.eE]+)\s*,\s*([-0-9.eE]+)\s*,\s*([-0-9.eE]+)\s*\]\s*,\s*'
    r'\[\s*([-0-9.eE]+)\s*,\s*([-0-9.eE]+)\s*,\s*([-0-9.eE]+)\s*\]')

def brace_match(s, i):
    d = 0
    while i < len(s):
        if s[i] == '{': d += 1
        elif s[i] == '}':
            d -= 1
            if d == 0: return i
        i += 1
    return -1

def inits_map(s):
    """item -> init code, parsed from the `// Inits` section."""
    out = {}
    for m in re.finditer(r'if\s*!\(isnull\s+(_item\d+)\)\s*then\s*\{', s):
        item = m.group(1)
        ob = s.index('{', m.start())
        cb = brace_match(s, ob)
        if cb < 0: continue
        body = s[ob+1:cb]
        body = re.sub(r'^\s*this\s*=\s*_item\d+\s*;', '', body, count=1)  # drop the `this = _itemN;`
        out[item] = body.strip()
    return out

def esc_init(code):
    code = re.sub(r'(?<![\w])this(?![\w])', '_this', code)   # object ref -> spawner's _this
    code = code.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ')
    code = re.sub(r'\s+', ' ', code).strip()
    code = code.replace('"', '""')                          # inner quotes for the array string literal
    return code

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("export", help="file containing the BIS_fnc_3DENExportSQF output")
    ap.add_argument("--insert", action="store_true", help="append entries into fn_mapData.sqf (.bak first)")
    ap.add_argument("--map", default=MAP)
    args = ap.parse_args()

    s = open(args.export, encoding="latin1").read()
    # scope to the Objects section if present (so we skip markers/units-in-groups we don't want? keep units too)
    inits = inits_map(s)

    entries = []
    # iterate object/unit create blocks across the whole file; grab the vectors that follow each create
    for m in CREATE.finditer(s):
        item, cls, x, y, z = m.groups()
        tail = s[m.end(): m.end()+1200]          # look ahead within this block for the vectors
        vm = VDU.search(tail)
        if vm:
            dx, dy, dz, ux, uy, uz = vm.groups()
        else:
            dx, dy, dz, ux, uy, uz = "0", "1", "0", "0", "0", "1"
        init = inits.get(item, "")
        entries.append('["%s",[%s,%s,%s],[[%s,%s,%s],[%s,%s,%s]],"%s",false]'
                       % (cls, x, y, z, dx, dy, dz, ux, uy, uz, esc_init(init)))

    print("// %d object/unit entr(y/ies)" % len(entries))
    for e in entries:
        print(e + ",")

    if args.insert:
        if not entries: sys.exit("nothing to insert")
        m = open(args.map, encoding="latin1").read()
        t = m.rstrip()
        if not t.endswith('];'): sys.exit("fn_mapData.sqf doesn't end with '];'")
        new = t[:-2] + "," + ",".join(entries) + "];" + m[len(t):]
        shutil.copy(args.map, args.map + ".bak")
        open(args.map, "w", encoding="latin1").write(new)
        print("// inserted %d entries into fn_mapData.sqf (backup: fn_mapData.sqf.bak)" % len(entries))

if __name__ == "__main__":
    main()
