#!/usr/bin/env python3
"""
Bake the 3D map's low-poly mesh library: malden_msh.txt.

    python3 tools/bake_map_meshes.py            # full run
    python3 tools/bake_map_meshes.py --only 12  # one mid, verbose

Input:  tools/map_model_paths.txt      (mid<TAB>model path, from harvest_map_bake.py)
        the game install's PBOs        (a3\\... paths, ODOL v64-75)
        the mission's custom_p3ds      (mission paths, MLOD)
        textures_png/INDEX.txt         (face colors: average of the real diffuse)
Output: mission/Armapunk2035.Malden/ui/html/malden_msh.txt

Per model: its own COARSEST visual resolution LOD (the artist's low-poly),
welded, triangulated, cluster-decimated only if it still exceeds TRI_BUDGET,
one rgb444 color per face. Verts are centimetre ints in PAGE axes
(east, north, up) = p3d (x, z, y), plan-centred on the footprint, up relative
to the bbox floor -- the page rotates by the row's dir and seats the floor
exactly like it seats a box.

Spec: map3d_lowpoly.md. Reader lives in map.html (parseMeshLib).
"""
import json, math, os, re, struct, sys, pathlib

ROOT      = pathlib.Path(__file__).resolve().parent.parent
BW        = pathlib.Path.home() / "blender_work"
GAME      = pathlib.Path.home() / ".local/share/Steam/steamapps/common/Arma 3"
MISSION   = ROOT / "mission/Armapunk2035.Malden"
TEXPNG    = ROOT / "textures_png"
OUT       = MISSION / "ui/html/malden_msh.txt"
PATHS_IN  = ROOT / "tools/map_model_paths.txt"
BLD_IN    = MISSION / "ui/html/malden_bld.txt"
TRI_BUDGET = 500     # per-model ceiling (owner 2026-08-27: "a little more detailed")
DETAIL_MIN = 140     # prefer the coarsest LOD at or above this; below it, take a finer one
SHADOW_SWITCH = 4000 # visual LOD bigger than this -> try the artist's shadow LOD instead
PAL = None           # module palette handle, set in main() (transfer_colors votes need it)
sys.path.insert(0, str(BW))
import odol73_to_mlod as odol
import mlod_rw

# ---------------------------------------------------------------- PBO index
# pboread.py slurps whole PBOs; the index below reads headers only and
# extracts single entries by seek, because structures PBOs run to gigabytes.

def _pbo_header(fh):
    """-> (prefix, [(name, mime, orig, size, offset)]) reading the header only."""
    def z():
        b = bytearray()
        while True:
            c = fh.read(1)
            if not c or c == b"\0": return bytes(b)
            b += c
    prefix, entries = "", []
    while True:
        name = z()
        mime, orig, rsv, ts, size = struct.unpack("<5I", fh.read(20))
        if name == b"" and mime == 0x56657273:          # 'Vers' property block
            while True:
                k = z()
                if k == b"": break
                v = z()
                if k.decode("latin1").lower() == "prefix":
                    prefix = v.decode("latin1").strip("\\").lower()
            continue
        if name == b"" and size == 0: break
        entries.append((name.decode("latin1").lower(), mime, orig, size))
    off = fh.tell()
    out = []
    for name, mime, orig, size in entries:
        out.append((name, mime, orig, size, off)); off += size
    return prefix, out

def _lzss(src, expected):
    """BI PBO LZSS ('Cprs' entries). Trailing 4-byte checksum ignored."""
    out = bytearray()
    i = 0
    while len(out) < expected and i < len(src):
        flags = src[i]; i += 1
        for bit in range(8):
            if len(out) >= expected or i >= len(src): break
            if flags & (1 << bit):
                out.append(src[i]); i += 1
            else:
                b1, b2 = src[i], src[i + 1]; i += 2
                rpos = len(out) - (((b2 & 0xF0) << 4) | b1)
                rlen = (b2 & 0x0F) + 3
                if rpos + rlen <= 0:
                    out.extend(b"\x20" * rlen)          # before start = spaces
                else:
                    for _ in range(rlen):
                        out.append(out[rpos] if rpos >= 0 else 0x20); rpos += 1
    return bytes(out)

