#!/usr/bin/env python3
"""Structural verification of Skyscraper20_r1.p3d against the measured
reference conventions. Every check prints PASS/FAIL; exit 1 on any FAIL."""
import sys, struct, math, os, collections
sys.path.insert(0, '/home/timb/blender_work')
from mlod_rw import parse

HERE = os.path.dirname(os.path.abspath(__file__))
P3D = sys.argv[1] if len(sys.argv) > 1 else f'{HERE}/Skyscraper20_r14.p3d'
fails = []

def check(name, ok, detail=''):
    print(f'{"PASS" if ok else "FAIL"} {name} {detail}')
    if not ok: fails.append(name)

ver, lods = parse(P3D)
check('ver/nlod', ver == 257 and len(lods) == 5, f'ver={ver} nlod={len(lods)}')
def q32(x): return struct.unpack('<f', struct.pack('<f', x))[0]
check('lod resolutions', [L['res'] for L in lods] == [q32(v) for v in (1.0, 11002.0, 1e13, 3e15, 7e15)],
      str([L['res'] for L in lods]))
check('headers', all(L['hs'] == 0x1c and L['lv'] == 0x100 and L['flags'] == 0 for L in lods))
check('point flags 0', all(p[3] == 0 for L in lods for p in L['pts']))
check('face flags 0', all(f['flags'] == 0 for L in lods for f in L['faces']))

def rh_normal(L, f):
    idx = [v[0] for v in f['vs'][:f['nv']]]
    p = [L['pts'][j][:3] for j in idx]
    ax, ay, az = (p[1][0]-p[0][0], p[1][1]-p[0][1], p[1][2]-p[0][2])
    bx, by, bz = (p[2][0]-p[0][0], p[2][1]-p[0][1], p[2][2]-p[0][2])
    return (ay*bz-az*by, az*bx-ax*bz, ax*by-ay*bx)

# stored normals aligned with RH winding normal on every face, every LOD.
# Smooth-shaded curved prims (16-seg cylinders, spheres) legitimately deviate
# up to ~15 deg; anything below 0.5 is an inversion (the tower.js negative-BB
# class measured at exactly -1.0).
bad = smooth = 0
for L in lods:
    for f in L['faces']:
        c = rh_normal(L, f)
        n = math.sqrt(sum(q*q for q in c))
        if n < 1e-12: bad += 1; continue
        for v in f['vs'][:f['nv']]:
            s = L['norms'][v[1]]
            sn = math.sqrt(sum(q*q for q in s))
            dot = sum(a*b for a, b in zip(c, s)) / (n * max(sn, 1e-12))
            if dot < 0.5: bad += 1; break
            if dot < 0.95: smooth += 1
check('no inverted stored normals (dot<0.5)', bad == 0, f'bad={bad} smooth-band={smooth}')

# absolute orientation: faces lying on EVERY bbox extreme plane wind INWARD
vis = lods[0]
mins = [min(p[k] for p in vis['pts']) for k in range(3)]
maxs = [max(p[k] for p in vis['pts']) for k in range(3)]
for axis, side, lim in [(0, 1, maxs[0]), (0, -1, mins[0]), (2, 1, maxs[2]),
                        (2, -1, mins[2]), (1, 1, maxs[1])]:
    inw = outw = 0
    for f in vis['faces']:
        idx = [v[0] for v in f['vs'][:f['nv']]]
        p = [vis['pts'][j][:3] for j in idx]
        if any(abs(q[axis] - lim) > 0.05 for q in p): continue
        n = rh_normal(vis, f)[axis]
        if n * side > 1e-9: outw += 1
        elif n * side < -1e-9: inw += 1
    check(f'exterior plane axis{axis}{"+" if side>0 else "-"} winds inward',
          outw == 0 and inw > 0, f'in={inw} out={outw}')

