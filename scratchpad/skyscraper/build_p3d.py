#!/usr/bin/env python3
"""tower_dump.json -> MLOD p3d matching the palace/jewelry reference conventions.

LOD set (matches both reference buildings byte-layout-wise):
  LOD0 visual 1.0      - full tri soup, handoff texture table
  LOD1 shadowB 11002   - minimal closed shells (tower + hut)
  LOD2 geometry 1e13   - convex components: boxes from the primitive registry,
                         stair lanes as wedge prisms
  LOD3 roadway 3e15    - walkable top faces, concrete penetration rvmat

Conventions measured from the references (analyze_refs.py / probe):
  ver=257, hs=0x1c, lv=0x100, lod flags=0, point/face flags=0
  winding: RH normal of vertex order points INTO the solid; stored normals equal
  that inward normal (dot +1). Roadway walkable tops wind RH-normal DOWN.
  taggs: #SharpEdges#, [ComponentNN...], [#Mass#], #UVSet#, #EndOfFile#
  Component naming: Component%02d (Component100 unpadded past 99)
  #Mass#: uniform per point, sum ~1e10 (jewelry-style)
"""
import json, struct, sys, math, os, collections
sys.path.insert(0, '/home/timb/blender_work')
import mlod_rw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = f'{HERE}/Skyscraper20_r14.p3d'

# ---- r6 swinging doors, baked OPEN ----------------------------------------
# The drop wires 100 engine doors (manifest + model.cfg + config.cpp) for the
# ADDON route. createSimpleObject cannot animate, so until the owner picks a
# door architecture we bake every leaf at its full open angle (flat against the
# wall): building fully traversable, leaves visible, collision real. Hinge and
# angle come from doors-manifest.json; the SIGN of each angle only exists in
# model.cfg's per-door `angle1 = "rad +/-100"` — parse it out.
import re as _re
DOORS = {d['id']: d for d in json.load(open(f'{HERE}/doors-manifest.json'))['doors']}
# v9 NO-ADDON route (owner pivot): door leaves are EXCLUDED from the building
# p3d entirely — doorways stay open, frames/signs stay. Each doorway gets a
# standalone leaf simple object (built below from the door_20 / door_1 dump
# meshes) driven by mission script. The manifest still drives the generated
# door data (hinge, yaw, kind, angle) via tools/gen_skyscraper_doors.py.
assert len(DOORS) == 96, len(DOORS)

# bbox invariant (autocenter placement stability — see r6 saga)
FOOT = ((-12.03, 12.03), (-12.03, 14.80))