class PboIndex:
    def __init__(self, game_root):
        self.by_prefix = {}          # prefix -> (pbo path, {entry name: (mime, orig, size, off)})
        roots = [game_root / "Addons"] + sorted(game_root.glob("*/Addons"))
        for r in roots:
            if not r.is_dir(): continue
            for p in sorted(r.glob("*.pbo")):
                try:
                    with open(p, "rb") as fh:
                        prefix, entries = _pbo_header(fh)
                except Exception as e:
                    print(f"  WARN unreadable pbo {p.name}: {e}"); continue
                if not prefix: continue
                self.by_prefix.setdefault(prefix, (p, {n: (m, o, s, f) for n, m, o, s, f in entries}))

    def extract(self, path):
        """path like a3\\structures_f\\...\\x.p3d -> bytes, or None."""
        path = path.lower().replace("/", "\\")
        for prefix, (pbo, entries) in self.by_prefix.items():
            if path.startswith(prefix + "\\"):
                rel = path[len(prefix) + 1:]
                if rel in entries:
                    mime, orig, size, off = entries[rel]
                    with open(pbo, "rb") as fh:
                        fh.seek(off); raw = fh.read(size)
                    if mime == 0x43707273:               # 'Cprs'
                        return _lzss(raw, orig)
                    return raw
        return None

# ------------------------------------------------------------- face colors
_PROC = re.compile(r"#\(argb,\d+,\d+,\d+\)color\(([\d.]+),([\d.]+),([\d.]+)")

class Palette:
    def __init__(self, texpng_root):
        self.root = texpng_root
        self.index = {}
        idx = texpng_root / "INDEX.txt"
        if idx.exists():
            for line in idx.read_text(encoding="utf-8", errors="replace").splitlines():
                m = re.match(r"(.+?) -> (\S+) \d+x\d+$", line.strip())
                if m: self.index[m.group(1).lower()] = m.group(2)
        self.cache = {}
        self.misses = set()
        self.matcache = {}
        self.matmisses = set()
        self.pbos = None          # set in main() -- rvmats live in the game PBOs

    @staticmethod
    def _floor_dark(c):
        """In-game, near-black surfaces are tinted GLASS -- env reflections keep
        them alive. Flat lambert renders them as voids (the palace facade is
        28k m2 of color(0,0,0)), so lift anything under a luma floor to a dark
        glass blue-grey. Night stripes/rims still ride on top."""
        if c < 0: return c
        r, g, bl = (c >> 8) & 15, (c >> 4) & 15, c & 15
        if r + g + bl >= 5: return c
        return (max(r, 1) << 8) | (max(g, 2) << 4) | max(bl, 3)

    def material_color(self, mat):
        """rvmat path -> rgb444 from the diffuse (_co) texture it names, or -1.

        An rvmat is a binarised (raP) config, but the texture paths inside are
        plain asciiz, so the diffuse reference is greppable without a config
        parser. Only `_co` is diffuse -- `_dt/_smdi/_nohq/_mask/_as` are
        normal/specular/mask channels and would poison the average."""
        m = (mat.decode("latin1") if isinstance(mat, bytes) else mat).lower().strip()
        if not m.endswith(".rvmat"): return -1
        if m in self.matcache: return self.matcache[m]
        c = -1
        blob = self.pbos.extract(m) if self.pbos else None
        if blob:
            for cand in re.findall(rb"[A-Za-z0-9_\\/.]+\.paa", blob):
                s = cand.decode("latin1").lower()
                if s.endswith("_co.paa"):
                    c = self.face_color(s)
                    if c >= 0: break
        self.matcache[m] = c
        if c < 0: self.matmisses.add(m)
        return c

    def face_color(self, tex):
        """tex bytes/str, or a (texture, rvmat) pair -> rgb444 int, or -1.

        Coarse ODOL LODs routinely carry NO texture and only a material, so the
        pair form falls back to the rvmat's own diffuse rather than dropping the
        face to flat kind color."""
        if isinstance(tex, tuple):
            tex, mat = tex
            c = self.face_color(tex)
            return c if c >= 0 else self.material_color(mat)
        t = (tex.decode("latin1") if isinstance(tex, bytes) else tex).lower().strip()
        if not t: return -1
        if t.startswith("#col:"): return int(t[5:], 16)   # pre-resolved (already floored)
        m = _PROC.match(t)
        if m:
            r, g, b = (min(1.0, float(v)) for v in m.groups())
            # procedural color() is linear; the mirror PNGs are sRGB -- match them
            srgb = lambda c: int(round((c ** (1 / 2.2)) * 255))
            return self._floor_dark(((srgb(r) >> 4) << 8) | ((srgb(g) >> 4) << 4) | (srgb(b) >> 4))
        if t in self.cache: return self.cache[t]
        rel = self.index.get(t.lstrip("\\"))
        if rel is None:
            self.misses.add(t); return -1
        from PIL import Image
        try:
            im = Image.open(self.root / rel).convert("RGB").resize((8, 8))
            px = list(im.getdata())
            r = sum(p[0] for p in px) // 64; g = sum(p[1] for p in px) // 64; b = sum(p[2] for p in px) // 64
            c = self._floor_dark(((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4))
        except Exception:
            c = -1
        self.cache[t] = c
        return c

# ------------------------------------------------------------ geometry core

def lod_triangles(verts, faces, face_tex):
    """-> [(p0,p1,p2,tex)] with p in p3d coords, quads split, degenerates kept for now."""
    tris = []
    for f, tex in zip(faces, face_tex):
        idx = [i for i in f if 0 <= i < len(verts)]
        if len(idx) < 3: continue
        tris.append((verts[idx[0]], verts[idx[1]], verts[idx[2]], tex))
        if len(idx) == 4:
            tris.append((verts[idx[0]], verts[idx[2]], verts[idx[3]], tex))
    return tris

def build_mesh(tris, palette, budget=TRI_BUDGET):
    """tris in p3d coords -> (verts_cm[(x,y,z)page], faces[(a,b,c,rgb444)]) welded,
    decimated to budget by vertex clustering if needed."""
    # page axes: east = p3d x, north = p3d z, up = p3d y
    pts = [(p[0], p[2], p[1]) for t in tris for p in t[:3]]
    if not pts: return [], []
    xs, ys, zs = zip(*pts)
    cx, cy, z0 = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)
    span = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs), 0.5)

    lox, hix = min(xs) - cx, max(xs) - cx
    loy, hiy = min(ys) - cy, max(ys) - cy
    hiz = max(zs) - z0

    def emit(snap):
        vmap, verts, faces, seen = {}, [], [], set()
        for a, b, c, tex in tris:
            ids = []
            for p in (a, b, c):
                q = (p[0] - cx, p[2] - cy, p[1] - z0)
                if snap > 0:
                    # snap for the collapse, then clamp back inside the raw bbox --
                    # unclamped, a coarse grid inflates a tower's extents by snap/2
                    q = (min(max(round(q[0] / snap) * snap, lox), hix),
                         min(max(round(q[1] / snap) * snap, loy), hiy),
                         min(max(round(q[2] / snap) * snap, 0), hiz))
                key = tuple(int(round(v * 100)) for v in q)
                if key not in vmap:
                    vmap[key] = len(verts); verts.append(key)
                ids.append(vmap[key])
            if ids[0] == ids[1] or ids[1] == ids[2] or ids[0] == ids[2]: continue
            fkey = (frozenset(ids), )
            if fkey in seen: continue
            seen.add(fkey)
            faces.append((ids[0], ids[1], ids[2], palette.face_color(tex)))
        return verts, faces

    verts, faces = emit(0)
    snap = span / 64
    while len(faces) > budget and snap < span:
        verts, faces = emit(snap)
        snap *= 1.6
    return verts, faces