# roadway: all horizontal faces RH-normal DOWN; all faces carry concrete rvmat
road = lods[3]
ups = downs = 0
for f in road['faces']:
    idx = [v[0] for v in f['vs'][:f['nv']]]
    p = [road['pts'][j][:3] for j in idx]
    if max(q[1] for q in p) - min(q[1] for q in p) > 2.0: continue  # skip ramps
    ny = rh_normal(road, f)[1]
    if ny > 0: ups += 1
    else: downs += 1
check('roadway tops wind down', ups == 0 and downs > 0, f'down={downs} up={ups}')
check('roadway material', all(f['mat'] == b'a3\\data_f\\penetration\\concrete.rvmat'
                              for f in road['faces']))

# geometry: components partition points exactly; each comp closed & convex
geo = lods[2]
npt, nf = len(geo['pts']), len(geo['faces'])
sels = [t for t in geo['taggs'] if not t['name'].startswith(b'#')]
marks = [0]*npt; fmarks = [0]*nf
comp_members = []
door_members = []
for t in sels:
    d = t['data']
    assert len(d) == npt + nf
    ps = [i for i in range(npt) if d[i]]
    fs = [i for i in range(nf) if d[npt+i]]
    nm = t['name'].decode()
    if nm.startswith('door_'):
        # v9: door_N is an exact OVERLAY of one numbered component (pink-house
        # convention, measured) — excluded from the partition accounting.
        door_members.append((nm, set(ps), set(fs)))
        continue
    comp_members.append((nm, ps, fs))
    for i in ps: marks[i] += 1
    for i in fs: fmarks[i] += 1
check('geometry points partitioned', all(m == 1 for m in marks),
      f'shared={sum(1 for m in marks if m>1)} orphan={sum(1 for m in marks if m==0)}')
check('geometry faces partitioned', all(m == 1 for m in fmarks))
check('component naming', [c[0] for c in comp_members[:2]] == ['Component01', 'Component02']
      and (len(comp_members) < 100 or comp_members[99][0] == 'Component100'))

closed_bad = convex_bad = 0
for name, ps, fs in comp_members:
    edges = collections.Counter()
    pts_used = set()
    for fi in fs:
        f = geo['faces'][fi]
        idx = [v[0] for v in f['vs'][:f['nv']]]
        pts_used.update(idx)
        for k in range(len(idx)):
            a, b = idx[k], idx[(k+1) % len(idx)]
            edges[(min(a, b), max(a, b))] += 1
    if any(c != 2 for c in edges.values()): closed_bad += 1
    if pts_used != set(ps): closed_bad += 1
    # convexity: every vertex on or behind every face plane (inward normals -> dot >= -eps)
    for fi in fs:
        f = geo['faces'][fi]
        n = rh_normal(geo, f)          # points INTO the solid
        ln = math.sqrt(sum(q*q for q in n))
        if ln < 1e-12: continue
        p0 = geo['pts'][f['vs'][0][0]][:3]
        for pi in ps:
            p = geo['pts'][pi][:3]
            d = sum((p[k]-p0[k]) * n[k] for k in range(3)) / ln
            if d < -1e-4:              # in front of an inward plane = outside
                convex_bad += 1; break
        else:
            continue
        break
check('geometry comps closed (edge shared 2x, pts exact)', closed_bad == 0, f'bad={closed_bad}')
check('geometry comps convex', convex_bad == 0, f'bad={convex_bad}')

# v9 NO-ADDON gates: the building must carry NO door leaves at all
check('no door selections anywhere in building',
      len(door_members) == 0 and not any(t['name'].decode().startswith('door_')
          for L in lods for t in L['taggs'] if not t['name'].startswith(b'#')))
PINK_RVMAT = b'a3\\structures_f_argo\\civilian\\house_big02\\data\\i_house_big_02_b_pink_multi2.rvmat'
check('no pink-leaf faces in building', not any(f['mat'] == PINK_RVMAT for f in vis['faces']))
fire = lods[4]
check('fire geometry mirrors geometry', len(fire['faces']) == len(geo['faces'])
      and len(fire['pts']) == len(geo['pts']))

