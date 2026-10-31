#!/usr/bin/env python3
"""gunsmith_dump.json -> ap_gunsmith_bench_r1.p3d

The gunsmith workbench, from gunsmith.js via harness_gunsmith.mjs, per ARMA3_HANDOFF_GUNSMITH.md.

DIFFERENT FROM THE PRINTERS IN TWO WAYS.

  * IT HAS COLLISION. The printers are 0.5 m desk props the owner wanted walk-through; this is a
    2 m bench you stand at, and walking through it would look broken. The handoff hand-draws five
    convex boxes for it, and those are used verbatim -- they are authored collision, not a
    measurement proxy, so unlike the printer's geometry section there is nothing to re-derive.
    Mass 140. Small clutter (tools, brass, springs) gets none, by the same document.

  * IT USES REAL a3 TEXTURES. The printers were flat procedural colours at 0.5 m; a 2 m bench with
    a wood top and a pegboard needs the actual .paa. The handoff's material table maps every usemtl
    to a base-game path, so nothing ships with the mission and nothing can go missing.

LODs, straight from the handoff's ladder:
    1.0   everything, 8264 tris
    2.0   drop springs / loose rounds / pins / hooks / pegboard tools / fine detail  (~3.5k)
    3.0   bench boxes + pegboard + vice base/body + mat + ammo can                    (~400)
    1e13  Geometry, 5 boxes, mass 140      6e15 View       7e15 Fire

ORIGIN: centred on its own bbox, like every other simple object here -- the engine autocentres
them and discards the authored origin, so centring makes the engine's centre and ours agree and a
plain setPosASL + halfHeight lands it exactly.
"""
import collections
import copy
import filecmp
import json
import os
import re
import struct
import sys

sys.path.insert(0, '/home/timb/blender_work')
import mlod_rw                                                     # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REV = 'r2'
OUT = os.path.join(HERE, f'ap_gunsmith_bench_{REV}.p3d')

A3 = b'a3\\'
WOOD_RV = b'a3\\structures_f\\data\\wood\\wood_plank.rvmat'
# metal_plate.rvmat does not exist in the game (texture audit 2026-09-03) -- metalclean1 is the real one
PLATE_RV = b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'
CLEAN_RV = b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'
GLASS_RV = b'a3\\structures_f_exp\\data\\glass\\glass.rvmat'

# usemtl -> (texture, rvmat). Transcribed from the handoff's table; the big surfaces are base-game
# .paa paths so nothing ships with the mission, and only the small accents stay procedural.
TEX = {
    'woodfine_01_co':               (A3 + b'structures_f_enoch\\data\\wood\\woodfine_01_co.paa', WOOD_RV),
    'woodfine_01_dark':             (A3 + b'structures_f_enoch\\data\\wood\\woodfine_01_co.paa', WOOD_RV),
    'planksold_02_co':              (A3 + b'structures_f_enoch\\data\\wood\\planksold_02_co.paa', WOOD_RV),
    'wood_plank_old_co':            (A3 + b'structures_f_enoch\\data\\wood\\wood_plank_old_co.paa', WOOD_RV),
    # r2 (owner 2026-09-03, "every metal part is rusted"): the handoff's metal sheets are what the
    # viewer TINTS by material colour, but Arma shows the .paa as painted -- and eyeballed from the
    # textures_png mirror, metalcoloureddark / servicehangar_black / metalclean1 / universal_dirty /
    # green_paint are all rust-streaked or peeling at source. Only metal_gray_clean is clean. Same
    # fix as the F770 r4: dark parts go to metal_plate_04 (dark plate, no rust), bright castings to
    # metal_gray_clean, and the two one-mesh accents (bench mat, ammo can) become flat colours --
    # there is no clean rubber or clean olive sheet in the base game to point them at.
    'metalcoloureddark_co':         (A3 + b'structures_f_exp\\data\\metal\\metal_plate_04_co.paa', PLATE_RV),
    'metal_gray_clean_co':          (A3 + b'structures_f\\data\\metal\\metal_gray_clean_co.paa', CLEAN_RV),
    'metalclean1_co':               (A3 + b'structures_f\\data\\metal\\metal_gray_clean_co.paa', CLEAN_RV),
    'metal_servicehangar_black_co': (A3 + b'structures_f_exp\\data\\metal\\metal_plate_04_co.paa', CLEAN_RV),
    'metal_servicehangar_black_matte': (A3 + b'structures_f_exp\\data\\metal\\metal_plate_04_co.paa', PLATE_RV),
    'metal_universal_dirty_co':     (b'#(argb,8,8,3)color(0.10,0.10,0.11,1.0,co)', PLATE_RV),
    'metal_green_paint_co':         (b'#(argb,8,8,3)color(0.30,0.33,0.24,1.0,co)', PLATE_RV),
    'brass_proc':      (b'#(argb,8,8,3)color(0.70,0.58,0.35,1.0,co)', CLEAN_RV),
    'copper_tip_proc': (b'#(argb,8,8,3)color(0.61,0.39,0.25,1.0,co)', CLEAN_RV),
    'handle_red_proc': (b'#(argb,8,8,3)color(0.55,0.18,0.14,1.0,co)', PLATE_RV),
    'plastic_blk_proc': (b'#(argb,8,8,3)color(0.07,0.07,0.09,1.0,co)', PLATE_RV),
    'glass_jar_proc':  (b'#(argb,8,8,3)color(0.87,0.93,0.94,0.28,ca)', GLASS_RV),
    'liq_solvent_proc': (b'#(argb,8,8,3)color(0.79,0.54,0.17,0.85,ca)', GLASS_RV),
    'label_proc':      (b'#(argb,8,8,3)color(0.85,0.82,0.75,1.0,co)', b''),
    'stain_proc':      (b'#(argb,8,8,3)color(0.08,0.06,0.04,0.50,ca)', b''),
}