# ---- handoff material table: three.js material name -> (texture, rvmat) ----
TEX = {
    'concrete_panels_co':             (b'a3\\structures_f_enoch\\data\\concrete\\concrete_panels_co.paa', b''),
    'plaster03_4x4_office_co':        (b'a3\\structures_f\\data\\plaster\\plaster03_4x4_office_co.paa', b''),
    'window_set_dark_2_ca':           (b'a3\\structures_f_exp\\data\\glass\\window_set_dark_2_ca.paa',
                                       b'a3\\structures_f_exp\\data\\glass\\glass.rvmat'),
    'office_addons_co':               (b'a3\\structures_f\\civ\\offices\\data\\office_addons_co.paa',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    # drop 7: door leaves ripped from the pink house are MULTIMATERIAL — the
    # whole look is the rvmat, face texture stays EMPTY (base-game Argo content)
    'house_big02_multi2':             (b'',
                                       b'a3\\structures_f_argo\\civilian\\house_big02\\data\\i_house_big_02_b_pink_multi2.rvmat'),
    'concrete_floor_02_co':           (b'a3\\structures_f_enoch\\data\\floor\\concrete\\concrete_floor_02_co.paa', b''),
    'hotel_02_floor_co':              (b'a3\\structures_f_exp\\data\\wood\\hotel_02_floor_co.paa', b''),
    'tile_04a_co':                    (b'a3\\structures_f\\data\\tile\\tile_04a_co.paa', b''),
    'asphalt_roof_a_co':              (b'a3\\structures_f_enoch\\data\\roof\\asphalt_roof_a_co.paa', b''),
    'wooden_bridge_co':               (b'a3\\structures_f_exp\\data\\wood\\wooden_bridge_co.paa', b''),
    'rollup_combo_co':                (b'a3\\structures_f\\data\\metal\\rollup_combo_co.paa', b''),
    'metal_grey_proc':                (b'#(argb,8,8,3)color(0.55,0.57,0.59,1.0,co)',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'metal_dark_proc':                (b'#(argb,8,8,3)color(0.18,0.20,0.23,1.0,co)',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'white_marking_proc':             (b'#(argb,8,8,3)color(0.90,0.90,0.88,1.0,co)', b''),
}
ROADWAY_MAT = b'a3\\data_f\\penetration\\concrete.rvmat'

dump = json.load(open(f'{HERE}/tower_dump.json'))
meshes = {m['name']: m for m in dump['meshes']}
registry = {r['name']: r for r in dump['registry']}
assert len(meshes) == len(dump['meshes'])

def f32(x):
    return struct.unpack('<f', struct.pack('<f', x))[0]

# ---------------------------------------------------------------- LOD builder
class Lod:
    def __init__(self, res):
        self.res = res
        self.pts = []           # (x,y,z)
        self.norms = []
        self.faces = []         # dicts for mlod_rw
        self._pt = {}
        self._nm = {}
        self.selections = []    # (name, set(ptIdx), set(faceIdx))
        self.comp_key = None    # reference geometry LODs partition points per
                                # component (measured: 0 shared) — namespace them

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
        """corners: list of (pos, normal, uv) in OUTWARD-CCW order (three.js
        convention). Written REVERSED with NEGATED normals -> Arma inward."""
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
        """Edge (a,b) is sharp iff two adjacent faces disagree on the stored
        normal at a shared endpoint — the MLOD split-normal semantic. Smooth
        cylinder walls share normal indices, box corners don't."""
        per_edge = collections.defaultdict(list)   # edge -> [(nA, nB), ...]
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

# ------------------------------------------------------------- solid helpers
def add_box(lod, mn, mx, sel=None):
    """Axis-aligned closed box, 6 quads, outward corners auto-reversed by face()."""
    x0, y0, z0 = mn; x1, y1, z1 = mx
    P = {(i, j, k): (x1 if i else x0, y1 if j else y0, z1 if k else z0)
         for i in (0, 1) for j in (0, 1) for k in (0, 1)}
    quads = [  # (corner keys CCW seen from outside, outward normal)
        ([(0,0,0), (0,0,1), (0,1,1), (0,1,0)], (-1, 0, 0)),
        ([(1,0,0), (1,1,0), (1,1,1), (1,0,1)], ( 1, 0, 0)),
        ([(0,0,0), (1,0,0), (1,0,1), (0,0,1)], ( 0,-1, 0)),
        ([(0,1,0), (0,1,1), (1,1,1), (1,1,0)], ( 0, 1, 0)),
        ([(0,0,0), (0,1,0), (1,1,0), (1,0,0)], ( 0, 0,-1)),
        ([(0,0,1), (1,0,1), (1,1,1), (0,1,1)], ( 0, 0, 1)),
    ]
    fs, ps = [], set()
    for keys, n in quads:
        fi = lod.face([(P[k], n, (0.0, 0.0)) for k in keys])
        fs.append(fi)
    for k in P.values(): ps.add(lod.pt(k))
    if sel is not None: sel[0].update(ps); sel[1].update(fs)

def oriented(corners, n):
    """Return corners ordered so the RH-rule normal aligns with n (outward)."""
    a, b, c = corners[0], corners[1], corners[2]
    d1 = (b[0]-a[0], b[1]-a[1], b[2]-a[2])
    d2 = (c[0]-a[0], c[1]-a[1], c[2]-a[2])
    cr = (d1[1]*d2[2]-d1[2]*d2[1], d1[2]*d2[0]-d1[0]*d2[2], d1[0]*d2[1]-d1[1]*d2[0])
    dot = cr[0]*n[0] + cr[1]*n[1] + cr[2]*n[2]
    assert abs(dot) > 1e-12, (corners, n)
    return corners if dot > 0 else list(reversed(corners))

def add_ramp_slab(lod, x0, x1, y0, y1, z_low, z_high, th=0.42, sel=None):
    """Sloped slab: top face is the ramp surface (y0 at z_low -> y1 at z_high),
    bottom face is the same ramp lowered by th. Stacked flights stay PARALLEL,
    so the flight above always leaves (rise - th) of head clearance — the flat
    -bottomed wedge/box fill used before r7 hung into the climb below and cut
    clearance to 0.34 m (owner-reported block at F1 lane B, audit-proven)."""
    a = (x0, y0 - th, z_low); b = (x1, y0 - th, z_low)
    c = (x0, y1 - th, z_high); d = (x1, y1 - th, z_high)
    e = (x0, y0, z_low); f = (x1, y0, z_low)
    g = (x0, y1, z_high); hh = (x1, y1, z_high)
    dy, dz = y1 - y0, z_high - z_low
    ln = math.hypot(dy, dz)
    up_n = (0.0, abs(dz) / ln, -math.copysign(dy / ln, dz))
    dn_n = (0.0, -up_n[1], -up_n[2])
    sgn = 1.0 if z_high > z_low else -1.0
    fs, ps = [], set()
    def q(corners, n):
        fs.append(lod.face([(p, n, (0.0, 0.0)) for p in oriented(corners, n)]))
    q([e, f, hh, g], up_n)             # top ramp
    q([a, b, d, c], dn_n)              # bottom ramp
    q([a, b, f, e], (0, 0, -sgn))      # end at z_low
    q([c, d, hh, g], (0, 0, sgn))      # end at z_high
    q([a, c, g, e], (-1, 0, 0))        # side x0
    q([b, d, hh, f], (1, 0, 0))        # side x1
    for p in (a, b, c, d, e, f, g, hh): ps.add(lod.pt(p))
    if sel is not None: sel[0].update(ps); sel[1].update(fs)

def add_wedge(lod, x0, x1, y0, y1, z_low, z_high, sel=None):
    """Solid ramp prism: bottom at y0 spanning z_low..z_high; top edge rises from
    y0 at z_low to y1 at z_high (z_low/z_high may be in either order)."""
    a = (x0, y0, z_low); b = (x1, y0, z_low)
    c = (x0, y0, z_high); d = (x1, y0, z_high)
    e = (x0, y1, z_high); f = (x1, y1, z_high)
    sgn = 1.0 if z_high > z_low else -1.0
    dy, dz = y1 - y0, z_high - z_low
    ln = math.hypot(dy, dz)
    slope_n = (0.0, abs(dz) / ln, -math.copysign(dy / ln, dz))  # outward up-slope normal
    fs, ps = [], set()
    def q(corners, n):
        fs.append(lod.face([(p, n, (0.0, 0.0)) for p in oriented(corners, n)]))
    q([a, c, d, b], (0, -1, 0))          # bottom
    q([c, d, f, e], (0, 0, sgn))         # back vertical at z_high
    q([a, b, f, e], slope_n)             # slope from edge ab up to ef
    q([a, c, e], (-1, 0, 0))             # side x0
    q([b, d, f], (1, 0, 0))              # side x1
    for p in (a, b, c, d, e, f): ps.add(lod.pt(p))
    if sel is not None: sel[0].update(ps); sel[1].update(fs)

def top_quad(lod, mn, mx, y, tex=b'', mat=b''):
    """Horizontal walkable quad at height y over rect mn..mx (x,z), RH normal DOWN
    per reference roadway convention -> pass outward-UP corners to face()."""
    x0, z0 = mn; x1, z1 = mx
    lod.face([((x0, y, z0), (0, 1, 0), (0.0, 0.0)),
              ((x0, y, z1), (0, 1, 0), (0.0, 0.0)),
              ((x1, y, z1), (0, 1, 0), (0.0, 0.0)),
              ((x1, y, z0), (0, 1, 0), (0.0, 0.0))], tex=tex, mat=mat)

def slope_quad(lod, x0, x1, y0, y1, z_low, z_high, tex=b'', mat=b''):
    dy, dz = y1 - y0, z_high - z_low
    ln = math.hypot(dy, dz)
    n = (0.0, abs(dz) / ln, -math.copysign(dy / ln, dz))
    a = (x0, y0, z_low); b = (x1, y0, z_low)
    e = (x0, y1, z_high); f = (x1, y1, z_high)
    lod.face([(p, n, (0.0, 0.0)) for p in oriented([a, b, f, e], n)], tex=tex, mat=mat)

# ------------------------------------------------------------------ LOD0 visual
# UV V-FLIP (r4): three.js/OBJ v runs bottom-up, p3d v runs top-down. PROVEN by
# provenance: every distinctive ac-unit-data.js v exists in the jewelry p3d only
# as 1-v (the extraction flipped INTO viewer space), and the r4 handoff authors
# its pinned glass window in "OBJ space ... v flipped". r1-r3 wrote v verbatim,
# which inverted every generated texture (invisible on symmetric concrete/tile,
# wrong atlas region on the r3 ACs). Flip at this write boundary ONLY — the
# synthetic LODs keep their 0.0 placeholder UVs.
vis = Lod(1.0)
tri_total = 0
for m in dump['meshes']:
    tex, mat = TEX[m['mat']]
    pos, nrm, uv = m['pos'], m['norm'], m['uv']
    ntri = len(pos) // 9
    tri_total += ntri
    if m['name'] in DOORS:
        continue                        # leaves live in door_leaf_*.p3d now
    for t in range(ntri):
        corners = []
        for c in range(3):
            i = t * 3 + c
            corners.append(((pos[3*i], pos[3*i+1], pos[3*i+2]),
                            (nrm[3*i], nrm[3*i+1], nrm[3*i+2]),
                            (uv[2*i], 1.0 - uv[2*i+1])))
        vis.face(corners, tex=tex, mat=mat)

# --------------------------------------------------------------- LOD2 geometry
geo = Lod(1e13)
comps = []          # list of (ptset, faceset) accumulated per component
def new_comp():
    c = (set(), set()); comps.append(c)
    geo.comp_key = len(comps)   # fresh point namespace per component
    return c

# The tower repeats the same wall/facade/glass plan every floor. Component
# selections cost (npts+nfaces) bytes EACH, so component count is quadratic in
# file size — merge vertically-stacked identical-footprint boxes into columns.
# Merge tolerance bridges the slab band (0.29+0.01) but never a door opening
# (2.2 m) or a window band (1.9 m) unless the class wants it (glass columns).
def merged_boxes(prims, tol):
    groups = collections.defaultdict(list)
    for p in prims:
        key = (round(p['min'][0], 3), round(p['max'][0], 3),
               round(p['min'][2], 3), round(p['max'][2], 3))
        groups[key].append(p)
    out = []
    for (x0, x1, z0, z1), ps in sorted(groups.items()):
        runs = []
        for p in sorted(ps, key=lambda q: q['min'][1]):
            if runs and p['min'][1] <= runs[-1][1] + tol:
                runs[-1][1] = max(runs[-1][1], p['max'][1])
            else:
                runs.append([p['min'][1], p['max'][1]])
        for y0, y1 in runs:
            out.append(((x0, y0, z0), (x1, y1, z1)))
    return out

def prims_of(suffixes=(), names=(), aab_only=False):
    # Iterate the REGISTRY, not the scene meshes: since r3 the viewer splits
    # collision groups into one object per box (F07_slab_c00...), so scene names
    # no longer match these suffixes. Registry keys are the stable base names.
    ps = []
    for name in sorted(registry):
        if name.endswith(tuple(suffixes)) if suffixes else name in names:
            for p in registry[name]['prims']:
                if not aab_only or p['aab']:
                    ps.append(p)
    return ps

MERGE_PLAN = [
    (prims_of(suffixes=['_walls_interior']), 0.35),   # wall runs merge, headers/doors stay open
    (prims_of(suffixes=['_facade_concrete']), 0.35),  # header+slab-edge+spandrel fuse into bands
    (prims_of(suffixes=['_glass']), 2.5),             # panes fuse into full-height columns
    (prims_of(suffixes=['_slab']) + prims_of(names=['ROOF_slab']), 0.0),
    (prims_of(suffixes=['_elevator_cab']), 0.0),
    (prims_of(names=['ROOF_parapet', 'ROOF_hut', 'ROOF_equipment', 'ROOF_stair_guard']), 0.0),
    # _stair_rails are EXCLUDED from Geometry entirely per the r5/r6 handoff
    # ("rails would clip the mid-landing turn") — confirmed by the b0296/b0297
    # traversal probes + offline envelope audit: the well-guard boxes left only
    # ~0.59 m end-gaps on the mid-landing turn, a walking-capsule squeeze.
    # Rails stay in the visual LOD; the 1.7 m well drop is the designer's call.
    (prims_of(suffixes=['_elevator_door']), 0.0),  # r5 fake shaft-sealing panels, one box per floor
    # b3: 3 m foundation plinth for slope placement — Geometry/Fire only, never Roadway
    (prims_of(names=['FOUNDATION']), 0.0),
]
geo_boxes = []
for prims, tol in MERGE_PLAN:
    geo_boxes.extend(merged_boxes(prims, tol))
for mn, mx in geo_boxes:
    add_box(geo, mn, mx, sel=new_comp())

# coverage invariant: every source prim must sit inside one merged box
def contained(p, boxes):
    e = 1e-3
    for mn, mx in boxes:
        if all(p['min'][k] >= mn[k] - e and p['max'][k] <= mx[k] + e for k in range(3)):
            return True
    return False
for prims, _tol in MERGE_PLAN:
    for p in prims:
        assert contained(p, geo_boxes), ('uncovered prim', p)

# door leaves (r6): one rotated convex box per open leaf. Same quad topology as
# add_box; a pure rotation preserves winding, so corners + normals just rotate.
def add_rot_box(lod, mn, mx, hx, hz, th, sel=None):
    x0, y0, z0 = mn; x1, y1, z1 = mx
    P = {(i, j, k): rot_y((x1 if i else x0, y1 if j else y0, z1 if k else z0), hx, hz, th)
         for i in (0, 1) for j in (0, 1) for k in (0, 1)}
    quads = [
        ([(0,0,0), (0,0,1), (0,1,1), (0,1,0)], (-1, 0, 0)),
        ([(1,0,0), (1,1,0), (1,1,1), (1,0,1)], ( 1, 0, 0)),
        ([(0,0,0), (1,0,0), (1,0,1), (0,0,1)], ( 0,-1, 0)),
        ([(0,1,0), (0,1,1), (1,1,1), (1,1,0)], ( 0, 1, 0)),
        ([(0,0,0), (0,1,0), (1,1,0), (1,0,0)], ( 0, 0,-1)),
        ([(0,0,1), (1,0,1), (1,1,1), (0,1,1)], ( 0, 0, 1)),
    ]
    fs, ps = [], set()
    for keys, n in quads:
        nr = rot_y(n, 0.0, 0.0, th)
        fs.append(lod.face([(P[k], nr, (0.0, 0.0)) for k in keys]))
    for k in P.values(): ps.add(lod.pt(k))
    if sel is not None: sel[0].update(ps); sel[1].update(fs)

# (no door geometry in the building — leaves are separate objects)

# AC units (r3): verbatim jewelry meshes added OUTSIDE mesh(), so not in the
# registry. Handoff: collision = plain 1.45 x 1.07 x 2.94 box each. All three
# are placed unrotated; take each mesh's aabb and assert the dims so a future
# rotated/scaled re-drop fails loudly instead of shipping a wrong box.
for name in sorted(n for n in meshes if n.startswith('ROOF_ac_')):
    pos = meshes[name]['pos']
    mn = [min(pos[i::3]) for i in range(3)]
    mx = [max(pos[i::3]) for i in range(3)]
    dims = [mx[k] - mn[k] for k in range(3)]
    assert all(abs(d - w) < 0.02 for d, w in zip(dims, (1.45, 1.07, 2.94))), (name, dims)
    add_box(geo, mn, mx, sel=new_comp())

# stairs: per floor -> lane A wedge, lane B wedge, mid-landing box.
# r5 splits each floor's stairs into three registry meshes (_stairA/_stairB/
# _stairLand) — no more x-based prim filtering. Keyed on _stairA so a naming
# re-drop that renames the meshes fails the count assert below instead of
# silently building zero stair collision.
stair_wedges = []   # kept for roadway reuse: (x0,x1,y0,y1,z_low,z_high)
for name in sorted(n for n in registry if n.endswith('_stairA')):
    base = name[:-1]                       # 'F01_stair'
    laneA = registry[name]['prims']
    laneB = registry[base + 'B']['prims']
    landing = registry[base + 'Land']['prims']
    assert laneA and laneB and len(landing) == 1, (name, len(laneA), len(laneB), len(landing))
    # Treads are thin floating boxes (top-r-.16 .. top) since the r2 design drop,
    # so the floor level is NOT min(bottom) any more (that is y0-.16, inside the
    # slab). Derive it from the tread TOPS, which are unchanged: uniform spacing r,
    # first top = y0 + r.
    topsA = sorted(p['max'][1] for p in laneA)
    gaps = [b - a for a, b in zip(topsA, topsA[1:])]
    assert all(abs(g - gaps[0]) < 1e-4 for g in gaps), (name, gaps[:4])
    y0 = topsA[0] - gaps[0]
    yA = max(p['max'][1] for p in laneA)      # y0+half-r
    yB = max(p['max'][1] for p in laneB)      # y0+rise-r
    wA = (-4.4, -3.1, y0, yA, 1.3, -1.3)      # descends in z
    wB = (-1.4, -0.1, yA, yB, -1.3, 1.3)      # lane B rises from mid landing level
    # RAMP-PARALLEL slabs, not filled wedges/boxes: flights stack vertically, so
    # any solid extending below the ramp surface by more than ~0.4 hangs into
    # the head band of the identical flight one storey down (r6 shipped that;
    # the owner hit it at F1 lane B and the headroom audit counted 525 blocked
    # path points across 19 floors). The slab matches the floating-tread visual.
    # th clamped so the F1 lane-A slab (floor 0.3) cannot poke below y=0 and
    # grow the bbox — the model autocenters, a grown bbox slides the placement.
    add_ramp_slab(geo, *wA, th=min(0.42, y0), sel=new_comp())
    add_ramp_slab(geo, *wB, sel=new_comp())
    # WELL FALL GUARDS (owner request after the r7 playtest: "you can fall to
    # your death"). Purpose-built, NOT the visual rail meshes (those stay out
    # of Geometry — r5 handoff). Two rules keep the traversal intact:
    # (1) edge fences span only x -3.05..-1.45 — the r5-era guards reached
    #     -3.16..-1.34 and pinched both turn corners to a capsule squeeze;
    #     shortened, the corner pass-throughs are >= ~0.8 m wide;
    # (2) flight-side guards are ramp-parallel slabs hung OVER THE WELL side
    #     of each lane edge (lane A east face, lane B west face), so they add
    #     zero obstruction inside the lane and stay parallel one storey up.
    # fence x-span -2.95..-1.55: the r8 span (-3.05..-1.45) left the lane-A
    # diagonal only 0.10 m of crossing margin and the probe grazed it (F7).
    # The 0.15 m uncovered slivers at the well corners are narrower than the
    # capsule — fall protection is unchanged.
    _landTop = y0 + (yB + gaps[0] - y0) / 2        # = y0 + rise/2 (landing top)
    add_box(geo, (-2.95, _landTop + 0.05, -1.36), (-1.55, _landTop + 0.95, -1.30), sel=new_comp())
    add_box(geo, (-2.95, y0 + 0.05, 1.30), (-1.55, y0 + 0.95, 1.36), sel=new_comp())
    add_ramp_slab(geo, -3.10, -3.04, y0 + 1.05, yA + 1.05, 1.3, -1.3, th=0.95, sel=new_comp())
    add_ramp_slab(geo, -1.46, -1.40, yA + 1.05, yB + 1.05, -1.3, 1.3, th=0.95, sel=new_comp())
    L = landing[0]
    add_box(geo, L['min'], L['max'], sel=new_comp())
    # containment sanity: every tread inside its wedge column + height. Tread
    # bottoms hang .16 below the derived floor level (embedded in the slab).
    for p in laneA + laneB:
        assert p['max'][1] <= (yB if p in laneB else yA) + 1e-4, (name, p)
        assert p['min'][1] >= y0 - 0.161, (name, p)
    stair_wedges.append((name, wA, wB, y0, yA, yB, L))
assert len(stair_wedges) == 20, len(stair_wedges)   # one flight set per floor

geo.selections = []
for i, (ps, fs) in enumerate(comps, 1):
    geo.selections.append((f'Component{i:02d}', ps, fs))


# --------------------------------------------------------------- LOD3 roadway
road = Lod(3e15)
def road_top(prim):
    top_quad(road, (prim['min'][0], prim['min'][2]), (prim['max'][0], prim['max'][2]),
             prim['max'][1], mat=ROADWAY_MAT)

for name in sorted(registry):
    if name.endswith(('_slab', '_floor_wood', '_floor_corridor', '_floor_tile')) \
       or name in ('ROOF_slab', 'ROOF_deck_bitumen'):
        for prim in registry[name]['prims']:
            road_top(prim)
# stair walking surface: PER-TREAD top quads, not ramps. The probe (b0296)
# showed ramp roadway stalls the walking capsule: the F1 flight is 43.9 deg
# (rise 2.5 / run 2.6) and the standard flights 33 deg. Discrete 0.17 risers
# go through the engine's auto-step instead, like vanilla stairs. Geometry
# keeps the solid wedges (bullet/body mass sits below the tread tops).
for name, wA, wB, y0, yA, yB, L in stair_wedges:
    base = name[:-1]
    for lane in (registry[name]['prims'], registry[base + 'B']['prims']):
        for p in lane:
            top_quad(road, (p['min'][0], p['min'][2]), (p['max'][0], p['max'][2]),
                     p['max'][1], mat=ROADWAY_MAT)
    top_quad(road, (L['min'][0], L['min'][2]), (L['max'][0], L['max'][2]),
             L['max'][1], mat=ROADWAY_MAT)
# lobby apron + step (wide, low, in front of the entrance) + elevator cab floor
for prim in registry['F01_facade_concrete']['prims']:
    if prim['min'][2] >= 11.9 and prim['max'][1] <= 0.31 and prim['max'][0] - prim['min'][0] >= 7:
        road_top(prim)
for prim in registry['F01_elevator_cab']['prims']:
    if abs(prim['max'][1] - 0.41) < .02:
        road_top(prim)

# ---------------------------------------------------------------- LOD1 shadow
ROOFY = max(p['max'][1] for p in registry['ROOF_slab']['prims'])
assert abs(ROOFY - 69.9) < 1e-3, ROOFY
shad = Lod(11002.0)
add_box(shad, (-12, 0, -12), (12, ROOFY + 1.26, 12))
add_box(shad, (-5.0, ROOFY, -3.2), (0.6, ROOFY + 2.76, 3.2))

# --------------------------------------------------------------------- write
import copy
geo_f = geo.finish(mass_total=1e10)
fire_f = copy.deepcopy(geo_f)          # Fire Geometry = Geometry incl. door_N comps
fire_f['res'] = 7e15
fire_f['taggs'] = [t for t in fire_f['taggs'] if t['name'] != b'#Mass#']
lods = [vis.finish(), shad.finish(), geo_f, road.finish(), fire_f]
n = mlod_rw.write(OUT, 257, lods)

# roundtrip byte check
ver2, lods2 = mlod_rw.parse(OUT)
back = f'{OUT}.rt'
mlod_rw.write(back, ver2, lods2)
import filecmp
assert filecmp.cmp(OUT, back, shallow=False), 'roundtrip mismatch'

xs = [p[0] for p in lods[0]['pts']]; ys = [p[1] for p in lods[0]['pts']]; zs = [p[2] for p in lods[0]['pts']]
assert abs(min(zs) - FOOT[1][0]) < 0.02 and abs(max(zs) - FOOT[1][1]) < 0.02, (min(zs), max(zs))
assert abs(min(xs) - FOOT[0][0]) < 0.02 and abs(max(xs) - FOOT[0][1]) < 0.02, (min(xs), max(xs))
print(f'wrote {OUT} bytes={n}')
print(f'visual: pts={len(lods[0]["pts"])} norms={len(lods[0]["norms"])} faces={len(lods[0]["faces"])}')
print(f'shadow: pts={len(lods[1]["pts"])} faces={len(lods[1]["faces"])}')
print(f'geometry: pts={len(lods[2]["pts"])} faces={len(lods[2]["faces"])} comps={len(comps)}')
print(f'roadway: pts={len(lods[3]["pts"])} faces={len(lods[3]["faces"])}')
print(f'bbox x [{min(xs):.2f},{max(xs):.2f}] y [{min(ys):.2f},{max(ys):.2f}] z [{min(zs):.2f},{max(zs):.2f}]')
print(f'halfHeight for placement = {(max(ys)-min(ys))/2:.3f}')

# ===================================================== standalone door leaves
# Two leaf p3ds spawned per doorway by mission script (no-addon route).
# RE-ORIGIN: hinge line = local Y axis through (0,0,0), leaf extending +X,
# bottom at y=0 — so a spawned simple object rotates about its hinge with a
# plain setDir.
PINK = TEX['house_big02_multi2']
for out_name, src_door in (('door_leaf_wide2', 'door_20'), ('door_leaf_narrow2', 'door_1')):
    d = DOORS[src_door]
    b = d['box']
    hx, hz, ybase = d['axis']['x'], d['axis']['z'], b[2]
    along_x = (b[1] - b[0]) > (b[5] - b[4])
    assert along_x, (src_door, 'leaf builder assumes an along-X source door')
    flip = abs(b[0] - hx) > abs(b[1] - hx)      # leaf extends -X from hinge -> rotate pi
    def _tp(p):
        x, y, z = p[0] - hx, p[1] - ybase, p[2] - hz
        return (-x, y, -z) if flip else (x, y, z)
    def _tn(n):
        return (-n[0], n[1], -n[2]) if flip else (n[0], n[1], n[2])
    m = meshes[src_door]
    lv = Lod(1.0)
    pos, nrm, uv = m['pos'], m['norm'], m['uv']
    for t in range(len(pos) // 9):
        corners = []
        for c in range(3):
            i = t * 3 + c
            corners.append((_tp((pos[3*i], pos[3*i+1], pos[3*i+2])),
                            _tn((nrm[3*i], nrm[3*i+1], nrm[3*i+2])),
                            (uv[2*i], 1.0 - uv[2*i+1])))
        lv.face(corners, tex=PINK[0], mat=PINK[1])
        # double-sided: the ripped pink-house leaf is one-sided and its back
        # rendered as a black slab in game — emit the mirror face too
        rev = [(p, (-n[0], -n[1], -n[2]), t2) for p, n, t2 in reversed(corners)]
        lv.face(rev, tex=PINK[0], mat=PINK[1])
    xs = [p[0] for p in lv.pts]; ys = [p[1] for p in lv.pts]; zs2 = [p[2] for p in lv.pts]
    span, hgt = max(xs), max(ys)
    assert -0.03 < min(xs) < 0.06 and -0.02 < min(ys) < 0.32, (out_name, min(xs), min(ys))
    lg = Lod(1e13)
    lg.comp_key = 1
    csel = (set(), set()); 
    add_box(lg, (min(xs), min(ys), min(zs2)), (span, hgt, max(zs2)), sel=csel)
    lg.selections = [('Component01', csel[0], csel[1])]
    lg_f = lg.finish(mass_total=120.0)
    import copy as _copy
    view_f = _copy.deepcopy(lg_f); view_f['res'] = 6e15
    view_f['taggs'] = [t for t in view_f['taggs'] if t['name'] != b'#Mass#']
    fire_lf = _copy.deepcopy(view_f); fire_lf['res'] = 7e15
    leaf_lods = [lv.finish(), lg_f, view_f, fire_lf]
    p = f'{HERE}/{out_name}.p3d'
    nby = mlod_rw.write(p, 257, leaf_lods)
    v2, l2 = mlod_rw.parse(p); mlod_rw.write(p + '.rt', v2, l2)
    import filecmp as _fc
    assert _fc.cmp(p, p + '.rt', shallow=False); os.remove(p + '.rt')
    print(f'{out_name}.p3d: span={span:.3f} h={hgt:.3f} thick={max(zs2)-min(zs2):.3f} '
          f'faces={len(lv.faces)} bytes={nby} (src {src_door}, flip={flip})')
