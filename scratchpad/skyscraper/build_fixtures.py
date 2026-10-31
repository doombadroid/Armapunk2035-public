#!/usr/bin/env python3
"""lux_dump.json -> ap_kitchen_r1.p3d / ap_shower_r1.p3d / ap_toilet_r1.p3d

The v18 lux tower fits every suite with a kitchen, a shower and a toilet. They
are instanced 29x each in the viewer, which is 536k of the model's 666k
triangles, and the handoff is explicit:

    "For the P3D: do NOT import 29 copies. Build each fixture as its own p3d
     once and place them with proxies (or as separate editor objects)."

So each fixture becomes one p3d, spawned per floor by the same local-simple-object
route the door leaves already use (custom_p3ds/lux_fixtures.sqf).

ORIGIN: each fixture's geometry is CENTRED ON ITS OWN BBOX. Simple objects are
autocentred by the engine — authored origins are discarded — and centring here
means the engine's centre and ours agree, so a plain setPosASL lands it exactly.
That is what lets the spawner skip the ray-calibration dance the door leaves
needed (they could not be centred: they must rotate about a hinge at their edge).

COLLISION comes from each fixture's own handoff, never from the visual shells:
  kitchen  carcasses, plinth, tops, oven bay  (named meshes, one box each)
  shower   tray, lip, back/left walls, ceiling, bench, bench top
  toilet   FOUR hand-drawn boxes -- the bowl shells are concave swept squircles
           and must not be hulled ("players cannot enter the bowl")

The toilet also gets a coarse second resolution LOD built from those collision
boxes, exactly as its handoff suggests: at 15.6k triangles it is the one fixture
heavy enough to matter 29 times over, and this lets Arma drop it to ~12 faces
once it is small on screen.
"""
import json, os, sys, copy, filecmp
sys.path.insert(0, '/home/timb/blender_work')
import mlod_rw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_lux import Lod, add_box, TEX          # reuse the tower's writer + material map

dump = json.load(open(f'{HERE}/lux_dump.json'))
meshes = [m for m in dump['meshes']]

# fixtures are instanced per floor; floor 2 is the reference copy
FIX = {
    'kitchen': ('F02_KITCHEN', 'ap_kitchen_r1'),
    'shower':  ('F02_SHOWER',  'ap_shower_r1'),
    'toilet':  ('F02_TOILET',  'ap_toilet_r1'),
}