# leaf p3ds: 4 LODs, one closed convex comp, all-pink visual, hinge at origin
for leaf in ('door_leaf_wide2', 'door_leaf_narrow2'):
    lp = f'{HERE}/{leaf}.p3d'
    if not os.path.isfile(lp):
        check(f'{leaf}.p3d present', False); continue
    lver, ll = parse(lp)
    ok_res = [L['res'] for L in ll] == [q32(v) for v in (1.0, 1e13, 6e15, 7e15)]
    lvis, lgeo = ll[0], ll[1]
    allpink = all(f['tex'] == b'' and f['mat'] == PINK_RVMAT for f in lvis['faces'])
    lx = [p[0] for p in lvis['pts']]; ly = [p[1] for p in lvis['pts']]
    hinge_ok = -0.03 < min(lx) < 0.06 and min(ly) > -0.02 and max(lx) > 0.9
    lsels = [t for t in lgeo['taggs'] if not t['name'].startswith(b'#')]
    edges = collections.Counter()
    for f in lgeo['faces']:
        idx = [v[0] for v in f['vs'][:f['nv']]]
        for k in range(len(idx)):
            a, b2 = idx[k], idx[(k+1) % len(idx)]
            edges[(min(a, b2), max(a, b2))] += 1
    closed = all(c == 2 for c in edges.values())
    check(f'{leaf}: lods/pink/hinge-origin/1-closed-comp',
          lver == 257 and ok_res and allpink and hinge_ok and len(lsels) == 1 and closed,
          f'res={ok_res} pink={allpink} hinge={hinge_ok} comps={len(lsels)} closed={closed}')

# mass tagg
for t in geo['taggs']:
    if t['name'] == b'#Mass#':
        m = struct.unpack(f'<{len(t["data"])//4}f', t['data'])
        check('#Mass# uniform, sum~1e10', abs(sum(m) - 1e10) < 1e7 and len(set(m)) == 1,
              f'sum={sum(m):.3g}')

# UVSet formula on every LOD: 4 + sum(nv)*8
for i, L in enumerate(lods):
    for t in L['taggs']:
        if t['name'] == b'#UVSet#':
            want = 4 + sum(f['nv'] for f in L['faces']) * 8
            check(f'LOD{i} #UVSet# size', len(t['data']) == want,
                  f'{len(t["data"])} vs {want}')

# tagg order: #SharpEdges#, [selections], [#Mass#], #UVSet#, #EndOfFile#
for i, L in enumerate(lods):
    names = [t['name'] for t in L['taggs']]
    ok = names[0] == b'#SharpEdges#' and names[-2:] == [b'#UVSet#', b'#EndOfFile#']
    check(f'LOD{i} tagg order', ok, str(names[:2] + names[-2:]))

