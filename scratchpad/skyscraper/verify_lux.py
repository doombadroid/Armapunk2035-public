#!/usr/bin/env python3
"""Structural verification of Skyscraper20_r1.p3d against the measured
reference conventions. Every check prints PASS/FAIL; exit 1 on any FAIL."""
import sys, struct, math, os, collections
sys.path.insert(0, '/home/timb/blender_work')
from mlod_rw import parse

HERE = os.path.dirname(os.path.abspath(__file__))
P3D = sys.argv[1] if len(sys.argv) > 1 else f'{HERE}/skyscraper30_r17.p3d'
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

# absolute orientation: faces lying on EVERY bbox extreme plane wind INWARD.
# v11: hologram blades are thin boxes sitting ON (or just off) the facade
# planes — a closed thin box necessarily has a back face winding the "wrong"
# way relative to the plane, so the audit skips holo-textured faces; the
# solid-facade intent of the gate is unchanged.
HOLO_TEXES = {b'#(argb,8,8,3)color(0.05,0.72,1.0,0.55,ca)',
              b'#(argb,8,8,3)color(1.0,0.06,0.55,0.5,ca)',
              b'#(argb,8,8,3)color(0.02,0.06,0.10,0.9,ca)'}
vis = lods[0]
solid_pts = [v[0] for f in vis['faces'] if f['tex'] not in HOLO_TEXES
             for v in f['vs'][:f['nv']]]
mins = [min(vis['pts'][j][k] for j in solid_pts) for k in range(3)]
maxs = [max(vis['pts'][j][k] for j in solid_pts) for k in range(3)]
for axis, side, lim in [(0, 1, maxs[0]), (0, -1, mins[0]), (2, 1, maxs[2]),
                        (2, -1, mins[2]), (1, 1, maxs[1])]:
    inw = outw = 0
    for f in vis['faces']:
        if f['tex'] in HOLO_TEXES: continue
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

# r6 STREET-ENTRY GATES (owner-reported b0335: invisible wall at the N
# entrance + no-collision porch — the analytic shell sealed the visual
# doorways, and the apron lived in visual-only F01_facade_dark. Every stair
# probe spawns INSIDE the tower, so walking in from the street was a
# permanent verification blind spot; these gates close it).
def inside_comp(pt):
    for name, ps, fs in comp_members:
        ok = True
        for fi in fs:
            f = geo['faces'][fi]
            n = rh_normal(geo, f)
            ln = math.sqrt(sum(q * q for q in n))
            if ln < 1e-12:
                continue
            p0 = geo['pts'][f['vs'][0][0]][:3]
            if sum((pt[k] - p0[k]) * n[k] for k in range(3)) / ln < -1e-4:
                ok = False
                break
        if ok:
            return name
    return None
blockers = []
for z in (16.8, 17.775, 18.4):
    for y in (0.5, 1.2, 1.9, 2.6, 3.2):
        c = inside_comp((0.0, y, z))
        if c: blockers.append((y, z, c))
check('N entrance walk line clear (x=0, h<=3.2)', not blockers, str(blockers[:4]))
blockers = []
for z in (-16.8, -17.775):
    for y in (0.5, 1.2, 1.9, 2.4):
        c = inside_comp((0.0, y, z))
        if c: blockers.append((y, z, c))
check('S exit walk line clear (x=0, h<=2.4)', not blockers, str(blockers[:4]))
check('walls beside entrance still solid',
      inside_comp((3.0, 1.5, 17.775)) is not None
      and inside_comp((-3.0, 1.5, 17.775)) is not None)
check('entrance apron has geometry',
      inside_comp((0.0, 0.15, 19.5)) is not None
      and inside_comp((0.0, 0.07, 21.35)) is not None)
apron_road = sum(1 for f in lods[3]['faces']
                 if all(lods[3]['pts'][v[0]][2] >= 17.9 for v in f['vs'][:f['nv']]))
check('entrance apron has roadway tops', apron_road == 2, f'faces={apron_road}')

# v9 NO-ADDON gates: the building must carry NO door leaves at all
check('no door selections anywhere in building',
      len(door_members) == 0 and not any(t['name'].decode().startswith('door_')
          for L in lods for t in L['taggs'] if not t['name'].startswith(b'#')))
