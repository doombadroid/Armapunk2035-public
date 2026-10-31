#!/usr/bin/env python3
"""Verification suite for ap_printer_i3_*.p3d / ap_printer_corexy_*.p3d. Must print ALL PASS.

Gates the things that fail SILENTLY in Arma or in the design source's own viewer:

  * winding, over every face -- a mirrored primitive renders as nothing in a single-sided viewer,
    so the prototype cannot show the defect and neither can the engine. It has to be measured.
    (This is the check that caught 6120 inverted faces on the skyscraper.)
  * no collision LODs -- the owner's call is that these props have none. A Geometry LOD creeping
    back in would be invisible until a player got stuck on his own printer, so absence is asserted.
  * rvmat paths that exist on disk -- Arma resolves a missing rvmat to a default and says nothing.
  * centring -- simple objects are autocentred by the engine, so a model whose own centre is not
    the origin lands offset from wherever the spawner asked for it.
"""
import filecmp
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, '/home/timb/blender_work')
import mlod_rw                                                    # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MISSION = os.path.abspath(os.path.join(HERE, '..', '..', 'mission', 'Armapunk2035.Malden'))
REV = 'r1'

fails = 0


def gate(name, ok, extra=''):
    global fails
    print(f'  [{"PASS" if ok else "FAIL"}] {name}' + (f'   {extra}' if extra else ''))
    if not ok:
        fails += 1


def winding_normal(l, f):
    ps = [l['pts'][v[0]][:3] for v in f['vs'][:f['nv']]]
    ax = [ps[1][i] - ps[0][i] for i in range(3)]
    bx = [ps[2][i] - ps[0][i] for i in range(3)]
    cr = [ax[1] * bx[2] - ax[2] * bx[1], ax[2] * bx[0] - ax[0] * bx[2], ax[0] * bx[1] - ax[1] * bx[0]]
    ln = math.sqrt(sum(c * c for c in cr))
    return ([c / ln for c in cr], ln)