# materials the fixtures use that the tower's TEX map does not already carry
EXTRA_TEX = {
    'steel_proc':            (b'#(argb,8,8,3)color(0.62,0.64,0.66,1.0,co)',
                              b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'matte_black_proc':      (b'#(argb,8,8,3)color(0.09,0.09,0.10,1.0,co)',
                              b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'porcelain_white_proc':  (b'#(argb,8,8,3)color(0.93,0.93,0.92,1.0,co)',
                              b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'seat_white_proc':       (b'#(argb,8,8,3)color(0.88,0.88,0.87,1.0,co)',
                              b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'burner_proc':           (b'#(argb,8,8,3)color(0.15,0.15,0.16,1.0,co)',
                              b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'led_warm_proc':         (b'#(argb,8,8,3)color(1.00,0.90,0.72,1.0,co)', b''),
    'water_proc':            (b'#(argb,8,8,3)color(0.55,0.70,0.78,0.65,ca)',
                              b'a3\\structures_f_exp\\data\\glass\\glass.rvmat'),
    'glass_clear_proc':      (b'#(argb,8,8,3)color(0.80,0.86,0.88,0.35,ca)',
                              b'a3\\structures_f_exp\\data\\glass\\glass.rvmat'),
    'glass_black_proc':      (b'#(argb,8,8,3)color(0.08,0.09,0.10,0.80,ca)',
                              b'a3\\structures_f_exp\\data\\glass\\glass.rvmat'),
    'glass_panel_proc':      (b'#(argb,8,8,3)color(0.10,0.12,0.14,0.75,ca)',
                              b'a3\\structures_f_exp\\data\\glass\\glass.rvmat'),
    'woodfine_01_co':        (b'a3\\structures_f_enoch\\data\\wood\\woodfine_01_co.paa',
                              b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'native_house_stone_floor_co': (b'a3\\structures_f_exp\\data\\stone\\native_house_stone_floor_co.paa',
                              b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
}
LOOKUP = dict(TEX)
LOOKUP.update(EXTRA_TEX)

# collision, per the fixtures' own handoffs -----------------------------------
GEO_SUFFIX = {
    'kitchen': ('_plinth', '_carcass_l1', '_carcass_l2', '_carcass_l3', '_carcass_l4',
                '_carcass_l5', '_carcass_r', '_oven_bay', '_top_l', '_top_r', '_top_f', '_top_b'),
    'shower':  ('_tray', '_tray_lip', '_wall_back', '_wall_left', '_ceiling', '_bench', '_bench_top'),
}
# toilet: hand-drawn boxes from ARMA3_HANDOFF_TOILET.md, in fixture-local metres
# (x across, y up, z depth) BEFORE recentring -- the shells are concave swept
# squircles and must never be hulled.
TOILET_BOXES = [
    ((-0.28, 0.00, -0.34), (0.28, 1.05, -0.24)),   # panel  0.56 x 1.05 x 0.10 at z -0.29
    ((-0.185, 0.075, -0.255), (0.185, 0.40, 0.355)),  # pan block, encloses dome + rim
    ((-0.185, 0.40, -0.255), (0.185, 0.44, 0.355)),   # seat slab 0.37 x 0.04 x 0.61 at y 0.42
    ((0.13, 0.36, -0.24), (0.275, 0.41, 0.06)),       # control arm
]


def collect(prefix):
    sel = [m for m in meshes if m['name'].startswith(prefix)]
    if not sel:
        sys.exit(f'no meshes for {prefix}')
    xs = []; ys = []; zs = []
    for m in sel:
        p = m['pos']; xs += p[0::3]; ys += p[1::3]; zs += p[2::3]
    ctr = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2)
    return sel, ctr, (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def build(kind):
    prefix, out_name = FIX[kind]
    sel, ctr, lo, hi = collect(prefix)

    vis = Lod(1.0)
    nf = 0
    for m in sel:
        key = m['mat']
        if key not in LOOKUP:
            sys.exit(f'{kind}: no material mapping for {key}')
        tex, mat = LOOKUP[key]
        pos, nrm, uv = m['pos'], m['norm'], m['uv']
        for t in range(len(pos) // 9):
            corners = []
            for c in range(3):
                i = t * 3 + c
                corners.append(((pos[3*i] - ctr[0], pos[3*i+1] - ctr[1], pos[3*i+2] - ctr[2]),
                                (nrm[3*i], nrm[3*i+1], nrm[3*i+2]),
                                (uv[2*i], 1.0 - uv[2*i+1])))     # same V-flip as everything else
            vis.face(corners, tex=tex, mat=mat)
            nf += 1

    # ---- geometry -----------------------------------------------------------
    geo = Lod(1e13)
    comps = []
    def new_comp():
        geo.comp_key = len(comps) + 1
        s = (set(), set()); comps.append(s); return s

    if kind == 'toilet':
        base = ((lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2)   # boxes are about the pan centre, floor-relative
        for (a, b) in TOILET_BOXES:
            add_box(geo,
                    (base[0] + a[0] - ctr[0] + (ctr[0] - base[0]) * 0, base[1] + a[1] - ctr[1], base[2] + a[2] - ctr[2]),
                    (base[0] + b[0] - ctr[0], base[1] + b[1] - ctr[1], base[2] + b[2] - ctr[2]),
                    sel=new_comp())
    else:
        for m in sel:
            if not m['name'].endswith(GEO_SUFFIX[kind]):
                continue
            p = m['pos']; xs = p[0::3]; ys = p[1::3]; zs = p[2::3]
            add_box(geo, (min(xs) - ctr[0], min(ys) - ctr[1], min(zs) - ctr[2]),
                         (max(xs) - ctr[0], max(ys) - ctr[1], max(zs) - ctr[2]), sel=new_comp())
    if not comps:
        sys.exit(f'{kind}: no collision components matched')
    geo.selections = [(f'Component{i:02d}', ps, fs) for i, (ps, fs) in enumerate(comps, 1)]

    geo_f = geo.finish(mass_total=200.0)
    fire_f = copy.deepcopy(geo_f); fire_f['res'] = 7e15
    fire_f['taggs'] = [t for t in fire_f['taggs'] if t['name'] != b'#Mass#']
    view_f = copy.deepcopy(geo_f); view_f['res'] = 6e15
    view_f['taggs'] = [t for t in view_f['taggs'] if t['name'] != b'#Mass#']

    lods = [vis.finish()]
    if kind == 'toilet':
        # coarse resolution LOD, straight from the handoff: "for a real LOD 3.0
        # replace the shells with the four collision boxes". 15.6k triangles is
        # fine once, but this fixture exists 29 times in one building.
        coarse = Lod(50.0)
        tex, mat = LOOKUP['porcelain_white_proc']
        base = ((lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2)
        for (a, b) in TOILET_BOXES:
            mn = (base[0] + a[0] - ctr[0], base[1] + a[1] - ctr[1], base[2] + a[2] - ctr[2])
            mx = (base[0] + b[0] - ctr[0], base[1] + b[1] - ctr[1], base[2] + b[2] - ctr[2])
            P = {(i, j, k): (mx[0] if i else mn[0], mx[1] if j else mn[1], mx[2] if k else mn[2])
                 for i in (0, 1) for j in (0, 1) for k in (0, 1)}
            quads = [([(0,0,0),(0,0,1),(0,1,1),(0,1,0)], (-1,0,0)), ([(1,0,0),(1,1,0),(1,1,1),(1,0,1)], (1,0,0)),
                     ([(0,0,0),(1,0,0),(1,0,1),(0,0,1)], (0,-1,0)), ([(0,1,0),(0,1,1),(1,1,1),(1,1,0)], (0,1,0)),
                     ([(0,0,0),(0,1,0),(1,1,0),(1,0,0)], (0,0,-1)), ([(0,0,1),(1,0,1),(1,1,1),(0,1,1)], (0,0,1))]
            for keys, nrm in quads:
                coarse.face([(P[k], nrm, (0.5, 0.5)) for k in keys], tex=tex, mat=mat)
        lods.append(coarse.finish())
    lods += [geo_f, view_f, fire_f]

    out = f'{HERE}/{out_name}.p3d'
    n = mlod_rw.write(out, 257, lods)
    v2, l2 = mlod_rw.parse(out); mlod_rw.write(out + '.rt', v2, l2)
    assert filecmp.cmp(out, out + '.rt', shallow=False); os.remove(out + '.rt')
    size = (hi[0]-lo[0], hi[1]-lo[1], hi[2]-lo[2])
    # offset of the fixture centre from the FLOOR datum, in tower model space --
    # the spawner needs this to place it, and it is identical on every floor
    print(f'{out_name}.p3d: {nf} faces, {len(comps)} collision comps, '
          f'{size[0]:.2f}x{size[1]:.2f}x{size[2]:.2f} m, bytes={n}')
    return (kind, ctr, lo[1])


if __name__ == '__main__':
    info = [build(k) for k in ('kitchen', 'shower', 'toilet')]
    # emit the placement data: centre offset relative to the floor's finished
    # level, in the tower's SCRIPT model frame [x, depth(z), up(y)]
    ZC, YC = 1.845, 58.460
    rows = []
    for kind, ctr, floor_y in info:
        rows.append(f'    ["{kind}", [{ctr[0]:.4f}, {ctr[2]-ZC:.4f}, {ctr[1]-YC:.4f}]]')
    out = os.path.join(HERE, '..', '..', 'mission', 'Armapunk2035.Malden',
                       'custom_p3ds', 'lux_fixtures_data.sqf')
    with open(out, 'w') as f:
        f.write('// GENERATED by scratchpad/skyscraper/build_fixtures.py -- do not hand-edit.\n')
        f.write('// [kind, centreOffsetModel] for FLOOR 2; every floor above is the same\n')
        f.write('// offset plus (floor-2)*3.6 in the up axis.\n')
        f.write('[\n' + ',\n'.join(rows) + '\n]\n')
    print(f'wrote {os.path.normpath(out)}')