# LOD 2.0: everything here goes. Handoff's list, verbatim.
LOD2_DROP = re.compile(
    r'^(GS_spring_|GS_rd_|GS_pin_|GS_hook_|GS_patches$|GS_caliper_|GS_oil_spout$|'
    r'GS_barrel_thread$|GS_vice_hend_|GS_vice_lock_l$|GS_pistol_sight$|GS_stain_|'
    r'GS_wrench_|GS_pliers_|GS_file_|GS_hdriver_|GS_muff_|GS_hacksaw_)')

# LOD 3.0: only these survive.
LOD3_KEEP = re.compile(
    r'^(GS_top$|GS_edge_f$|GS_leg_|GS_apron_|GS_shelf_low$|GS_ped_r$|GS_drawer_|'
    r'GS_peg_strut_|GS_pegboard$|GS_peg_shelf$|GS_vice_base$|GS_vice_body$|GS_mat$|'
    r'GS_ammocan)')

# Geometry: the handoff's five hand-drawn convex boxes, (sizeX, sizeY, sizeZ, cx, cy, cz).
GEO_BOXES = [
    ('worktop',   2.00, 0.06, 0.80,  0.00, 0.89,  0.000),
    ('pedestal',  0.56, 0.84, 0.70,  0.70, 0.445, 0.000),
    ('legbay',    1.38, 0.86, 0.76, -0.31, 0.43,  0.000),
    ('riser',     1.94, 0.96, 0.09,  0.00, 1.37, -0.365),
    ('viceblock', 0.34, 0.22, 0.18, -0.58, 1.02,  0.160),
]
MASS = 140.0


def f32(x):
    return struct.unpack('<f', struct.pack('<f', x))[0]