def check(key, path):
    print(f'\n== {os.path.basename(path)}')
    dump = json.load(open(f'{HERE}/printer_dump.json'))[key]
    meshes, mats = dump['meshes'], dump['mats']
    ver, lods = mlod_rw.parse(path)

    res = [l['res'] for l in lods]
    gate('two visual LODs at 1.0 / 50.0', res == [1.0, 50.0], f'{res}')

    # Collision LODs live at these magic resolutions; the owner's call is that there are none.
    COLLISION_RES = {1e13: 'Geometry', 6e15: 'View Geometry', 7e15: 'Fire Geometry',
                     3e15: 'Roadway', 11002.0: 'Shadow'}
    stray = [n for r, n in COLLISION_RES.items() if r in res]
    gate('no collision/shadow LODs (owner: prop has none)', not stray, ','.join(stray))
    gate('no #Mass# tagg', not any(t['name'] == b'#Mass#' for l in lods for t in l['taggs']))

    vis, coarse = lods[0], lods[1]

    tris = sum(len(m['pos']) // 9 for m in meshes)
    gate('visual face count == source triangles', len(vis['faces']) == tris,
         f'{len(vis["faces"])} vs {tris}')

    # --- winding, EVERY face (not a sample: an inverted primitive can be a handful of faces)
    bad = 0
    degen = 0
    for f in vis['faces']:
        wn, ln = winding_normal(vis, f)
        if ln < 1e-12:
            degen += 1
            continue
        sn = vis['norms'][f['vs'][0][1]]
        if sum(sn[i] * wn[i] for i in range(3)) < 0.90:
            bad += 1
    gate('winding == stored normal, all faces', bad == 0, f'{bad} inverted of {len(vis["faces"])}')
    gate('no degenerate faces', degen == 0, f'{degen}')

    # --- centred on its own bbox (engine autocentres simple objects)
    xs = [p[0] for p in vis['pts']]; ys = [p[1] for p in vis['pts']]; zs = [p[2] for p in vis['pts']]
    ctr = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2)
    gate('visual centred on origin', max(abs(c) for c in ctr) < 1e-6,
         f'centre=({ctr[0]:.2e},{ctr[1]:.2e},{ctr[2]:.2e})')

    size = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    gate('desk-prop scale (all axes < 0.8 m)', all(s < 0.8 for s in size),
         f'{size[0]:.3f} x {size[1]:.3f} x {size[2]:.3f}')

    # --- textures
    notex = sum(1 for f in vis['faces'] if not f['tex'])
    gate('every visual face has a texture', notex == 0, f'{notex} bare')

    used = {f['tex'] for f in vis['faces']}
    gate('every source material reaches the model', len(used) == len(mats),
         f'{len(used)} textures for {len(mats)} materials')

    # --- rvmats that are mission-local must exist, or Arma silently substitutes a default
    rvs = {f['mat'] for f in vis['faces'] if f['mat']}
    missing = []
    for r in rvs:
        s = r.decode()
        if s.startswith('mpmissions\\__cur_mp.Malden\\'):
            if not os.path.exists(os.path.join(MISSION, s.split('\\')[-1])):
                missing.append(s)
    gate('mission-local rvmats exist on disk', not missing, ','.join(missing))

    # --- emissive + glass routing (a screen that lost its rvmat just looks painted on)
    emissive_tex = {f'#(argb,8,8,3)color({int(mats[n]["emissive"][1:3],16)/255:.3f},'
                    f'{int(mats[n]["emissive"][3:5],16)/255:.3f},'
                    f'{int(mats[n]["emissive"][5:7],16)/255:.3f},'
                    f'{mats[n]["opacity"]:.2f},co)'.encode()
                    for n in ('lcd', 'screen', 'led') if n in mats}
    em_ok = all(any(f['tex'] == t and f['mat'].endswith(b'ap_printer_screen.rvmat')
                    for f in vis['faces']) for t in emissive_tex)
    gate('emissive faces carry the screen rvmat', em_ok, f'{len(emissive_tex)} emissive materials')

    # --- coarse LOD
    nboxes = len(coarse['faces']) / 6
    gate('coarse LOD is whole boxes (6 quads each)', nboxes == int(nboxes), f'{len(coarse["faces"])} faces')
    gate('coarse LOD is far cheaper than visual', len(coarse['faces']) * 20 < len(vis['faces']),
         f'{len(coarse["faces"])} vs {len(vis["faces"])}')
    cxs = [p[0] for p in coarse['pts']]; cys = [p[1] for p in coarse['pts']]; czs = [p[2] for p in coarse['pts']]
    inside = (min(cxs) >= min(xs) - 1e-6 and max(cxs) <= max(xs) + 1e-6 and
              min(cys) >= min(ys) - 1e-6 and max(cys) <= max(ys) + 1e-6 and
              min(czs) >= min(zs) - 1e-6 and max(czs) <= max(zs) + 1e-6)
    gate('coarse LOD within the visual bbox', inside)

    return size


def main():
    models = [('i3', f'{HERE}/ap_printer_i3_{REV}.p3d'),
              ('corexy', f'{HERE}/ap_printer_corexy_{REV}.p3d')]
    for key, path in models:
        if not os.path.exists(path):
            print(f'  [FAIL] missing {path}')
            return 1
        check(key, path)

    # --- determinism: rebuild into a temp dir and compare bytes
    print('\n== determinism')
    with tempfile.TemporaryDirectory() as td:
        keep = {p: open(p, 'rb').read() for _, p in models}
        subprocess.run([sys.executable, f'{HERE}/build_printer.py'], check=True,
                       cwd=HERE, stdout=subprocess.DEVNULL)
        same = all(open(p, 'rb').read() == keep[p] for _, p in models)
        gate('rebuild is byte-identical', same)
        del td

    print()
    if fails:
        print(f'{fails} FAILURE(S)')
        return 1
    print('ALL PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