def _extent(tris):
    pts = [p for t in tris for p in t[:3]]
    if not pts: return (0, 0, 0)
    xs, ys, zs = zip(*(p[:3] for p in pts))
    return (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))

def _sane(cands, ref):
    """keep LODs whose extents reach >=60% of the reference extent per axis --
    some far LODs collapse to a roof slab or drop a wing (shed_big's is a
    single plane); those read as boxes-with-holes on the page."""
    out = []
    for res, tris in cands:
        e = _extent(tris)
        if all(ev >= rv * 0.6 - 0.3 for ev, rv in zip(e, ref)): out.append((res, tris))
    return out

def transfer_colors(dst, src, pal):
    """dst tris (shadow LOD, untextured) get colors from the visual LOD: an
    AREA-WEIGHTED VOTE over the 12 nearest visual faces. Nearest-1 painted
    whole palace wings window-glass black -- one sliver outvoting the wall."""
    import numpy as np
    A = np.array([t[0] for t in src]); B = np.array([t[1] for t in src]); C = np.array([t[2] for t in src])
    sc = (A + B + C) / 3
    area = np.linalg.norm(np.cross(B - A, C - A), axis=1) / 2 + 1e-6
    cols = [pal.face_color(t[3]) for t in src]
    out = []
    K = min(12, len(src))
    for a, b, c, _ in dst:
        cen = (np.array(a) + np.array(b) + np.array(c)) / 3
        d2 = ((sc - cen) ** 2).sum(axis=1)
        near = np.argpartition(d2, K - 1)[:K]
        score = {}
        for j in near:
            score[cols[j]] = score.get(cols[j], 0.0) + float(area[j])
        win = max(score, key=score.get)
        out.append((a, b, c, "#COL:%03x" % win if win >= 0 else b""))
    return out