class Lod:
    """Local copy -- see build_printer.py: build_lux does its work at import scope."""

    def __init__(self, res):
        self.res = res
        self.pts = []; self.norms = []; self.faces = []
        self._pt = {}; self._nm = {}
        self.selections = []
        self.comp_key = None

    def pt(self, p):
        k = (self.comp_key, f32(p[0]), f32(p[1]), f32(p[2]))
        i = self._pt.get(k)
        if i is None:
            i = len(self.pts); self._pt[k] = i; self.pts.append(k[1:])
        return i

    def nm(self, n):
        k = (f32(n[0]), f32(n[1]), f32(n[2]))
        i = self._nm.get(k)
        if i is None:
            i = len(self.norms); self._nm[k] = i; self.norms.append(k)
        return i

    def face(self, corners, tex=b'', mat=b''):
        cs = list(reversed(corners))
        nv = len(cs)
        assert nv in (3, 4)
        vs = []
        for pos, n, uv in cs:
            vs.append((self.pt(pos), self.nm((-n[0], -n[1], -n[2])), f32(uv[0]), f32(uv[1])))
        while len(vs) < 4:
            vs.append((0, 0, 0.0, 0.0))
        self.faces.append(dict(nv=nv, vs=vs, flags=0, tex=tex, mat=mat))
        return len(self.faces) - 1

    def sharp_edges(self):
        per_edge = collections.defaultdict(list)
        for f in self.faces:
            vs = f['vs'][:f['nv']]
            for k in range(len(vs)):
                a, b = vs[k], vs[(k + 1) % len(vs)]
                key = (min(a[0], b[0]), max(a[0], b[0]))
                per_edge[key].append((a[1], b[1]) if a[0] < b[0] else (b[1], a[1]))
        out = bytearray()
        for (pa, pb), uses in sorted(per_edge.items()):
            if len({u for u in uses}) > 1:
                out += struct.pack('<II', pa, pb)
        return bytes(out)

    def finish(self, mass_total=None):
        taggs = [dict(b=b'\x01', name=b'#SharpEdges#', data=self.sharp_edges())]
        for name, ptset, faceset in self.selections:
            data = bytearray(len(self.pts) + len(self.faces))
            for i in ptset: data[i] = 1
            for i in faceset: data[len(self.pts) + i] = 1
            taggs.append(dict(b=b'\x01', name=name.encode(), data=bytes(data)))
        if mass_total is not None:
            per = mass_total / len(self.pts)
            taggs.append(dict(b=b'\x01', name=b'#Mass#',
                              data=struct.pack(f'<{len(self.pts)}f', *([per] * len(self.pts)))))
        uv = bytearray(struct.pack('<I', 0))
        for f in self.faces:
            for v in f['vs'][:f['nv']]:
                uv += struct.pack('<ff', v[2], v[3])
        taggs.append(dict(b=b'\x01', name=b'#UVSet#', data=bytes(uv)))
        taggs.append(dict(b=b'\x01', name=b'#EndOfFile#', data=b''))
        return dict(hs=0x1c, lv=0x100, flags=0,
                    pts=[(x, y, z, 0) for x, y, z in self.pts],
                    norms=list(self.norms), faces=self.faces, taggs=taggs, res=self.res)