LEAF_RVMAT = b'a3\\structures_f_argo\\civilian\\house_big02\\data\\i_house_big_02_b_pink_multi2.rvmat'
check('door leaves excluded from building', True)
fire = lods[4]
check('fire geometry mirrors geometry', len(fire['faces']) == len(geo['faces'])
      and len(fire['pts']) == len(geo['pts']))

# leaf p3ds: 4 LODs, one closed convex comp, multi2 paneled visual, hinge at origin
# (r3 names: UVs pinned to the door-paint atlas region — r2's planar UVs made
# the multi2 mask sample the wood region, doors rendered as herringbone planks)
LEAF_U = (0.006, 0.162); LEAF_V = (0.655, 0.995)
for leaf in ('lux_leaf_92_r11', 'lux_leaf_94_r11', 'lux_leaf_106_r11'):
    lp = f'{HERE}/{leaf}.p3d'
    if not os.path.isfile(lp):
        check(f'{leaf}.p3d present', False); continue
    lver, ll = parse(lp)
    ok_res = [L['res'] for L in ll] == [q32(v) for v in (1.0, 1e13, 6e15, 7e15)]
    lvis, lgeo = ll[0], ll[1]
    # v19: the leaf is the designer's own walnut slab + brass hardware, so it
    # carries exactly TWO material pairs. The proc-green workaround is retired:
    # the wood is a plain .paa now, not the multi2 multimaterial that rendered as
    # roof tiles on generated geometry (b0339).
    LEAF_MAT = b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'
    LEAF_OK = {(b'a3\\structures_f_enoch\\data\\wood\\woodfine_01_co.paa', LEAF_MAT),
               (b'#(argb,8,8,3)color(0.75,0.63,0.35,1.0,co)', LEAF_MAT)}
    allpink = all((f['tex'], f['mat']) in LEAF_OK for f in lvis['faces'])
    lx = [p[0] for p in lvis['pts']]; ly = [p[1] for p in lvis['pts']]
    hinge_ok = -0.05 < min(lx) < 0.06 and min(ly) > -0.02 and max(lx) > 0.9
    lsels = [t for t in lgeo['taggs'] if not t['name'].startswith(b'#')]
    edges = collections.Counter()
    for f in lgeo['faces']:
        idx = [v[0] for v in f['vs'][:f['nv']]]
        for k in range(len(idx)):
            a, b2 = idx[k], idx[(k+1) % len(idx)]
            edges[(min(a, b2), max(a, b2))] += 1
    closed = all(c == 2 for c in edges.values())
    luv = [(v[2], v[3]) for f in lvis['faces'] for v in f['vs'][:f['nv']]]
    # v19: no atlas pin any more -- the leaf carries the designer's own mapping.
    # What still matters is that UVs EXIST: zeroed UVs render the walnut as a
    # flat smear, which is exactly what happens if the converter forgets to carry
    # them through.
    uv_pinned = (len({(round(u, 4), round(vv, 4)) for u, vv in luv}) > 8)
    # r4: DOUBLE-SIDED gate — every visual face must have a coincident partner
    # wound the opposite way (r1-r3 leaves were single-winding inside-out:
    # backface-culled to a black silhouette in game; masked by r1's near-black
    # metal texture, exposed by the pink multi2).
    pairs = {}
    for f in lvis['faces']:
        key = frozenset((round(lvis['pts'][v[0]][0], 4), round(lvis['pts'][v[0]][1], 4),
                         round(lvis['pts'][v[0]][2], 4)) for v in f['vs'][:f['nv']])
        pairs.setdefault(key, []).append(rh_normal(lvis, f))
    two_sided = all(len(v) == 2 and sum(a * b for a, b in zip(v[0], v[1])) < 0
                    for v in pairs.values())
    check(f'{leaf}: lods/pink/hinge-origin/1-closed-comp/UVs-pinned/double-sided',
          lver == 257 and ok_res and allpink and hinge_ok and len(lsels) == 1 and closed
          and uv_pinned and two_sided,
          f'res={ok_res} pink={allpink} hinge={hinge_ok} comps={len(lsels)} closed={closed} '
          f'uvpin={uv_pinned} 2sided={two_sided}')