def choose_source(vis, shadow, detail_min=DETAIL_MIN):
    """vis/shadow = [(res, tris)]. Pick the geometry to ship:
    - coarsest SANE visual LOD with >= detail_min tris (else the coarsest sane;
      fences pass detail_min=0 -- 11.8k instances cannot afford detail)
    - a huge pick (> SHADOW_SWITCH) swaps to the artist's shadow LOD when one
      exists with real shape (>=100 tris; generated towers ship a 24-tri box
      shadow -- useless), colors transferred from the finest visual LOD."""
    if not vis: return None
    ref = _extent(min(vis, key=lambda rt: rt[0])[1])     # finest visual = truth
    sane = _sane(vis, ref) or [min(vis, key=lambda rt: rt[0])]
    sane.sort(key=lambda rt: -rt[0])                     # coarse first
    pick = next((rt for rt in sane if len(rt[1]) >= detail_min), sane[-1])
    if len(pick[1]) > SHADOW_SWITCH and shadow:
        sh = [rt for rt in _sane(shadow, ref) if 100 <= len(rt[1]) <= 8000]
        if sh:
            best = max(sh, key=lambda rt: len(rt[1]))
            finest = min(vis, key=lambda rt: rt[0])
            return transfer_colors(best[1], finest[1], PAL), best[0]
    return pick[1], pick[0]

def load_odol_lod(blob, tmpdir, name, detail_min=DETAIL_MIN):
    tmp = tmpdir / (re.sub(r"\W", "_", name) + ".p3d")
    tmp.write_bytes(blob)
    try:
        model = odol.read_odol(str(tmp))
    finally:
        tmp.unlink(missing_ok=True)
    vis, shadow = [], []
    for res, lod in zip(model["resolutions"], model["lods"]):
        # res 0 IS a visual LOD -- odol73_to_mlod's own winding_vote excludes only
        # res >= 900. Nine models (helipads, crossings) have res 0 as their ONLY
        # visual LOD and used to bake as "no visual lod".
        band = vis if 0 <= res < 900 else shadow if 1e4 <= res < 2e4 else None
        if band is None: continue
        ft = list(odol.face_texmat(lod))          # (texture, rvmat) per face
        band.append((res, lod_triangles(lod["verts"], lod["faces"], ft)))
    return choose_source(vis, shadow, detail_min)

def load_mlod_lod(path, detail_min=DETAIL_MIN):
    ver, lods = mlod_rw.parse(str(path))
    vis, shadow = [], []
    for lod in lods:
        res = lod["res"]
        band = vis if 0 <= res < 900 else shadow if 1e4 <= res < 2e4 else None
        if band is None: continue
        verts = [(p[0], p[1], p[2]) for p in lod["pts"]]
        faces = [[v[0] for v in f["vs"][:f["nv"]]] for f in lod["faces"]]
        ft = [(f["tex"], f["mat"]) for f in lod["faces"]]
        band.append((res, lod_triangles(verts, faces, ft)))
    return choose_source(vis, shadow, detail_min)

def profile_stack(tris, bands=12):
    """A generated tower's only LOD runs to ~100k tris; clustering that down to
    200 turns walls into mush. Its massing IS a stack of boxes, so rebuild it as
    one: slice by height, per-slice plan bbox, extruded ring per slice. Setbacks
    and the crown taper survive; windows are the page's night stripes anyway.
    Returns tris in p3d coords, one modal texture per band for the color."""
    ys = [p[1] for t in tris for p in t[:3]]
    y0, y1 = min(ys), max(ys)
    step = (y1 - y0) / bands or 1
    out = []
    for b in range(bands):
        lo, hi = y0 + b * step, y0 + (b + 1) * step
        band = [t for t in tris if lo <= (t[0][1] + t[1][1] + t[2][1]) / 3 < hi or (b == bands - 1 and (t[0][1] + t[1][1] + t[2][1]) / 3 >= hi)]
        if not band: continue
        px = [p[0] for t in band for p in t[:3]]; pz = [p[2] for t in band for p in t[:3]]
        x0, x1, z0, z1 = min(px), max(px), min(pz), max(pz)
        texn = {}
        for t in band: texn[t[3]] = texn.get(t[3], 0) + 1
        tex = max(texn, key=texn.get)
        c = [(x0, lo, z0), (x1, lo, z0), (x1, lo, z1), (x0, lo, z1),
             (x0, hi, z0), (x1, hi, z0), (x1, hi, z1), (x0, hi, z1)]
        quads = [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7), (3, 2, 1, 0)]
        for q in quads:
            out.append((c[q[0]], c[q[1]], c[q[2]], tex))
            out.append((c[q[0]], c[q[2]], c[q[3]], tex))
    return out