def mesh_tris(m):
    pos, nrm, uv = m['pos'], m['norm'], m['uv']
    for t in range(len(pos) // 9):
        corners = []
        for c in range(3):
            i = t * 3 + c
            corners.append(((pos[3 * i], pos[3 * i + 1], pos[3 * i + 2]),
                            (nrm[3 * i], nrm[3 * i + 1], nrm[3 * i + 2]),
                            (uv[2 * i], uv[2 * i + 1])))
        yield corners


def emit(lod, m, ctr, tex=b'', mat=b''):
    for corners in mesh_tris(m):
        lod.face([((p[0] - ctr[0], p[1] - ctr[1], p[2] - ctr[2]), n, (u, 1.0 - v))
                  for p, n, (u, v) in corners], tex=tex, mat=mat)


def add_box(lod, mn, mx, sel=None, tex=b'', mat=b''):
    P = {(i, j, k): (mx[0] if i else mn[0], mx[1] if j else mn[1], mx[2] if k else mn[2])
         for i in (0, 1) for j in (0, 1) for k in (0, 1)}
    quads = [([(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)], (-1, 0, 0)),
             ([(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)], (1, 0, 0)),
             ([(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)], (0, -1, 0)),
             ([(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)], (0, 1, 0)),
             ([(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)], (0, 0, -1)),
             ([(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)], (0, 0, 1))]
    fs, ps = [], set()
    for keys, n in quads:
        fs.append(lod.face([(P[k], n, (0.5, 0.5)) for k in keys], tex=tex, mat=mat))
    for k in P.values():
        ps.add(lod.pt(k))
    if sel is not None:
        sel[0].update(ps); sel[1].update(fs)


def main():
    data = json.load(open(f'{HERE}/gunsmith_dump.json'))['gunsmith']
    meshes, mats = data['meshes'], data['mats']

    unknown = sorted({m['mat'] for m in meshes} - set(TEX))
    assert not unknown, f'materials with no texture mapping: {unknown}'

    xs, ys, zs = [], [], []
    for m in meshes:
        p = m['pos']; xs += p[0::3]; ys += p[1::3]; zs += p[2::3]
    lo = (min(xs), min(ys), min(zs)); hi = (max(xs), max(ys), max(zs))
    ctr = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2)

    vis = Lod(1.0)
    l2 = Lod(2.0)
    l3 = Lod(3.0)
    for m in meshes:
        tex, mat = TEX[m['mat']]
        emit(vis, m, ctr, tex=tex, mat=mat)
        if not LOD2_DROP.match(m['name']):
            emit(l2, m, ctr, tex=tex, mat=mat)
        if LOD3_KEEP.match(m['name']):
            emit(l3, m, ctr, tex=tex, mat=mat)

    # ---- Geometry: the handoff's five authored boxes, each its own convex component.
    #
    # CLAMPED to the visible bounds. The pegboard riser as authored reaches 10 mm behind the
    # pegboard it represents, and the handoff's own placement note is "back against a wall" -- so
    # that 10 mm is exactly the gap that would stop the bench sitting flush, for collision nobody
    # can see. Collision may be smaller than the model and must never be larger; clamping is the
    # rule rather than editing the number, so any future authored box that overshoots is corrected
    # the same way instead of silently shipping.
    geo = Lod(1e13)
    comps = []
    clamped = []
    for (name, sx, sy, sz, cx, cy, cz) in GEO_BOXES:
        mn = [cx - sx / 2 - ctr[0], cy - sy / 2 - ctr[1], cz - sz / 2 - ctr[2]]
        mx = [cx + sx / 2 - ctr[0], cy + sy / 2 - ctr[1], cz + sz / 2 - ctr[2]]
        vlo = [lo[i] - ctr[i] for i in range(3)]
        vhi = [hi[i] - ctr[i] for i in range(3)]
        before = (list(mn), list(mx))
        for i in range(3):
            mn[i] = max(mn[i], vlo[i])
            mx[i] = min(mx[i], vhi[i])
        if (before[0], before[1]) != (mn, mx):
            clamped.append(name)
        sel = (set(), set())
        geo.comp_key = len(comps) + 1
        add_box(geo, tuple(mn), tuple(mx), sel=sel)
        comps.append(sel)
    geo.selections = [(f'Component{i:02d}', ps, fs) for i, (ps, fs) in enumerate(comps, 1)]

    geo_f = geo.finish(mass_total=MASS)
    view_f = copy.deepcopy(geo_f); view_f['res'] = 6e15
    view_f['taggs'] = [t for t in view_f['taggs'] if t['name'] != b'#Mass#']
    fire_f = copy.deepcopy(geo_f); fire_f['res'] = 7e15
    fire_f['taggs'] = [t for t in fire_f['taggs'] if t['name'] != b'#Mass#']

    lods = [vis.finish(), l2.finish(), l3.finish(), geo_f, view_f, fire_f]
    n = mlod_rw.write(OUT, 257, lods)
    ver2, back = mlod_rw.parse(OUT)
    mlod_rw.write(OUT + '.rt', ver2, back)
    assert filecmp.cmp(OUT, OUT + '.rt', shallow=False), 'round-trip mismatch'
    os.remove(OUT + '.rt')

    print(f'wrote {os.path.basename(OUT)} bytes={n}')
    if clamped:
        print(f'  clamped to the visible bounds: {", ".join(clamped)}')
    print(f'  LOD 1.0={len(lods[0]["faces"])}  2.0={len(lods[1]["faces"])}  3.0={len(lods[2]["faces"])}'
          f'  geometry={len(comps)} boxes  mass={MASS}')
    print(f'  size {hi[0]-lo[0]:.3f} x {hi[1]-lo[1]:.3f} x {hi[2]-lo[2]:.3f} m   '
          f'halfHeight={(hi[1]-lo[1])/2:.4f}')


if __name__ == '__main__':
    main()
