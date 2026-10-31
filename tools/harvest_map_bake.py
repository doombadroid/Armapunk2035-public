#!/usr/bin/env python3
"""
Harvest APS_fnc_mapBake's log dump into the assets the 3D map reads.

    python3 tools/harvest_map_bake.py [logfile]

Reads the LAST complete bake in the log (a boot can contain several), writes:
    mission/Armapunk2035.Malden/ui/html/malden_hf.txt
    mission/Armapunk2035.Malden/ui/html/malden_bld.txt
    mission/Armapunk2035.Malden/ui/html/malden_fen.txt

Formats are the MAP3D_SPEC contract:
    hf:  "# size cellMeters minH maxH" meta line, then size rows of size floats,
         NORTH ROW FIRST (the bake already emits north-first).
    bld: "# count gen=..." then x,y,dir,sx,sy,sz,kind,zbase,mid per line.
    fen: the SAME row format, holding the kind-5 (fence/wall) rows and nothing
         else; bld holds everything else.  See THE FENCE SPLIT below.
"""
import hashlib, re, sys, pathlib

log = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/home/timb/arma3server_dev/loonydev.log")
root = pathlib.Path(__file__).resolve().parent.parent / "mission/Armapunk2035.Malden/ui/html"
text = log.read_text(encoding="utf-8", errors="replace")

# last bake only: cut at the final MAPBAKE start
starts = [m.start() for m in re.finditer(r"\[MAPBAKE\] start", text)]
if not starts: sys.exit("no [MAPBAKE] start in the log")
text = text[starts[-1]:]

meta = re.search(r'\[HFDUMP\] META (\d+) (\d+) ([-\d.]+) ([-\d.]+)', text)
if not meta: sys.exit("no HFDUMP META")
n, cell, lo, hi = int(meta.group(1)), int(meta.group(2)), meta.group(3), meta.group(4)

rows = {}
for m in re.finditer(r'\[HFDUMP\] R(\d+)C(\d+) ([-\d.,e]+)', text):
    r, c = int(m.group(1)), int(m.group(2))
    rows.setdefault(r, {})[c] = m.group(3)
if len(rows) != n: sys.exit(f"heightfield incomplete: {len(rows)}/{n} rows")

hf_lines = [f"# size cellMeters minH maxH", f"{n} {cell} {lo} {hi}"]
for r in range(n):
    chunks = rows[r]
    vals = ",".join(chunks[c] for c in sorted(chunks))
    count = vals.count(",") + 1
    if count != n: sys.exit(f"row {r} has {count} values")
    hf_lines.append(vals)
(root / "malden_hf.txt").write_text("\n".join(hf_lines) + "\n", encoding="utf-8")

# Rows are "x,y,dir,sx,sy,sz,kind[,zbase[,modelpath]]" -- the 9th field (added
# for the mesh library) is a p3d path and may be empty. Split per line rather
# than one mega-regex; validate the numeric head.
raw = []
for m in re.finditer(r'\[BLDUMP\] (?!END)(.+)', text):
    # diag_log wraps the line in quotes; the capture includes the closing one
    parts = m.group(1).rstrip().rstrip('"').split(",")
    if len(parts) < 7 or len(parts) > 9: sys.exit(f"bad BLDUMP row: {m.group(1)!r}")
    try:
        [float(v) for v in parts[:8] if v != ""]
    except ValueError:
        sys.exit(f"non-numeric BLDUMP row: {m.group(1)!r}")
    raw.append(parts)
end = re.search(r'\[BLDUMP\] END n=(\d+)', text)
if not end: sys.exit("no BLDUMP END")
if len(raw) != int(end.group(1)): sys.exit(f"buildings incomplete: {len(raw)}/{end.group(1)}")
# The fed crossing ships as one hand-measured span (ramp feet from
# malden_markers.sqf); the bake excludes its 16 seabed-seated pieces, and the
# span must survive every re-harvest.
raw.append("8889.5,3765,0,891,37.1,6,4,0".split(","))