# ---------------------------------------------------------------- main
def main():
    only = None
    if "--only" in sys.argv: only = int(sys.argv[sys.argv.index("--only") + 1])
    if not PATHS_IN.exists(): sys.exit(f"missing {PATHS_IN} -- run harvest_map_bake.py first")
    models = []
    for line in PATHS_IN.read_text(encoding="utf-8").splitlines():
        mid, path = line.split("\t", 1)
        models.append((int(mid), path.strip()))

    # median row extents + dominant kind per mid (fences get coarse, tiny meshes)
    med, kindmap = {}, {}
    if BLD_IN.exists():
        rows, kinds = {}, {}
        for line in BLD_IN.read_text(encoding="utf-8").splitlines()[1:]:
            p = line.split(",")
            if len(p) < 9 or p[8] == "-1": continue
            rows.setdefault(int(p[8]), []).append((float(p[3]), float(p[4]), float(p[5])))
            kinds.setdefault(int(p[8]), []).append(int(p[6]))
        for mid, rs in rows.items():
            rs.sort()
            med[mid] = rs[len(rs) // 2]
            ks = kinds[mid]
            kindmap[mid] = max(set(ks), key=ks.count)

    import tempfile
    tmpdir = pathlib.Path(tempfile.mkdtemp(prefix="mshbake_"))
    pbos = PboIndex(GAME)
    print(f"pbo index: {len(pbos.by_prefix)} prefixes")
    global PAL
    pal = PAL = Palette(TEXPNG)
    pal.pbos = pbos          # rvmat lookups go through the same PBO index
    print(f"texture index: {len(pal.index)} entries")

    out_models, missing, dropped, stats = [], [], [], []
    for mid, path in models:
        if only is not None and mid != only: continue
        tris = None
        # a fence exists 11.8k times -- it gets the coarsest LOD and a hard 40-tri
        # cap, or the page's per-instance VBOs outgrow everything else combined
        fence = kindmap.get(mid) == 5
        dmin, budget = (0, 40) if fence else (DETAIL_MIN, TRI_BUDGET)
        try:
            if path.startswith("a3\\"):
                blob = pbos.extract(path)
                if blob is None: missing.append((mid, path, "not in any pbo")); continue
            else:
                base = path.replace("/", "\\").rsplit("\\", 1)[-1]
                cand = {p.name.lower(): p for p in (MISSION / "custom_p3ds").glob("*.p3d")}
                f = cand.get(base) or ((MISSION / base) if (MISSION / base).exists() else None)
                if f is None: missing.append((mid, path, "no mission file")); continue
                blob = f.read_bytes()
            # route by magic, not by where the file lives -- the mission's own
            # p3ds ship binarized (ODOL), and a PBO could in principle hold MLOD
            if blob[:4] == b"ODOL":
                got = load_odol_lod(blob, tmpdir, path.rsplit("\\", 1)[-1], dmin)
            elif blob[:4] == b"MLOD":
                tmp = tmpdir / "m.p3d"; tmp.write_bytes(blob)
                got = load_mlod_lod(tmp, dmin); tmp.unlink(missing_ok=True)
            else:
                missing.append((mid, path, f"unknown magic {blob[:4]!r}")); continue
            if got is None: missing.append((mid, path, "no visual lod")); continue
            tris, res = got
        except Exception as e:
            missing.append((mid, path, f"parse: {type(e).__name__} {e}")); continue
        raw_n = len(tris)
        if raw_n > 20000:
            # only TOWERS (height dominates plan) get the profile stack; a wide
            # landmark this big with no usable shadow LOD just gets clustered
            ex, ey, ez = _extent(tris)                   # p3d frame: ey = up
            if ey > 1.3 * max(ex, ez, 0.1): tris = profile_stack(tris)
        verts, faces = build_mesh(tris, pal, budget)
        if not faces: missing.append((mid, path, "empty after weld")); continue

        def _ext(vs):
            xs = [v[0] for v in vs]; ys = [v[1] for v in vs]; zs = [v[2] for v in vs]
            return ((max(xs) - min(xs)) / 100, (max(ys) - min(ys)) / 100, (max(zs) - min(zs)) / 100)

        # cross-check vs the bake's own boundingBoxReal (page x<->sx, y<->sy, up<->sz)
        if mid in med:
            sx, sy, sz = med[mid]
            ext = _ext(verts)
            if any(e > s * 1.25 + 1.5 for e, s in zip(ext, (sx, sy, sz))):
                # bigger than the engine's own bbox = apron/billboard/holo geometry
                # the engine does not count. Clip to the row box and retry.
                pc = [(p[0], p[2], p[1]) for t in tris for p in t[:3]]
                cx = (min(q[0] for q in pc) + max(q[0] for q in pc)) / 2
                cy = (min(q[1] for q in pc) + max(q[1] for q in pc)) / 2
                z0 = min(q[2] for q in pc)
                keep = [t for t in tris if all(
                    abs(p[0] - cx) <= sx * 0.575 + 1 and abs(p[2] - cy) <= sy * 0.575 + 1
                    and (p[1] - z0) <= sz * 1.15 + 2 for p in t[:3])]
                verts, faces = build_mesh(keep, pal, budget)
                ext = _ext(verts) if faces else (0, 0, 0)
                if not faces or any(e > s * 1.25 + 1.5 for e, s in zip(ext, (sx, sy, sz))):
                    dropped.append((mid, path, f"oversize {tuple(round(e,1) for e in ext)} vs row {med[mid]}"))
                    continue
            if ext[2] < 0.3:
                # flat decal -- coplanar with the terrain, z-fights; keep the box
                dropped.append((mid, path, "flat decal")); continue
            if sx * sy >= 40 and ext[2] < sz * 0.85 and (ext[0] < sx * 0.55 or ext[1] < sy * 0.55):
                # full-height towers on a proxy-widened base (lighthouse) stay --
                # the slender real shape beats the fat box. The test below drops
                # a real building missing most of its plan (proxy-carried wings the
                # visual LOD never contains) reads as half a hulk -- box massing wins
                dropped.append((mid, path, f"partial {tuple(round(e,1) for e in ext)} vs row {med[mid]}"))
                continue
        stats.append((raw_n, len(faces)))
        out_models.append((mid, path, verts, faces))

    # generation stamp: the hash of the path list this library was baked from.
    # test_bake_map_meshes.py fails when it disagrees with malden_bld.txt's, which
    # is what catches "re-harvested but never re-baked" mid renumbering.
    import hashlib
    stamp = hashlib.sha256(PATHS_IN.read_text(encoding="utf-8").encode()).hexdigest()[:16]
    lines = [f"# {len(out_models)} {sum(len(f) for _, _, _, f in out_models)} gen={stamp}"]
    for mid, path, verts, faces in out_models:
        lines.append(f"M {mid} {len(verts)} {len(faces)} {path.rsplit(chr(92), 1)[-1]}")
        lines.append(" ".join(f"{v[0]},{v[1]},{v[2]}" for v in verts))
        lines.append(" ".join(f"{a},{b},{c},{col:03x}" if col >= 0 else f"{a},{b},{c},-" for a, b, c, col in faces))
    if only is None:
        OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"\nmeshed {len(out_models)}/{len(models)} models -> {OUT.name} "
          f"({OUT.stat().st_size // 1024 if only is None and OUT.exists() else 0}KB)")
    if stats:
        b = sorted(s[1] for s in stats)
        print(f"tris/model: min {b[0]} med {b[len(b)//2]} max {b[-1]}  "
              f"(decimated: {sum(1 for r, f in stats if f < r and r > TRI_BUDGET)})")
    if pal.misses: print(f"texture misses (material fallback tried): {len(pal.misses)}")
    if pal.matmisses: print(f"material misses (kind-color fallback): {len(pal.matmisses)}")
    flat = sum(1 for _, _, _, fs in out_models for f in fs if f[3] < 0)
    tot = sum(len(fs) for _, _, _, fs in out_models) or 1
    print(f"faces on kind color: {flat}/{tot} ({100.0*flat/tot:.1f}%)")
    for mid, path, why in missing: print(f"  MISS mid {mid}: {path} -- {why}")
    for mid, path, why in dropped: print(f"  DROP mid {mid}: {path} -- {why} (box fallback)")

if __name__ == "__main__":
    main()