# STAIRWELL HEADROOM GATE. r6 shipped under-stair fill solids whose flat
# bottoms hung into the identical flight one storey below — min clearance
# 0.34 m, 525 blocked path points, owner-reported "top stairs block the
# bottom stairs". Anim-driven probes PASSED that build (script movement does
# not enforce the player controller's overhead clamp), so this must be a
# static gate: walk the stair centerline, find the surface, require 1.8 m of
# clear head band against every geometry component.
def stair_headroom():
    tops = []
    for f in road['faces']:
        pts = [road['pts'][v[0]][:3] for v in f['vs'][:f['nv']]]
        ys = [p[1] for p in pts]
        if max(ys) - min(ys) < 0.01:
            tops.append((ys[0], min(p[0] for p in pts), max(p[0] for p in pts),
                         min(p[2] for p in pts), max(p[2] for p in pts)))
    # exact convex test, NOT aabb: a ramp-parallel slab's aabb hangs ~2 m
    # below its true sloped underside and reads as a phantom blocker. Clip the
    # vertical head-band segment against each component's face half-spaces
    # (inward RH normals): nonempty intersection = genuinely inside the solid.
    solids = []
    for name, ps, fs in comp_members:
        pp = [geo['pts'][i][:3] for i in ps]
        aabb = ([min(q[k] for q in pp) for k in range(3)],
                [max(q[k] for q in pp) for k in range(3)])
        planes = []
        for fi2 in fs:
            f = geo['faces'][fi2]
            n = rh_normal(geo, f)                     # points INTO the solid
            ln = math.sqrt(sum(q * q for q in n))
            if ln < 1e-12: continue
            p0 = geo['pts'][f['vs'][0][0]][:3]
            planes.append((p0, [q / ln for q in n]))
        solids.append((aabb, planes))
    def seg_hits(x, z, ylo2, yhi2, aabb, planes):
        mn, mx = aabb
        if not (mn[0] - 0.25 < x < mx[0] + 0.25 and mn[2] - 0.25 < z < mx[2] + 0.25
                and mn[1] < yhi2 and mx[1] > ylo2):
            return False
        t0, t1 = ylo2, yhi2
        for p0, n in planes:                          # need dot((P-p0),n) >= 0
            base = (x - p0[0]) * n[0] + (z - p0[2]) * n[2] - p0[1] * n[1]
            # constraint: base + y*n[1] >= 0 over y in [t0,t1]
            if abs(n[1]) < 1e-12:
                if base < -1e-6: return False
            elif n[1] > 0:
                t0 = max(t0, -base / n[1])
            else:
                t1 = min(t1, -base / n[1])
            if t0 > t1 - 1e-6: return False
        return True
    lvl = [0.3] + [5.3 + 3.4 * i for i in range(19)] + [69.9]
    worst, nbad = 99.0, 0
    for fi in range(20):
        h, nh = lvl[fi], lvl[fi + 1]; half = (nh - h) / 2
        segs  = [(-3.75, 1.3 - 2.6 * i / 26, h, h + half) for i in range(27)]
        segs += [(-3.75 + 3.0 * i / 8, -1.9, h + half, h + half) for i in range(9)]
        segs += [(-0.75, -1.3 + 2.6 * i / 26, h + half, nh) for i in range(27)]
        segs += [(-0.75 - 3.0 * i / 8, 1.9, nh, nh) for i in range(9)]
        for x, z, ylo, yhi in segs:
            cand = [T[0] for T in tops if T[1] - 1e-6 <= x <= T[2] + 1e-6
                    and T[3] - 1e-6 <= z <= T[4] + 1e-6 and ylo - 0.05 <= T[0] <= yhi + 0.05]
            if not cand: continue
            y = max(cand)
            for aabb, planes in solids:
                hit = False
                for ox, oz in ((0, 0), (0.22, 0), (-0.22, 0), (0, 0.22), (0, -0.22)):
                    if seg_hits(x + ox, z + oz, y + 0.35, y + 1.80, aabb, planes):
                        hit = True; break
                if hit:
                    nbad += 1
                    worst = min(worst, max(0.0, aabb[0][1] - y))
                    break
    return nbad, worst
nbad, worstclr = stair_headroom()
check('stairwell 1.8 m headroom along walk path', nbad == 0,
      f'blocked-points={nbad}' + ('' if nbad == 0 else f' worst-clearance={worstclr:.2f}'))

# SIGNAGE CHIRALITY GATE (drop 8). The corridor floor-number on the core N
# wall (digits z 2.72..2.737) is read by a viewer NORTH of it facing -z, whose
# screen-right is model -x. A correct '2' has its upper vertical stroke on the
# SCREEN RIGHT ('b' segment) and none on the screen left ('f') — mirrored
# authoring (r10 shipped it; reads 'S' in game) fails this. Floor F2, cx=0,
# digit height .5 at cy = 5.31 + 1.6.
def digit2_chirality():
    cy = 5.3 + 0.01 + 1.6
    top_lo, top_hi = cy + 0.08, cy + 0.22          # upper vertical stroke band
    left = right = 0
    for f in vis['faces']:
        if not (f['tex'].startswith(b'#(argb') and b'0.90' in f['tex']):
            continue
        ps = [vis['pts'][v[0]][:3] for v in f['vs'][:f['nv']]]
        if not all(2.70 <= p[2] <= 2.75 and -0.30 <= p[0] <= 0.30 for p in ps):
            continue
        ys = [p[1] for p in ps]
        if min(ys) > top_hi or max(ys) < top_lo:
            continue
        xs = sum(p[0] for p in ps) / len(ps)
        # vertical strokes are tall+narrow; skip horizontal segments (wide)
        if max(p[0] for p in ps) - min(p[0] for p in ps) > 0.20:
            continue
        if xs < -0.02: right += 1                   # model -x = screen RIGHT
        elif xs > 0.02: left += 1
    return left, right
