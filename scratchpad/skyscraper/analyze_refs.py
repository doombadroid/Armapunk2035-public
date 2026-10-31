#!/usr/bin/env python3
"""Survey the two reference MLOD p3ds: LOD set, header fields, taggs, textures,
mass, face shapes, winding-vs-normal orientation. Defines the target format."""
import sys, struct, collections, math
sys.path.insert(0, '/home/timb/blender_work')
from mlod_rw import parse

BASE = '/tmp/claude-1000/-home-timb/01f83e5a-e5d3-4e94-8e46-ae8e3105b454/scratchpad/skyscraper/uploads'

def resname(r):
    names = {1.0:'visual', 2.0:'visual2', 1e13:'GEOMETRY', 3e15:'ROADWAY',
             1e15:'memory', 2e15:'landcontact', 4e15:'paths', 5e15:'hitpoints',
             6e15:'viewgeo', 7e15:'firegeo', 10000.0:'shadowV0', 10010.0:'shadowV10',
             11000.0:'shadowB0', 11002.0:'shadowB2', 11010.0:'shadowB10'}
    for k,v in names.items():
        if abs(r-k) <= abs(k)*1e-9: return v
    return f'res={r:g}'

def survey(path):
    ver, lods = parse(path)
    print(f'\n=== {path.split("/")[-1]}  ver={ver}  nlod={len(lods)}')
    for i, L in enumerate(lods):
        taggnames = [t['name'].decode('latin1') for t in L['taggs']]
        sel = [n for n in taggnames if not n.startswith('#')]
        print(f'LOD{i} {resname(L["res"]):>9} hs={L["hs"]:#x} lv={L["lv"]:#x} flags={L["flags"]:#x} '
              f'pts={len(L["pts"])} norms={len(L["norms"])} faces={len(L["faces"])}')
        nvc = collections.Counter(f['nv'] for f in L['faces'])
        fflags = collections.Counter(f['flags'] for f in L['faces'])
        print(f'   nv counts: {dict(nvc)}  face-flags: {dict(fflags)}')
        ptflags = collections.Counter(p[3] for p in L['pts'])
        print(f'   point-flags: {dict(ptflags)}')
        texs = collections.Counter((f['tex'], f['mat']) for f in L['faces'])
        for (t,m),c in texs.most_common(6):
            print(f'   {c:5d}x tex={t[:70]!r} mat={m[:60]!r}')
        if len(texs) > 6: print(f'   ... {len(texs)-6} more tex/mat combos')
        hashsel = [n for n in taggnames if n.startswith('#')]
        print(f'   taggs: {hashsel}  selections: {len(sel)} '
              f'{sel[:4]}{"..." if len(sel)>4 else ""}')
        for t in L['taggs']:
            if t['name'] == b'#Mass#':
                masses = struct.unpack(f'<{len(t["data"])//4}f', t['data'])
                print(f'   #Mass# n={len(masses)} sum={sum(masses):.1f} '
                      f'min={min(masses):.4f} max={max(masses):.4f}')
            if t['name'] == b'#SharpEdges#':
                print(f'   #SharpEdges# pairs={len(t["data"])//8}')
            if t['name'] == b'#Property#':
                print(f'   #Property# {t["data"]!r}')
            if t['name'] == b'#UVSet#':
                print(f'   #UVSet# len={len(t["data"])}')
        # winding check on a sample face: RH normal from vertex order vs stored normal
        for f in L['faces'][:400]:
            if f['nv'] < 3: continue
            idx = [v[0] for v in f['vs'][:f['nv']]]
            ni  = [v[1] for v in f['vs'][:f['nv']]]
            p = [L['pts'][j][:3] for j in idx]
            ax,ay,az = (p[1][0]-p[0][0], p[1][1]-p[0][1], p[1][2]-p[0][2])
            bx,by,bz = (p[2][0]-p[0][0], p[2][1]-p[0][1], p[2][2]-p[0][2])
            cx,cy,cz = (ay*bz-az*by, az*bx-ax*bz, ax*by-ay*bx)
            n = math.sqrt(cx*cx+cy*cy+cz*cz)
            if n < 1e-9: continue
            sn = L['norms'][ni[0]]
            dot = (cx*sn[0]+cy*sn[1]+cz*sn[2])/n/max(1e-9, math.sqrt(sum(q*q for q in sn)))
            print(f'   winding sample: RHnormal·storedNormal = {dot:+.3f} '
                  f'(+1 = stored normal along RH winding normal)')
            break

for f in ('MaldenGrandPalaceBuilding_r4.p3d', 'JewelryBuildingModel.p3d'):
    survey(f'{BASE}/{f}')
