#!/usr/bin/env python3
"""
Golden checks for the 3D map's mesh library (spec: map3d_lowpoly.md §5).

    python3 tools/test_bake_map_meshes.py

Validates the SHIPPED artifacts (malden_msh.txt + malden_bld.txt +
malden_fen.txt), not the baker's internals: format, index sanity, tri budget,
coverage, and the known house's extents against its own bake rows.

malden_fen.txt is malden_bld.txt's kind-5 (fence/wall) rows, lifted out so the
map does not parse 74% of the island before it can show the opening view. The
two are ONE artifact split in two, and the split is what this file guards: the
partition has to be exact in both directions (no fence left in bld, nothing but
fences in fen) and the gen stamps have to agree, or the page re-assembles a
world that is missing rows or holds them twice with no error anywhere.
"""
import hashlib, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HTML = ROOT / "mission/Armapunk2035.Malden/ui/html"
TRI_BUDGET = 500
fails = []
def check(ok, msg):
    print(("  ok  " if ok else "  FAIL") + " " + msg)
    if not ok: fails.append(msg)

def die(msg):
    """A malformed artifact must FAIL, never traceback -- this test exists to
    catch exactly the shapes that would crash a naive reader."""
    print("  FAIL " + msg)
    sys.exit("1 FAILED")

# ---- bld + fen rows -----------------------------------------------------------
def read_rows(name):
    """One row file -> (rows, gen stamp). Same format for both; the only
    difference between them is which kinds they are allowed to hold."""
    path = HTML / name
    if not path.exists():
        die(f"{name} is missing -- re-run tools/harvest_map_bake.py, which writes both")
    lines = path.read_text().splitlines()
    rs = [l.split(",") for l in lines[1:] if l.strip()]
    head = lines[0].lstrip("# ").split()
    if not head or not head[0].isdigit(): die(f"{name} header unreadable: {lines[0]!r}")
    check(int(head[0]) == len(rs), f"{name} count header matches ({len(rs)} rows)")
    if not all(len(r) == 9 for r in rs):
        die(f"a {name} row does not have 9 columns (x,y,dir,sx,sy,sz,kind,zbase,mid)")
    check(True, f"every {name} row has 9 columns (x,y,dir,sx,sy,sz,kind,zbase,mid)")
    return rs, next((h[4:] for h in head[1:] if h.startswith("gen=")), None)

bld_rows, bld_gen = read_rows("malden_bld.txt")
fen_rows, fen_gen = read_rows("malden_fen.txt")

# THE PARTITION, asserted in both directions. One direction alone is worthless:
# a baker that wrote every row to both files passes "fen holds only fences" and
# would render the whole island twice.
check(not [r for r in bld_rows if r[6] == "5"],
      f"malden_bld.txt holds no kind-5 rows ({len(bld_rows)} rows, fences elsewhere)")
check(all(r[6] == "5" for r in fen_rows),
      f"malden_fen.txt holds nothing but kind-5 rows ({len(fen_rows)} fences)")
check(bld_gen is not None and bld_gen == fen_gen,
      f"bld and fen carry the same gen stamp (bld={bld_gen}, fen={fen_gen})")

# Everything past this point is about the island as a whole -- the page parses
# the concatenation, so that is what coverage and the golden house are read from.
rows = bld_rows + fen_rows
mids_used = {int(r[8]) for r in rows if r[8] != "-1"}

# ---- msh library --------------------------------------------------------------
msh_lines = (HTML / "malden_msh.txt").read_text().splitlines()
lib = {}
i = 1
while i < len(msh_lines):
    h = msh_lines[i].split(" ")
    if len(h) < 5 or h[0] != "M": die(f"bad model header at line {i}: {msh_lines[i]!r}")
    try:
        mid, nv, nf, name = int(h[1]), int(h[2]), int(h[3]), h[4]
        verts = [tuple(int(x) for x in g.split(",")) for g in msh_lines[i + 1].split(" ")]
        faces = [g.split(",") for g in msh_lines[i + 2].split(" ")]
    except (ValueError, IndexError) as e:
        die(f"malformed model block at line {i}: {e}")
    if len(verts) != nv or len(faces) != nf: die(f"count mismatch in {name}")
    for f in faces:
        if not all(0 <= int(v) < nv for v in f[:3]): die(f"index out of range in {name}")
        if not (f[3] == "-" or int(f[3], 16) <= 0xFFF): die(f"bad color in {name}")
    lib[mid] = (name, verts, faces)
    i += 3
mhead = msh_lines[0].lstrip("# ").split()
if len(mhead) < 2: die(f"msh header unreadable: {msh_lines[0]!r}")
n_models, n_tris = int(mhead[0]), int(mhead[1])
msh_gen = next((h[4:] for h in mhead[2:] if h.startswith("gen=")), None)
check(len(lib) == n_models and sum(len(v[2]) for v in lib.values()) == n_tris,
      f"msh header matches content ({n_models} models, {n_tris} tris)")
check(all(len(v[2]) <= TRI_BUDGET for v in lib.values()), f"every model within {TRI_BUDGET} tris")
check(all(min(z for _, _, z in v[1]) == 0 for v in lib.values()), "every model's floor sits at up=0")

# ---- generation stamp ---------------------------------------------------------
# mids are positional; a re-harvest that does not re-bake renumbers them under a
# library that kept the old ids, and every check below still passes while wrong
# buildings render. The stamp is the only thing that catches it.
paths = ROOT / "tools/map_model_paths.txt"
live = hashlib.sha256(paths.read_text(encoding="utf-8").encode()).hexdigest()[:16] if paths.exists() else None
check(bld_gen is not None and msh_gen is not None, f"both artifacts carry a gen stamp (bld={bld_gen}, msh={msh_gen})")
check(bld_gen == msh_gen, "bld and msh stamps agree (same path list)")
check(live is None or live == msh_gen, f"stamps match the live path list ({live})")

# ---- coverage -----------------------------------------------------------------
meshed_rows = sum(1 for r in rows if int(r[8]) in lib)
check(meshed_rows / len(rows) > 0.9, f"mesh coverage {meshed_rows}/{len(rows)} rows (>90%)")
orphans = mids_used - set(lib)
print(f"       {len(orphans)} mids without a mesh (baker drops -> box fallback): expected, page-safe")

# ---- the golden house ---------------------------------------------------------
golden = [m for m, (name, _, _) in lib.items() if name == "i_house_big_01_v1_f.p3d"]
check(bool(golden), "golden model i_house_big_01_v1_f present")
if golden:
    name, verts, faces = lib[golden[0]]
    ext = [(max(c) - min(c)) / 100 for c in zip(*verts)]
    grows = [r for r in rows if r[8] != "-1" and int(r[8]) == golden[0]]
    sx, sy, sz = (float(grows[0][3]), float(grows[0][4]), float(grows[0][5]))
    ok = all(abs(e - s) <= s * 0.25 + 1.5 for e, s in zip(ext, (sx, sy, sz)))
    check(ok, f"golden extents {[round(e,1) for e in ext]} match bake row ({sx},{sy},{sz}) ±25%")
    check(len(grows) > 10, f"golden model actually used ({len(grows)} instances)")

print()
sys.exit(f"{len(fails)} FAILED" if fails else print("ALL PASS") or 0)
