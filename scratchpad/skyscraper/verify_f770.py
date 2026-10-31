#!/usr/bin/env python3
"""Verification suite for the six ap_printer_f770_*_r1.p3d MLODs + fab_parts_data.sqf. Must print ALL PASS.

Every number here is recomputed from f770_dump.json; nothing is compared against the handoff prose.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, '/home/timb/blender_work')
import mlod_rw                                                    # noqa: E402
sys.path.insert(0, HERE)
import build_f770 as B                                            # noqa: E402

MISSION = B.MISSION
INDEX = os.path.abspath(os.path.join(HERE, '..', '..', 'textures_png', 'INDEX.txt'))
fails = 0


def gate(name, ok, extra=''):
    global fails
    print(f'  [{"PASS" if ok else "FAIL"}] {name}' + (f'   {extra}' if extra else ''))
    if not ok:
        fails += 1


def bbox(lod):
    xs = [p[0] for p in lod['pts']]; ys = [p[1] for p in lod['pts']]; zs = [p[2] for p in lod['pts']]
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def check_part(part, meshes, mats, index_paths, geometry):
    path = os.path.join(HERE, f'{B.BASE}_{part}_{B.REV}.p3d')
    print(f'\n== {os.path.basename(path)}')
    if not os.path.exists(path):
        gate('file exists', False, path); return None
    ver, lods = mlod_rw.parse(path)
    res = [B.f32(l['res']) for l in lods]          # stored as float32: 1e13 reads back 9999999827968.0
    want = [B.f32(x) for x in [1.0, 50.0] + ([1e13, 6e15, 7e15] if geometry else [])]
    gate('LOD resolutions', res == want, f'{res}')
    vis, coarse = lods[0], lods[1]
    tris = sum(len(m['pos']) // 9 for m in meshes)
    gate('visual faces == dumped tris', len(vis['faces']) == tris, f'{len(vis["faces"])} vs {tris}')
    lo, hi = bbox(vis)
    ctr = [(lo[i] + hi[i]) / 2 for i in range(3)]
    gate('visual LOD centred on its bbox', all(abs(c) < 1e-4 for c in ctr), f'{[round(c, 5) for c in ctr]}')
    used = {f['tex'] for f in vis['faces']}
    need = {B.tex_for(n, mats[n])[0] for n in {m['mat'] for m in meshes}}
    gate('every material of the group reaches the model', need <= used, f'{len(need)} needed, {len(used)} used')
    a3 = sorted({t.decode() for t in used if t.startswith(b'a3\\')})
    missing = [t for t in a3 if t.lower() not in index_paths]
    gate('vanilla textures exist in textures_png/INDEX.txt', not missing, ','.join(missing) or f'{len(a3)} paths')
    local = sorted({t.decode() for t in used if t.startswith(b'mpmissions\\')}
                   | {f['mat'].decode() for f in vis['faces'] if f['mat'].startswith(b'mpmissions\\')})
    miss2 = [t for t in local if not os.path.exists(os.path.join(MISSION, t.split('\\')[-1]))]
    gate('mission-local textures/rvmats exist on disk', not miss2, ','.join(miss2) or f'{len(local)} files')
    # every a3 rvmat must be one the game ships: the handoff's metal_plate.rvmat did not exist and the faces
    # wearing it rendered with a missing material (2026-09-03). textures_png/RVMATS.txt = tools/texture_audit.py's index.
    rvidx = os.path.abspath(os.path.join(HERE, '..', '..', 'textures_png', 'RVMATS.txt'))
    known = set(l.strip().lower() for l in open(rvidx, encoding='utf-8')) if os.path.exists(rvidx) else set()
    a3rv = sorted({f['mat'].decode().lower() for f in vis['faces'] if f['mat'].startswith(b'a3\\')})
    miss3 = [r for r in a3rv if r not in known]
    gate('a3 rvmats exist in the game (textures_png/RVMATS.txt)', bool(known) and not miss3, ','.join(miss3) or f'{len(a3rv)} rvmats')
    clo, chi = bbox(coarse)
    inside = all(clo[i] >= lo[i] - 1e-5 and chi[i] <= hi[i] + 1e-5 for i in range(3))
    gate('coarse LOD is one box inside the visual bbox', len(coarse['faces']) == 6 and inside)
    if geometry:
        geo = lods[2]
        glo, ghi = bbox(geo)
        gate('geometry is one box == visual bbox',
             len(geo['faces']) == 6 and all(abs(glo[i] - lo[i]) < 1e-5 and abs(ghi[i] - hi[i]) < 1e-5 for i in range(3)))
        mass = [t for t in geo['taggs'] if t['name'] == b'#Mass#']
        tot = sum(__import__('struct').unpack(f'<{len(mass[0]["data"]) // 4}f', mass[0]['data'])) if mass else 0
        gate('#Mass# present and totals 900', mass and abs(tot - B.MASS) < 0.5, f'{tot:.1f}')
        gate('Component01 selection present', any(t['name'] == b'Component01' for t in geo['taggs']))
        for k, name in ((3, 'View'), (4, 'Fire')):
            gate(f'{name} geometry carries no #Mass#', not any(t['name'] == b'#Mass#' for t in lods[k]['taggs']))
    return ctr, (hi[1] - lo[1]) / 2, (lo, hi)


def main():
    data = json.load(open(os.path.join(HERE, 'f770_dump.json')))
    meshes, mats = data['meshes'], data['mats']
    groups = {}
    for m in meshes:
        groups.setdefault(m['group'], []).append(m)
    index_paths = set()
    with open(INDEX, encoding='utf-8', errors='replace') as f:
        for line in f:
            index_paths.add(line.split(' -> ')[0].strip().lower())

    body = check_part('body', groups['body'], mats, index_paths, True)
    if body is None:
        print('\n1 FAILURE(S)'); return 1
    blo, bhi = B.bounds(groups['body'])
    body_ctr = [(blo[i] + bhi[i]) / 2 for i in range(3)]
    parts_ok = True
    offsets = {}
    for suffix, g in B.PARTS:
        r = check_part(suffix, groups[g], mats, index_paths, False)
        parts_ok = parts_ok and r is not None
        lo, hi = B.bounds(groups[g])
        c = [(lo[i] + hi[i]) / 2 for i in range(3)]
        offsets[suffix] = [c[0] - body_ctr[0], (-(c[2] - body_ctr[2]) if B.MIRROR_Z else (c[2] - body_ctr[2])), c[1] - body_ctr[1]]

    print('\n== fab_parts_data.sqf')
    path = os.path.join(MISSION, 'custom_p3ds', 'fab_parts_data.sqf')
    txt = open(path, encoding='utf-8').read()
    m = re.search(r'\["(ap_printer_f770)", "(r\d+)", ([\d.]+), \[(.*)\], \[([^\]]*)\]\]', txt)
    gate('row parses', m is not None)
    if m:
        gate('basename/rev', m.group(1) == B.BASE and m.group(2) == B.REV)
        gate('lift == body half-height', abs(float(m.group(3)) - (bhi[1] - blo[1]) / 2) < 1e-4, m.group(3))
        rows = re.findall(r'\["(\w+)", \[([-\d.]+), ([-\d.]+), ([-\d.]+)\]\]', m.group(4))
        gate('five parts in order', [r[0] for r in rows] == [s for s, _ in B.PARTS], str([r[0] for r in rows]))
        bad = [r[0] for r in rows if r[0] in offsets and
               any(abs(float(r[1 + i]) - offsets[r[0]][i]) > 2e-4 for i in range(3))]
        gate('offsets == part centre - body centre (dump)', not bad, ','.join(bad))
        anim = [float(x) for x in m.group(5).split(',')]
        gate('anim constants == f770.js', anim == [float(x) for x in B.anim_constants()], str(anim))

    print('\n== determinism')
    files = [os.path.join(HERE, f'{B.BASE}_{p}_{B.REV}.p3d') for p in ['body'] + [s for s, _ in B.PARTS]] + [path]
    keep = {p: open(p, 'rb').read() for p in files}
    subprocess.run([sys.executable, os.path.join(HERE, 'build_f770.py')], check=True, cwd=HERE, stdout=subprocess.DEVNULL)
    gate('rebuild is byte-identical (p3ds + data file)', all(open(p, 'rb').read() == keep[p] for p in files))

    print()
    if fails or not parts_ok:
        print(f'{fails} FAILURE(S)'); return 1
    print('ALL PASS'); return 0


if __name__ == '__main__':
    sys.exit(main())
