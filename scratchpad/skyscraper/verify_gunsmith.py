#!/usr/bin/env python3
"""Verification suite for ap_gunsmith_bench_*.p3d. Must print ALL PASS.

The printer's suite asserts the ABSENCE of collision; this one asserts its presence and shape,
because the bench is the opposite case -- a 2 m object you stand at, where walking through it is
the bug. Everything else is the same discipline: measure the geometry, never read the description.
"""
import filecmp
import json
import math
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, '/home/timb/blender_work')
import mlod_rw                                                     # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REV = 'r2'
P3D = os.path.join(HERE, f'ap_gunsmith_bench_{REV}.p3d')
fails = 0


def gate(name, ok, extra=''):
    global fails
    print(f'  [{"PASS" if ok else "FAIL"}] {name}' + (f'   {extra}' if extra else ''))
    if not ok:
        fails += 1


def winding_normal(l, f):
    ps = [l['pts'][v[0]][:3] for v in f['vs'][:f['nv']]]
    a = [ps[1][i] - ps[0][i] for i in range(3)]
    b = [ps[2][i] - ps[0][i] for i in range(3)]
    c = [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
    n = math.sqrt(sum(x * x for x in c))
    return ([x / n for x in c], n) if n > 1e-12 else ([0, 0, 0], 0.0)


def main():
    if not os.path.exists(P3D):
        print(f'  [FAIL] missing {P3D}')
        return 1
    dump = json.load(open(f'{HERE}/gunsmith_dump.json'))['gunsmith']
    meshes = dump['meshes']
    ver, lods = mlod_rw.parse(P3D)
    res = [l['res'] for l in lods]

    print(f'\n== {os.path.basename(P3D)}')
    # Resolutions are stored as float32, so 1e13 comes back as 9999999827968.0 -- compare
    # relatively, never for equality, or the gate fails on the storage format rather than the model.
    want = [1.0, 2.0, 3.0, 1e13, 6e15, 7e15]
    gate('LOD ladder 1.0 / 2.0 / 3.0 / Geometry / View / Fire',
         len(res) == len(want) and all(abs(a - b) <= 1e-6 * max(1.0, abs(b)) for a, b in zip(res, want)),
         f'{[round(r) for r in res]}')

    vis, l2, l3, geo, view, fire = lods

    tris = sum(len(m['pos']) // 9 for m in meshes)
    gate('visual face count == source triangles', len(vis['faces']) == tris,
         f'{len(vis["faces"])} vs {tris}')

    # The ladder must actually get cheaper, or the LODs cost memory and buy nothing.
    gate('LOD ladder is monotonically cheaper',
         len(vis['faces']) > len(l2['faces']) > len(l3['faces']),
         f'{len(vis["faces"])} > {len(l2["faces"])} > {len(l3["faces"])}')
    gate('LOD 3 is a true silhouette (< 8% of full)',
         len(l3['faces']) < 0.08 * len(vis['faces']),
         f'{len(l3["faces"])} / {len(vis["faces"])}')

    # --- winding, every face of every visual LOD. A mirrored primitive renders as NOTHING in a
    # single-sided viewer, so neither the prototype nor the engine can show the defect.
    for nm, l in (('1.0', vis), ('2.0', l2), ('3.0', l3)):
        bad = 0
        worst = 1.0
        for f in l['faces']:
            wn, ln = winding_normal(l, f)
            if ln == 0.0:
                bad += 1
                continue
            sn = l['norms'][f['vs'][0][1]]
            d = sum(sn[i] * wn[i] for i in range(3))
            worst = min(worst, d)
            # INVERSION, not deviation. A mirrored face has dot ~= -1; a smooth-shaded curved
            # surface legitimately deviates, because the stored normal is the interpolated VERTEX
            # normal and the winding normal is the flat FACE normal. On this model's springs and
            # torus pieces that reaches ~35 degrees, which a 0.90 threshold reads as 2027 defects
            # and which is simply what a tight tube looks like.
            if d <= 0.0:
                bad += 1
        gate(f'no inverted faces, LOD {nm}', bad == 0,
             f'{bad} inverted of {len(l["faces"])}, worst dot {worst:+.2f}')

    # --- collision: five convex boxes, and this time their PRESENCE is the requirement
    sels = [t for t in geo['taggs'] if t['name'].startswith(b'Component')]
    gate('geometry has 5 named components', len(sels) == 5, f'{len(sels)}')
    npts = len(geo['pts'])
    boxes_ok = True
    for t in sels:
        d = t['data']
        p = sum(d[i] for i in range(npts))
        fc = sum(d[npts + i] for i in range(len(geo['faces'])))
        if p != 8 or fc != 6:                      # 8 corners, 6 quad faces = a convex box
            boxes_ok = False
            print(f'      {t["name"].decode()}: pts={p} faces={fc}')
    gate('every component is a convex box (8 pts / 6 quads)', boxes_ok)

    gm = [t for t in geo['taggs'] if t['name'] == b'#Mass#']
    gate('geometry carries mass', len(gm) == 1)
    gate('view + fire are mass-free copies of geometry',
         not any(t['name'] == b'#Mass#' for t in view['taggs'] + fire['taggs'])
         and len(view['faces']) == len(geo['faces']) == len(fire['faces']))

    # Collision must not stick out of the thing it represents, or players bounce off thin air.
    gx = [p[0] for p in geo['pts']]; gy = [p[1] for p in geo['pts']]; gz = [p[2] for p in geo['pts']]
    vx = [p[0] for p in vis['pts']]; vy = [p[1] for p in vis['pts']]; vz = [p[2] for p in vis['pts']]
    gate('collision is inside the visible model',
         min(gx) >= min(vx) - 1e-3 and max(gx) <= max(vx) + 1e-3 and
         min(gy) >= min(vy) - 1e-3 and max(gy) <= max(vy) + 1e-3 and
         min(gz) >= min(vz) - 1e-3 and max(gz) <= max(vz) + 1e-3,
         f'geo x[{min(gx):.2f},{max(gx):.2f}] vs vis x[{min(vx):.2f},{max(vx):.2f}]')

    # --- centring and scale
    ctr = ((min(vx) + max(vx)) / 2, (min(vy) + max(vy)) / 2, (min(vz) + max(vz)) / 2)
    gate('visual centred on origin', max(abs(c) for c in ctr) < 1e-6)
    gate('bench-scale (2.0 x 1.9 x 1.0 m, within tolerance)',
         abs((max(vx) - min(vx)) - 2.045) < 0.05 and abs((max(vy) - min(vy)) - 1.893) < 0.05)

    # --- textures
    notex = sum(1 for f in vis['faces'] if not f['tex'])
    gate('every visual face has a texture', notex == 0, f'{notex} bare')
    a3 = {f['tex'] for f in vis['faces'] if f['tex'].startswith(b'a3\\')}
    proc = {f['tex'] for f in vis['faces'] if f['tex'].startswith(b'#(')}
    # r2 pins the CLEAN sheet set: the r1 map pointed at rust-streaked base-game metal (owner
    # 2026-09-03), so the gate names every a3 texture allowed and fails on any other one.
    CLEAN = {b'a3\\structures_f_enoch\\data\\wood\\woodfine_01_co.paa',
             b'a3\\structures_f_enoch\\data\\wood\\planksold_02_co.paa',
             b'a3\\structures_f_enoch\\data\\wood\\wood_plank_old_co.paa',
             b'a3\\structures_f_exp\\data\\metal\\metal_plate_04_co.paa',
             b'a3\\structures_f\\data\\metal\\metal_gray_clean_co.paa'}
    gate('big surfaces use the r2 clean a3 sheets only, accents stay procedural',
         a3 == CLEAN and len(proc) >= 5,
         f'{len(a3)} a3 ({", ".join(sorted(t.decode().rsplit(chr(92), 1)[-1] for t in a3 - CLEAN)) or "all clean"}), {len(proc)} procedural')
    gate('no mission-local texture or rvmat (nothing to ship, nothing to lose)',
         not any(b'mpmissions' in f['tex'] or b'mpmissions' in f['mat'] for f in vis['faces']))

    print('\n== determinism')
    keep = open(P3D, 'rb').read()
    subprocess.run([sys.executable, f'{HERE}/build_gunsmith.py'], check=True, cwd=HERE,
                   stdout=subprocess.DEVNULL)
    gate('rebuild is byte-identical', open(P3D, 'rb').read() == keep)

    print()
    if fails:
        print(f'{fails} FAILURE(S)')
        return 1
    print('ALL PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