# mesh ids: one per distinct model path, first-occurrence order. Pathless rows
# (road-derived bridge decks, the hand span, empty getModelInfo) get -1 = the
# page's box fallback.
# A pre-mesh bake (8 fields, no model path) parses cleanly and would silently
# revert the whole mesh feature: every mid -1, map_model_paths.txt truncated to
# empty, next bake writes a "# 0 0" library, island back to boxes with only an
# informational print. Refuse it the same way a missing END is refused.
if not any(len(parts) > 8 and parts[8].strip().lower().endswith(".p3d") for parts in raw):
    sys.exit("no BLDUMP row carries a model path -- this log predates the mesh bake "
             "(re-run APS_fnc_mapBake on a current build before harvesting)")

mids, bld, vines = {}, [], 0
for parts in raw:
    path = parts[8].strip().lower() if len(parts) > 8 else ""
    zbase = parts[7] if len(parts) > 7 else "-999"
    # vineyard trellises arrive from the WALL sweep by the thousands -- they are
    # crops, not fences, and would render the vineyard regions as wall mazes
    if parts[6] == "5" and "vineyard" in path:
        vines += 1; continue
    mid = mids.setdefault(path, len(mids)) if path.endswith(".p3d") else -1
    bld.append(",".join(parts[:7] + [zbase, str(mid)]))
paths_file = pathlib.Path(__file__).resolve().parent / "map_model_paths.txt"
paths_text = "".join(f"{i}\t{p}\n" for p, i in sorted(mids.items(), key=lambda kv: kv[1]))
paths_file.write_text(paths_text, encoding="utf-8")

# GENERATION STAMP. mids are positional (first-occurrence order), so a re-harvest
# that adds one structure early in the sweep renumbers everything after it. If the
# mesh library is not rebaked from the SAME path list, church meshes land on sheds
# with no error anywhere. Both artifacts carry this hash; the golden test compares
# them, so a mismatched pair fails loudly instead of rendering wrong buildings.
stamp = hashlib.sha256(paths_text.encode()).hexdigest()[:16]

# THE FENCE SPLIT. Three quarters of the bake is fences (12838 of 17287 rows),
# and the 3D map cannot draw a single one of them above 10 m/px -- yet a cold
# open paid ~0.77 s of blocked main thread parsing all of them before the
# opening view could finish arriving. So they ship as their own file, which the
# page fetches only after that view has settled.
#
# The rule is kind == 5 and nothing else, in BOTH files, in bake order: the page
# re-splits the concatenation of the two, and tools/test_bake_map_meshes.py
# asserts the partition (no kind 5 in bld, only kind 5 in fen, headers and gen
# stamps agreeing) so the two cannot drift apart across a re-harvest.
fen = [b for b in bld if b.split(",")[6] == "5"]
bld = [b for b in bld if b.split(",")[6] != "5"]

def write_rows(name, rows):
    (root / name).write_text(f"# {len(rows)} gen={stamp}\n" + "\n".join(rows) + "\n",
                             encoding="utf-8")
write_rows("malden_bld.txt", bld)
write_rows("malden_fen.txt", fen)

allrows = bld + fen
kinds = {}
for b in allrows: k = b.split(",")[6]; kinds[k] = kinds.get(k, 0) + 1
meshed = sum(1 for b in allrows if b.split(",")[8] != "-1")
print(f"heightfield: {n}x{n} @ {cell}m  range {lo}..{hi}")
print(f"buildings:   {len(allrows)}  by kind: {dict(sorted(kinds.items()))}  abs-base rows: {sum(1 for b in allrows if b.split(',')[7]!='-999')}")
print(f"             split: {len(bld)} -> malden_bld.txt, {len(fen)} fences -> malden_fen.txt")
print(f"meshes:      {len(mids)} distinct models cover {meshed}/{len(allrows)} rows -> {paths_file.name}  (vineyard rows dropped: {vines})")
print(f"sizes: hf {((root/'malden_hf.txt').stat().st_size)//1024}KB  bld {((root/'malden_bld.txt').stat().st_size)//1024}KB  fen {((root/'malden_fen.txt').stat().st_size)//1024}KB")