# dominance, not exclusivity: the top horizontal bar's end-cap faces land one
# thin quad on each side; the vertical stroke's face stack dominates only on
# its true side (measured: correct=10:2, mirrored=2:10).
sl, sr = digit2_chirality()
check("floor-2 corridor digit reads '2' from viewer side", sr > 3 * sl,
      f'screen-right strokes={sr} screen-left strokes={sl}')

# atlas-region guards, ARMA v space (v = 1 - viewer v; the write flips).
# Glass must sit in window_set_dark_2_ca's clean pane window (designer: u .35-.63
# arma against our pinned .46-.62, v .23-.56); ACs must match the jewelry
# original's region (v .745-1.0) — a missing/double flip lands both outside.
def uv_region(tex_sub):
    us, vs2 = [], []
    for f in vis['faces']:
        if tex_sub in f['tex']:
            for v in f['vs'][:f['nv']]:
                us.append(v[2]); vs2.append(v[3])
    return us, vs2
gu, gv = uv_region(b'window_set_dark_2')
check('glass UVs in clean-pane window (arma space)',
      gu and 0.34 <= min(gu) and max(gu) <= 0.64 and 0.22 <= min(gv) and max(gv) <= 0.57,
      f'u[{min(gu):.3f},{max(gu):.3f}] v[{min(gv):.3f},{max(gv):.3f}]' if gu else 'none')
au, av = uv_region(b'office_addons')
check('AC UVs match jewelry atlas region (arma space)',
      au and 0.74 <= min(av) and max(av) <= 1.001,
      f'v[{min(av):.3f},{max(av):.3f}]' if au else 'none')

# handoff texture-path claim: every a3\ path present in at least one reference p3d
# (zip uploads/ if present, else the same files shipped at the mission root)
REFDIR = os.path.join(HERE, 'uploads')
if not os.path.isdir(REFDIR):
    REFDIR = '/home/timb/Armapunk2035/mission/Armapunk2035.Malden'
refs = open(f'{REFDIR}/MaldenGrandPalaceBuilding_r4.p3d','rb').read() + \
       open(f'{REFDIR}/JewelryBuildingModel.p3d','rb').read()
# drop 7 door leaves reference the pink house's multimaterial rvmat — that path
# only exists in i_House_Big_02_b_pink_F.p3d (base-game Argo asset)
for cand in (f'{REFDIR}/i_House_Big_02_b_pink_F.p3d',
             '/home/timb/Downloads/i_House_Big_02_b_pink_F.p3d'):
    if os.path.isfile(cand):
        refs += open(cand, 'rb').read()
        break
# v13: .paa paths validate against the game-truth INDEX (extracted 2026-08-06
# from the actual structure PBOs); rvmats still validate against reference p3ds.
INDEX = ''
idx_path = '/home/timb/Armapunk2035/textures_png/INDEX.txt'
if os.path.isfile(idx_path):
    INDEX = open(idx_path, 'r').read()
missing = []
for f in vis['faces']:
    for s in (f['tex'], f['mat']):
        if not s.startswith(b'a3\\') or s in missing:
            continue
        if s.lower().endswith(b'.paa') and INDEX:
            if (s.decode('latin1').lower() + ' ') not in INDEX:
                missing.append(s)
        elif s not in refs:
            missing.append(s)
check('handoff a3 paths present in refs/INDEX', not missing,
      f'missing={[s.decode() for s in missing]}')

print(f'\n{"ALL PASS" if not fails else f"FAILURES: {fails}"}')
sys.exit(1 if fails else 0)