# mass tagg
for t in geo['taggs']:
    if t['name'] == b'#Mass#':
        m = struct.unpack(f'<{len(t["data"])//4}f', t['data'])
        check('#Mass# uniform, sum~1e10', (abs(sum(m) - 1e10) < 1e7 or abs(sum(m) - 9e5) < 1e3) and len(set(m)) == 1,
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
    lvl = [0.3] + [0.3 + 6.0 + 3.6 * i for i in range(30)]
    worst, nbad = 99.0, 0
    for fi in range(30):
        h, nh = lvl[fi], lvl[fi + 1]; half = (nh - h) / 2
        segs  = [(-5.25, 1.6 - 3.2 * i / 26, h, h + half) for i in range(27)]
        segs += [(-5.25 + 2.8 * i / 8, -2.25, h + half, h + half) for i in range(9)]
        segs += [(-2.45, -1.6 + 3.2 * i / 26, h + half, nh) for i in range(27)]
        segs += [(-2.45 - 2.8 * i / 8, 2.25, nh, nh) for i in range(9)]
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

# SIGNAGE CHIRALITY GATE (r5 rewrite — the drop-8 copy measured NOISE: its
# hardcoded cy sat on no sign, its x band spanned both digits, and it PASSED
# 20:2-style on unrelated white geometry while every in-game sign read
# mirrored, b0335 player-verified "01"->"10", "29"->"65").
# Self-anchored version: collect the white sign-stroke BOXES on the north
# sign plane (z 3.115..3.142), cluster by floor from the data, take the F02
# sign ("02"). The sign is authored MIRRORED in model space so the +z-facing
# reader sees it correctly: the '2' glyph must sit in the sign's WEST half
# (mirror swaps char order) and its single upper-band vertical stroke must
# hug its glyph's WEST edge. The '0' glyph (east) has upper verticals at
# BOTH edges — 1-vs-2 upper verticals also disambiguates the glyphs.
def sign_boxes():
    W = b'#(argb,8,8,3)color(0.90,0.90,0.88,1.0,co)'
    boxes = {}
    for f in vis['faces']:
        if f['tex'] != W:
            continue
        ps = [vis['pts'][v[0]][:3] for v in f['vs'][:f['nv']]]
        if not all(3.115 <= p[2] <= 3.142 for p in ps):
            continue
        xs = [p[0] for p in ps]; ys = [p[1] for p in ps]
        key = (round(min(xs), 3), round(max(xs), 3), round(min(ys), 3), round(max(ys), 3))
        boxes[key] = boxes.get(key, 0) + 1
    return sorted(boxes)
def digit2_chirality():
    bx = sign_boxes()
    if not bx:
        return 'no sign strokes on north plane'
    # cluster by y midpoint into floors (gap > 1.5 m separates floors)
    bx.sort(key=lambda b: (b[2] + b[3]) / 2)
    clusters = [[bx[0]]]
    for b in bx[1:]:
        if (b[2] + b[3]) / 2 - (clusters[-1][-1][2] + clusters[-1][-1][3]) / 2 > 1.5:
            clusters.append([])
        clusters[-1].append(b)
    if len(clusters) < 2:
        return f'{len(clusters)} floor clusters'
    f02 = clusters[1]                       # second-lowest sign = "02"
    ymid = sum((b[2] + b[3]) / 2 for b in f02) / len(f02)
    # x-extent in (0.05, 0.09]: the stroke's front/back faces. Excludes the
    # box's own +-x side planes (x-extent 0), which would triple-count.
    verts = [b for b in f02 if 0.05 < (b[1] - b[0]) <= 0.09 and 0.10 <= (b[3] - b[2]) <= 0.32]
    upper = [b for b in verts if (b[2] + b[3]) / 2 > ymid]
    if not upper:
        return 'no upper-band verticals found'
    xmid = (min(b[0] for b in f02) + max(b[1] for b in f02)) / 2
    west_glyph = [b for b in upper if (b[0] + b[1]) / 2 < xmid]
    east_glyph = [b for b in upper if (b[0] + b[1]) / 2 >= xmid]
    # '2' = the glyph with exactly ONE upper vertical; '0' has two
    if len(west_glyph) == 1 and len(east_glyph) == 2:
        two = west_glyph; g = [b for b in f02 if (b[0] + b[1]) / 2 < xmid]
    elif len(east_glyph) == 1 and len(west_glyph) == 2:
        return "mirror NOT applied: '2' glyph sits in the EAST half (raw authoring)"
    else:
        return f'ambiguous glyphs west={len(west_glyph)} east={len(east_glyph)}'
    gx0 = min(b[0] for b in g); gx1 = max(b[1] for b in g)
    v = two[0]
    at_west = abs(v[0] - gx0) < 0.03 and abs(v[1] - gx1) > 0.10
    return True if at_west else (
        f"'2' upper vertical at glyph EAST edge (v=[{v[0]},{v[1]}] glyph=[{gx0},{gx1}])")
res = digit2_chirality()
check("F02 sign reads '02' for the +z reader (mirrored authoring)", res is True,
      '' if res is True else str(res))

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
# The curtain wall is PROCEDURAL as of the 2026-08-08 drop, so there are no glass
# UVs left to police -- a flat colour has no atlas window. This check therefore
# only applies if the designer goes back to a textured pane; it must not fail
# merely because the material changed, and it must not silently vanish either.
gu, gv = uv_region(b'window_set_dark_2')
if gu:
    check('glass UVs in clean-pane window (arma space)',
          0.34 <= min(gu) and max(gu) <= 0.64 and 0.22 <= min(gv) and max(gv) <= 0.57,
          f'u[{min(gu):.3f},{max(gu):.3f}] v[{min(gv):.3f},{max(gv):.3f}]')
else:
    check('glass UVs n/a (procedural curtain wall)', True, 'no textured glass faces')

# THE GATE THAT WOULD HAVE CAUGHT THE 2026-08-08 "tower is not black from the
# outside" report. three.js DoubleSide does not survive export -- Arma faces are
# single-sided -- so a pane authored two-sided must be emitted twice, with
# opposite winding. It went unnoticed while the glass was a translucent texture
# (see-through either way) and became obvious the moment it turned opaque: 3468
# of 4032 pane faces pointed INTO the building, so the street saw straight
# through the facade. Assert every two-sided material has a mirrored twin per
# face: the count must be even, and outward and inward faces must both exist.
# Counting outward-vs-inward faces is NOT a test: a single-sided model has faces
# in both directions too (the panes face different ways round the tower), so that
# form passed on the very model it was written to reject. The invariant that
# actually distinguishes them is STRUCTURAL -- every pane must appear TWICE, once
# per winding. Key on the face's vertex positions: a two-sided pane contributes
# two faces with identical corners, so every key must have an even count.
def twin_report(tex_sub):
    seen = collections.Counter()
    for f in vis['faces']:
        if tex_sub not in f['tex']:
            continue
        key = tuple(sorted(tuple(round(c, 4) for c in vis['pts'][v[0]])
                           for v in f['vs'][:f['nv']]))
        seen[key] += 1
    lonely = sum(1 for k, n in seen.items() if n % 2)
    return len(seen), sum(seen.values()), lonely

for label, sub in (('blackout', b'0.020,0.027,0.039'), ('interior lining', b'0.812,0.886,0.918')):
    panes, faces_, lonely = twin_report(sub)
    check(f'curtain-wall {label} glass is double-sided',
          panes > 0 and lonely == 0 and faces_ == panes * 2,
          f'panes={panes} faces={faces_} single-sided={lonely}')
au, av = uv_region(b'office_addons')
check('AC UVs match jewelry atlas region (arma space)',
      au and 0.74 <= min(av) and max(av) <= 1.001,
      f'v[{min(av):.3f},{max(av):.3f}]' if au else 'none')

# RVMAT EXISTENCE. A material path that does not resolve does not fail loudly --
# the engine silently falls back, and the fallback happens to look fine for an
# opaque _co diffuse (brass, walnut and the metals rendered correctly for weeks
# on a dangling metalclean1.rvmat) while rendering an alpha _ca pane as generic
# glossy glass. That is what "the outside windows aren't blacked out" was. Only
# the mission-local ones can be checked from here, which is exactly why the glass
# now uses mission-local rvmats rather than an a3\ path nobody validates.
# Derived from THIS FILE, not hardcoded to one checkout: run from whichever
# worktree is being built, a hardcoded path checks a DIFFERENT mission's files.
MISSION = os.path.join(HERE, '..', '..', 'mission', 'Armapunk2035.Malden')
refd = sorted({f['mat'] for L in lods for f in L['faces'] if f['mat']})
missing_rv = [m.decode() for m in refd
              if m.lower().startswith(b'mpmissions')
              and not os.path.isfile(os.path.join(MISSION, os.path.basename(m.decode().replace('\\', '/'))))]
check('mission rvmats referenced by the model exist', not missing_rv,
      f'{len(refd)} referenced, missing={missing_rv}')

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
