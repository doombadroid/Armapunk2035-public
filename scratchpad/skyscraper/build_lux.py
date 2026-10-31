#!/usr/bin/env python3
"""lux_dump.json -> skyscraper30_r2.p3d (+ 3 metal leaf p3ds).

30F luxury tower per ARMA3_HANDOFF_LUX.md. Differences from the 20F builder:
- Geometry components are VERBATIM per-scene-mesh face islands (the rounded
  corners are quarter-cylinder wedges and faceted chord boxes — an AABB box
  per prim would square them off and wall up the chamfer ad-canvas).
- Glass gets per-face thin chord-box components (DOCUMENTED DEVIATION from the
  handoff's fire-only glass: a full-height glazed suite with no body collision
  is a walk-through-the-facade fall hazard).
- Doors excluded everywhere (no-addon route); three metal leaf p3ds are
  synthesized from the manifest spans (plain box + handle, hinge at origin).
"""
import json, struct, sys, math, os, collections
sys.path.insert(0, '/home/timb/blender_work')
import mlod_rw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = f'{HERE}/skyscraper30_r17.p3d'

DOORS = {d['id']: d for d in json.load(open(f'{HERE}/lux-doors-manifest.json'))['doors']}
assert len(DOORS) == 88, len(DOORS)

TEX = {
    # ---- v20 drop (luxtower2.zip, 2026-08-19) -------------------------------
    # Every colour below is READ FROM THE SOURCE (kitchen.js / shower.js /
    # toilet.js / lux-tower.js declare them as MeshStandardMaterial name+color),
    # not chosen here -- the handoff's material table never listed them.
    # ap_* textures ship MISSION-LOCAL, the same way the neon and glass rvmats
    # already do; the drop's rvmats named an ap_structures\ addon this project
    # does not have.
    'ap_palette_co'                   : (b'mpmissions\\__cur_mp.Malden\\ap_palette_co.paa',
                                       b'mpmissions\\__cur_mp.Malden\\ap_palette.rvmat'),
    'elev_call_proc'                  : (b'mpmissions\\__cur_mp.Malden\\ap_callplate_co.paa',
                                       b'mpmissions\\__cur_mp.Malden\\ap_callplate.rvmat'),
    'native_house_stone_floor_co'     : (b'a3\\structures_f_exp\\data\\stone\\native_house_stone_floor_co.paa',
                                       b''),
    'woodfine_01_co'                  : (b'a3\\structures_f_enoch\\data\\wood\\woodfine_01_co.paa',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'steel_proc'                      : (b'#(argb,8,8,3)color(0.769,0.788,0.804,1.0,co)',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'matte_black_proc'                : (b'#(argb,8,8,3)color(0.078,0.086,0.098,1.0,co)',
                                       b''),
    'seat_white_proc'                 : (b'#(argb,8,8,3)color(0.914,0.910,0.886,1.0,co)',
                                       b''),
    'porcelain_white_proc'            : (b'#(argb,8,8,3)color(0.949,0.945,0.925,1.0,co)',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'burner_proc'                     : (b'#(argb,8,8,3)color(0.067,0.067,0.067,1.0,co)',
                                       b''),
    'led_warm_proc'                   : (b'#(argb,8,8,3)color(1.000,0.949,0.847,1.0,co)',
                                       b''),
    'glass_black_proc'                : (b'#(argb,8,8,3)color(0.055,0.067,0.078,1.0,co)',
                                       b''),
    'glass_panel_proc'                : (b'#(argb,8,8,3)color(0.106,0.122,0.141,1.0,co)',
                                       b''),
    'glass_clear_proc'                : (b'#(argb,8,8,3)color(0.875,0.949,0.969,0.16,co)',
                                       b'mpmissions\\__cur_mp.Malden\\glass_interior.rvmat'),
    'water_proc'                      : (b'#(argb,8,8,3)color(0.624,0.847,0.902,0.55,co)',
                                       b'mpmissions\\__cur_mp.Malden\\glass_interior.rvmat'),
    'concrete_panels_co':             (b'a3\\structures_f_enoch\\data\\concrete\\concrete_panels_co.paa', b''),
    'gallery_wall_plaster_a_co':      (b'a3\\structures_f_aow\\civilian\\gallery_01\\data\\gallery_wall_plaster_a_co.paa',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'window_set_dark_2_ca':           (b'a3\\structures_f_exp\\data\\glass\\window_set_dark_2_ca.paa',
                                       b'a3\\structures_f_exp\\data\\glass\\glass.rvmat'),
    # v21 (owner drop 2026-08-19): the curtain wall is 0x0b1116 at ALPHA 0.50 --
    # (0.043, 0.067, 0.086). We were still shipping 0.020/0.027/0.039 at alpha 0.94,
    # the value from the 2026-08-08 blackout fix, and it is what made the glazing
    # read wrong in game: at 0.94 an occupant cannot see out at all, and because the
    # pane is SINGLE double-sided glazing since v19, a sightline crossing two walls
    # stacks the tint -- 0.94 twice is near-black, which is why some panes looked far
    # darker than others.
    #
    # 0.50 is the designer's own compromise and the handoff states the intent: the
    # interior behind it is unlit, so the street still reads dark, while someone
    # inside looking out at daylight actually sees through. The one-way look comes
    # from the lighting, not from the alpha.
    #
    # v20 (owner drop 2026-08-08): the designer replaced the textured curtain-wall
    # glass with two PROCEDURAL materials -- an almost-opaque blackout pane, and a
    # faint interior lining mesh sitting 8 cm inboard of it, so the tower reads
    # black from the street and lightly tinted from inside a suite. Both are flat
    # colours, so they need no UV pinning (the GLASS_TEX pin below only ever
    # mattered for a real texture's mapping). Alpha rides in the ca channel.
    # The rvmat these used to point at -- a3\structures_f_exp\data\glass\glass.rvmat --
    # IS NOT IN ANY ARMA 3 PBO (every addon scanned 2026-08-08). With no material
    # to load the engine fell back to a default that ignored the near-black
    # diffuse and drew glossy grey glass: "the outside windows aren't blacked
    # out". These two rvmats ship with the mission, exactly like the neon ones.
    # v21b: this is now the OUTWARD-facing half of the pane ONLY -- see the
    # one-way curtain wall block further down. Fully opaque on purpose. 0.94 was
    # not enough: the suites are lit by 5956 emissive neon faces, and 6% of that
    # still reads as seeing straight in from the street.
    'glass_blackout_proc':            (b'#(argb,8,8,3)color(0.043,0.067,0.086,1.00,ca)',
                                       b'mpmissions\\__cur_mp.Malden\\glass_blackout.rvmat'),
    # v21b: the INWARD-facing half. The designer's authored v21 value, which the
    # owner confirmed reads correctly from a suite ("the inside out looks good").
    # Rides glass_interior.rvmat rather than the blackout one because that has
    # specular 0.03 against 0.30 -- the raised specular exists to bounce sky at
    # the street, and on the pane you are looking THROUGH it is only glare.
    'glass_vision_proc':              (b'#(argb,8,8,3)color(0.043,0.067,0.086,0.50,ca)',
                                       b'mpmissions\\__cur_mp.Malden\\glass_interior.rvmat'),
    'glass_interior_proc':            (b'#(argb,8,8,3)color(0.812,0.886,0.918,0.16,ca)',
                                       b'mpmissions\\__cur_mp.Malden\\glass_interior.rvmat'),
    'concrete_floor_02_co':           (b'a3\\structures_f_enoch\\data\\floor\\concrete\\concrete_floor_02_co.paa', b''),
    'gallery_floor_parquet_b_co':     (b'a3\\structures_f_aow\\civilian\\gallery_01\\data\\gallery_floor_parquet_b_co.paa', b''),
    'marble_tiles_01_co':             (b'a3\\structures_f_exp\\data\\tiles\\marble_tiles_01_co.paa', b''),
    'marble_tiles_02_co':             (b'a3\\structures_f_exp\\data\\tiles\\marble_tiles_02_co.paa',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'metal_panels_white_co':          (b'a3\\structures_f_exp\\data\\metal\\metal_panels_white_co.paa', b''),
    # v19: the designer re-authored the leaves as dark walnut veneer. This is a
    # PLAIN texture + standard rvmat now, not the pink-house multimaterial that
    # rendered as roof tiles on our generated leaves (b0339) -- so the proc-green
    # workaround can retire and the leaves can use the designer's own material.
    'house_big02_multi2':             (b'a3\\structures_f_enoch\\data\\wood\\woodfine_01_co.paa',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'door_brass_proc':                (b'#(argb,8,8,3)color(0.75,0.63,0.35,1.0,co)',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    # r5 leaves: multi2 on a generated mesh proved CONTEXT-FRAGILE in game (A/B
    # b0339: our leaf rendered the atlas roof-tile region, and the 20F
    # door_leaf_wide2 — green at its own tower in b0313 — rendered pitch black
    # beside it). Proc color + metalclean is the tower-proven combo that
    # renders everywhere; the green is the designer's own house_big02 preview
    # tone (0x4e6b52) and the paneling relief carries the door look.
    'leaf_green_proc':                (b'#(argb,8,8,3)color(0.31,0.42,0.32,1.0,co)',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'rollup_combo_co':                (b'a3\\structures_f\\data\\metal\\rollup_combo_co.paa', b''),
    'office_addons_co':               (b'a3\\structures_f\\civ\\offices\\data\\office_addons_co.paa',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'metal_grey_proc':                (b'#(argb,8,8,3)color(0.55,0.57,0.59,1.0,co)',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'metal_elevator_proc': (b'mpmissions\\__cur_mp.Malden\\ap_elevator_co.paa',
                                       b'mpmissions\\__cur_mp.Malden\\ap_elevator.rvmat'),
    'metal_dark_proc':                (b'#(argb,8,8,3)color(0.14,0.15,0.18,1.0,co)',
                                       b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'),
    'white_marking_proc':             (b'#(argb,8,8,3)color(0.90,0.90,0.88,1.0,co)', b''),
    'neon_cyan_proc':                 (b'#(argb,8,8,3)color(0.050,0.720,1.000,1.0,co)',
                                       b'mpmissions\\__cur_mp.Malden\\neon_cyan.rvmat'),
    'neon_magenta_proc':              (b'#(argb,8,8,3)color(1.000,0.060,0.550,1.0,co)',
                                       b'mpmissions\\__cur_mp.Malden\\neon_magenta.rvmat'),
    'neon_violet_proc':               (b'#(argb,8,8,3)color(0.620,0.250,1.000,1.0,co)',
                                       b'mpmissions\\__cur_mp.Malden\\neon_violet.rvmat'),
    'dancefloor_proc':                (b'#(argb,8,8,3)color(0.20,0.10,0.40,1.0,co)',
                                       b'mpmissions\\__cur_mp.Malden\\neon_violet.rvmat'),
    # v11 holograms — visual-only meshes (never in Geometry); alpha ca procs + neon glow rvmats
    'holo_cyan_proc':                 (b'#(argb,8,8,3)color(0.05,0.72,1.0,0.55,ca)',
                                       b'mpmissions\\__cur_mp.Malden\\neon_cyan.rvmat'),
    'holo_magenta_proc':              (b'#(argb,8,8,3)color(1.0,0.06,0.55,0.5,ca)',
                                       b'mpmissions\\__cur_mp.Malden\\neon_magenta.rvmat'),
    'ticker_screen_proc':             (b'#(argb,8,8,3)color(0.02,0.06,0.10,0.9,ca)',
                                       b'mpmissions\\__cur_mp.Malden\\neon_cyan.rvmat'),
}
ROADWAY_MAT = b'a3\\data_f\\penetration\\concrete.rvmat'

# Materials the designer authored as THREE.DoubleSide in lux-tower.js. Kept as a
# name list rather than inferred, because the dump carries no side flag -- if the
# designer marks another material two-sided, it belongs here too.
TWO_SIDED = {'glass_blackout_proc', 'glass_interior_proc', 'white_marking_proc'}

dump = json.load(open(f'{HERE}/lux_dump.json'))
meshes = {m['name']: m for m in dump['meshes']}
registry = {r['name']: r for r in dump['registry']}
assert len(meshes) == len(dump['meshes'])

def f32(x):
    return struct.unpack('<f', struct.pack('<f', x))[0]

class Lod:
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

def add_box(lod, mn, mx, sel=None):
    x0, y0, z0 = mn; x1, y1, z1 = mx
    P = {(i, j, k): (x1 if i else x0, y1 if j else y0, z1 if k else z0)
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
        fs.append(lod.face([(P[k], n, (0.0, 0.0)) for k in keys]))
    for k in P.values(): ps.add(lod.pt(k))
    if sel is not None: sel[0].update(ps); sel[1].update(fs)

def oriented(corners, n):
    a, b, c = corners[0], corners[1], corners[2]
    d1 = (b[0]-a[0], b[1]-a[1], b[2]-a[2])
    d2 = (c[0]-a[0], c[1]-a[1], c[2]-a[2])
    cr = (d1[1]*d2[2]-d1[2]*d2[1], d1[2]*d2[0]-d1[0]*d2[2], d1[0]*d2[1]-d1[1]*d2[0])
    dot = cr[0]*n[0] + cr[1]*n[1] + cr[2]*n[2]
    assert abs(dot) > 1e-12, (corners, n)
    return corners if dot > 0 else list(reversed(corners))

def add_ramp_slab(lod, x0, x1, y0, y1, z_low, z_high, th=0.42, sel=None):
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
    q([e, f, hh, g], up_n)
    q([a, b, d, c], dn_n)
    q([a, b, f, e], (0, 0, -sgn))
    q([c, d, hh, g], (0, 0, sgn))
    q([a, c, g, e], (-1, 0, 0))
    q([b, d, hh, f], (1, 0, 0))
    for p in (a, b, c, d, e, f, g, hh): ps.add(lod.pt(p))
    if sel is not None: sel[0].update(ps); sel[1].update(fs)

def top_quad(lod, mn, mx, y, tex=b'', mat=b''):
    x0, z0 = mn; x1, z1 = mx
    lod.face([((x0, y, z0), (0, 1, 0), (0.0, 0.0)),
              ((x0, y, z1), (0, 1, 0), (0.0, 0.0)),
              ((x1, y, z1), (0, 1, 0), (0.0, 0.0)),
              ((x1, y, z0), (0, 1, 0), (0.0, 0.0))], tex=tex, mat=mat)

# ------------------------------------------------------------------ visual
vis = Lod(1.0)
GLASS_TEX = TEX['window_set_dark_2_ca'][0]
def pin_face(uvs):
    """Arc glass shells escape the source-side pin (it assumes quad boxes) —
    remap any out-of-band window_set face into the clean pane region here."""
    if all(0.455 <= u <= 0.625 and 0.435 <= v <= 0.775 for u, v in uvs):
        return uvs
    us = [u for u, v in uvs]; vs2 = [v for u, v in uvs]
    du = (max(us) - min(us)) or 1.0; dv = (max(vs2) - min(vs2)) or 1.0
    return [(0.46 + (u - min(us)) / du * 0.16, 0.443 + (v - min(vs2)) / dv * 0.325)
            for u, v in uvs]

# v18: two families are NOT part of the tower's visual LOD.
#   GEO_*            hidden convex collision boxes nested inside each slab. The
#                    slab itself is now ONE plan-shaped extruded piece (concave,
#                    with real shaft holes), so its collision cannot be derived
#                    from its own geometry any more -- the designer ships it
#                    separately. Handoff: "DELETE every GEO_* object from
#                    Resolution 1.0".
#   *_KITCHEN/_SHOWER/_TOILET
#                    per-floor fixtures, instanced 29x each in the viewer. The
#                    handoff is explicit: "do NOT import 29 copies" -- they are
#                    536k of the model's 666k triangles (a single toilet is
#                    15.6k). They ship as their own p3ds, placed per floor by the
#                    same spawner pattern the door leaves already use.
FIXTURE_TAGS = ('_KITCHEN', '_SHOWER', '_TOILET')
def is_fixture(n): return any(t in n for t in FIXTURE_TAGS)
def is_geo_box(n): return n.startswith('GEO_')

# v19 doors ship as door_N (walnut leaf) PLUS door_N_hw (brass lever, rose
# plates, kick plates, latch edge) -- two objects per opening. Both belong to the
# LEAF p3d, which the spawner swings; neither may be baked into the tower.
# Matching only `name in DOORS` missed every _hw mesh, so the brass stayed
# welded to the frame at the closed position while its twin swung away on the
# leaf: two sets of handles per door, one of them floating in the doorway.
def is_door_part(n):
    return n in DOORS or (n.endswith('_hw') and n[:-3] in DOORS)

# ------------------------------------------------- one-way curtain wall (v21b)
# WHY. Alpha is symmetric. One number cannot make a pane opaque from the street
# and clear from a suite, and the owner has now reported both ends of that trade
# on the same model (2026-08-19): at 0.94, "its see through on the outside and
# too dark on the inside"; at 0.50, "outside you can see in / the inside out
# looks good though". Raising alpha blinds the occupant, lowering it opens the
# facade. There is no value that satisfies both, so stop looking for one.
#
# The fix is free, because the two faces of a pane are ALREADY emitted
# separately by the TWO_SIDED branch below. Arma faces are single-sided and
# backface-cull, so the outward face is the only one a viewer on the street can
# see, and the inward face is the only one an occupant can see. Give them
# different materials and the pane is genuinely one-way. No extra geometry: the
# face count does not move, only which material each half carries.
#
# WHICH HALF IS WHICH cannot be read off the authored normals -- they are mixed
# (3612 outward against 996 inward), which is the whole reason TWO_SIDED had to
# exist. It is decided geometrically: push the triangle centroid 30 cm along its
# own normal and ask whether it left the storey footprint. The footprint is the
# convex hull of that storey's own glass in XZ, which is what a curtain wall is.
# Cross-checked against a radial test on the 3744 triangles radial can call
# confidently (|dot| > 0.7): zero disagreements.
#
# Triangles with a near-vertical normal (864) are the top and bottom slivers of
# the pane reveal, where "outward" has no meaning. Both their faces take the
# exterior material; they are edge-on to everyone.
def _hull2d(pts):
    pts = sorted(set(pts))
    if len(pts) < 3:
        return pts
    def half(ps):
        o = []
        for p in ps:
            while len(o) >= 2 and (o[-1][0]-o[-2][0])*(p[1]-o[-2][1]) - (o[-1][1]-o[-2][1])*(p[0]-o[-2][0]) <= 0:
                o.pop()
            o.append(p)
        return o
    return half(pts)[:-1] + half(pts[::-1])[:-1]

def _inside2d(h, p):
    for i in range(len(h)):
        a, b = h[i], h[(i+1) % len(h)]
        if (b[0]-a[0])*(p[1]-a[1]) - (b[1]-a[1])*(p[0]-a[0]) < -1e-9:
            return False
    return True

GLASS_EXT_MAT = 'glass_blackout_proc'
GLASS_INT_MAT = 'glass_vision_proc'

def _storey_key(n):
    return n[:3] if (n[:1] == 'F' and n[1:3].isdigit()) else '*'

_gpts = collections.defaultdict(list)
for _m in dump['meshes']:
    if _m['mat'] != GLASS_EXT_MAT:
        continue
    _p = _m['pos']
    for _i in range(0, len(_p), 3):
        _q = (round(_p[_i], 4), round(_p[_i+2], 4))
        _gpts[_storey_key(_m['name'])].append(_q)
        _gpts['*'].append(_q)
GLASS_HULLS = {k: _hull2d(v) for k, v in _gpts.items()}

def glass_outward(name, corners):
    """True if `corners` faces the street, False if it faces the room, None if
    it is an edge-on sliver where the question does not apply."""
    nx = sum(c[1][0] for c in corners) / 3.0
    nz = sum(c[1][2] for c in corners) / 3.0
    nl = math.hypot(nx, nz)
    if nl < 0.15:
        return None
    h = GLASS_HULLS.get(_storey_key(name)) or GLASS_HULLS['*']
    cx = sum(c[0][0] for c in corners) / 3.0
    cz = sum(c[0][2] for c in corners) / 3.0
    return not _inside2d(h, (cx + nx/nl*0.30, cz + nz/nl*0.30))

glass_sides = collections.Counter()

for m in dump['meshes']:
    if is_door_part(m['name']) or is_geo_box(m['name']) or is_fixture(m['name']):
        continue
    tex, mat = TEX[m['mat']]
    pos, nrm, uv = m['pos'], m['norm'], m['uv']
    for t in range(len(pos) // 9):
        uvs = [(uv[2*(t*3+c)], uv[2*(t*3+c)+1]) for c in range(3)]
        if tex == GLASS_TEX:
            uvs = pin_face(uvs)
        corners = []
        for c in range(3):
            i = t * 3 + c
            corners.append(((pos[3*i], pos[3*i+1], pos[3*i+2]),
                            (nrm[3*i], nrm[3*i+1], nrm[3*i+2]),
                            (uvs[c][0], 1.0 - uvs[c][1])))
        # v21b one-way split: front and back of a glass pane take different
        # materials. Every other mesh keeps a single pair, so this is a no-op
        # for them.
        f_tex, f_mat = tex, mat
        b_tex, b_mat = tex, mat
        if m['mat'] == GLASS_EXT_MAT:
            side = glass_outward(m['name'], corners)
            if side is True:
                b_tex, b_mat = TEX[GLASS_INT_MAT]
                glass_sides['authored outward'] += 1
            elif side is False:
                f_tex, f_mat = TEX[GLASS_INT_MAT]
                glass_sides['authored inward'] += 1
            else:
                glass_sides['edge sliver'] += 1
        vis.face(corners, tex=f_tex, mat=f_mat)
        # DOUBLE-SIDED materials get their back face too. Arma faces are
        # single-sided and backface-cull; three.js DoubleSide does not survive
        # the export on its own, so a pane authored as two-sided is visible from
        # exactly one side in game. It went unnoticed while the curtain wall was
        # a translucent _ca texture (you saw through it from either side), and
        # became the "tower is not black from the outside" report the moment the
        # designer made it an opaque blackout: 3468 of the 4032 pane faces were
        # oriented inward, so the street saw straight through the facade.
        # Same idiom the door leaves already use.
        if m['mat'] in TWO_SIDED:
            inv = [(p, (-n[0], -n[1], -n[2]), uv) for p, n, uv in reversed(corners)]
            vis.face(inv, tex=b_tex, mat=b_mat)

print('glass one-way split: ' + ', '.join(f'{k}={v}' for k, v in sorted(glass_sides.items())))

# ------------------------------------------------------- geometry (verbatim)
import re as _re
def base_of(name):
    return _re.sub(r'_c\d+$', '', name)

# v18: '_slab' is GONE from this list -- the slab is now a single concave
# extruded plate and merging its AABB would fill the stair and lift shafts with
# solid collision. Its convex boxes arrive as GEO_* instead (see below). The
# fitted kitchen also left: it is a fixture p3d now, not tower geometry.
GEO_SUFFIX = ('_walls_interior', '_elevator_doors')
GEO_EXACT = {'F01_reception', 'F01_reception_top', 'F01_columns',
             'ROOF_hut', 'ROOF_bar',
             'ROOF_bar_stools', 'ROOF_lounge', 'ROOF_lounge_table',
             'ROOF_dancefloor', 'ROOF_dancefloor_frame', 'ROOF_speaker_1',
             'ROOF_speaker_2', 'ROOF_equipment', 'ROOF_stair_guard',
             # v11: foundation plinth (Geometry/Fire, never Roadway) + crown ticker
             # structure (band/posts touchable from the roof; screens stay visual-only)
             'FOUNDATION', 'TICKER_band', 'TICKER_posts'}

geo = Lod(1e13)
comps = []
def new_comp():
    c = (set(), set()); comps.append(c)
    geo.comp_key = len(comps)
    return c

def islands_of(mesh):
    """Union-find faces into connected islands by shared (rounded) positions."""
    pos = mesh['pos']
    ntri = len(pos) // 9
    key2id = {}
    parent = list(range(ntri))
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]; a = parent[a]
        return a
    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb: parent[ra] = rb
    for t in range(ntri):
        for c in range(3):
            i = t * 3 + c
            k = (round(pos[3*i], 3), round(pos[3*i+1], 3), round(pos[3*i+2], 3))
            if k in key2id:
                union(t, key2id[k])
            else:
                key2id[k] = t
    groups = collections.defaultdict(list)
    for t in range(ntri):
        groups[find(t)].append(t)
    return list(groups.values())

def island_closed(mesh, tris):
    """Every position-keyed edge must be shared by exactly two faces."""
    pos = mesh['pos']
    edges = collections.Counter()
    for t in tris:
        ks = []
        for c in range(3):
            i = t * 3 + c
            ks.append((round(pos[3*i], 3), round(pos[3*i+1], 3), round(pos[3*i+2], 3)))
        for c in range(3):
            a, bb2 = ks[c], ks[(c + 1) % 3]
            edges[(min(a, bb2), max(a, bb2))] += 1
    return all(v == 2 for v in edges.values())

def add_mesh_component(mesh, tris, sel):
    pos, nrm = mesh['pos'], mesh['norm']
    for t in tris:
        corners = []
        for c in range(3):
            i = t * 3 + c
            corners.append(((pos[3*i], pos[3*i+1], pos[3*i+2]),
                            (nrm[3*i], nrm[3*i+1], nrm[3*i+2]), (0.0, 0.0)))
        fi = geo.face(corners)
        sel[1].add(fi)
        for v in geo.faces[fi]['vs'][:3]:
            sel[0].add(v[0])

# HYBRID geometry: an island that IS an axis-aligned box goes into the merge
# pool (vertically-stacked identical footprints fuse into columns — the 20F
# trick that keeps component count linear); only genuinely curved/rotated
# islands (arc wedges, chamfer walls, cylinders) become verbatim components.
def island_box(mesh, tris):
    pos = mesh['pos']
    xs = []; ys = []; zs = []
    for t in tris:
        for c in range(3):
            i = t * 3 + c
            xs.append(pos[3*i]); ys.append(pos[3*i+1]); zs.append(pos[3*i+2])
    mn = (min(xs), min(ys), min(zs)); mx = (max(xs), max(ys), max(zs))
    for t in tris:
        for c in range(3):
            i = t * 3 + c
            p = (pos[3*i], pos[3*i+1], pos[3*i+2])
            for k in range(3):
                if abs(p[k] - mn[k]) > 2e-3 and abs(p[k] - mx[k]) > 2e-3:
                    return None
    return mn, mx

merge_pool = []          # (mn, mx) axis-aligned boxes
verbatim = []            # (mesh, tris)
geo_mesh_count = 0

# A MESH THAT SHIPS ITS OWN GEO_* DECOMPOSITION MUST NOT ALSO BE ITS OWN COLLISION.
# That is the whole point of the decomposition, and the slab-collision comment below
# states it: the plates are concave now, so they cannot be their own collision.
#
# It was not enforced here, and island_box let it through silently. Its test is
# "every vertex lies on the AABB boundary" -- which is TRUE of a flat slab with
# rectangular holes punched in it. v19 merged each group into ONE object, so
# F01_walls_interior became a single wall panel with the door openings as holes; it
# passed the box test and came back as a SOLID box spanning x[-6.10,6.10], sealing
# every doorway on the floor. r12 has the four separate wall segments with a 1.0 m
# gap at x[-4.30,-3.30]; r13 had those AND the slab over them. Measured in game:
# the ground-floor doorway was impassable.
_geo_covered = set()
for _n in meshes:
    if _n.startswith('GEO_'):
        _b = _n[4:]
        if '_c' in _b:
            _b = _b.rsplit('_c', 1)[0]
        _geo_covered.add(_b)

for name in sorted(meshes):
    b = base_of(name)
    if b.startswith('door_') or b.endswith(('_stairA', '_stairB', '_stairLand')):
        continue
    if is_geo_box(name) or is_fixture(name):
        continue
    if b in _geo_covered or name in _geo_covered:
        continue
    if not (b.endswith(GEO_SUFFIX) or b in GEO_EXACT):
        continue
    m = meshes[name]
    for isl in islands_of(m):
        bb = island_box(m, isl)
        if bb is not None:
            merge_pool.append(bb)
        else:
            verbatim.append((m, isl))

def merged_boxes(prims, tol):
    groups = collections.defaultdict(list)
    for mn, mx in prims:
        key = (round(mn[0], 3), round(mx[0], 3), round(mn[2], 3), round(mx[2], 3))
        groups[key].append((mn[1], mx[1]))
    out = []
    for (x0, x1, z0, z1), spans in sorted(groups.items()):
        runs = []
        for y0v, y1v in sorted(spans):
            if runs and y0v <= runs[-1][1] + tol:
                runs[-1][1] = max(runs[-1][1], y1v)
            else:
                runs.append([y0v, y1v])
        for y0v, y1v in runs:
            out.append(((x0, y0v, z0), (x1, y1v, z1)))
    return out

for mn, mx in merged_boxes(merge_pool, 0.40):
    add_box(geo, mn, mx, sel=new_comp())

# rotated PRISMS (arc chord boxes, chamfer walls, quarter wedges): an island
# whose vertices sit on exactly two y-levels is an extrusion — group by xz
# footprint, merge vertical runs, and re-emit ONE template island per run with
# its y-levels stretched. Chord stacks over 30 floors collapse into columns.
prisms = collections.defaultdict(list)   # footprint -> [(y0, y1, mesh, tris)]
odd = []
for m, isl in verbatim:
    pos = m['pos']
    ys = set(); foot = set()
    for t in isl:
        for c in range(3):
            i = t * 3 + c
            ys.add(round(pos[3*i+1], 3))
            foot.add((round(pos[3*i], 3), round(pos[3*i+2], 3)))
    if len(ys) == 2:
        y0v, y1v = sorted(ys)
        prisms[tuple(sorted(foot))].append((y0v, y1v, m, isl))
    else:
        odd.append((m, isl))

def emit_stretched(mesh, tris, src_y0, src_y1, dst_y0, dst_y1, sel):
    pos, nrm = mesh['pos'], mesh['norm']
    for t in tris:
        corners = []
        for c in range(3):
            i = t * 3 + c
            y = pos[3*i+1]
            ny = dst_y0 if abs(y - src_y0) < 2e-3 else dst_y1
            corners.append(((pos[3*i], ny, pos[3*i+2]),
                            (nrm[3*i], nrm[3*i+1], nrm[3*i+2]), (0.0, 0.0)))
        fi = geo.face(corners)
        sel[1].add(fi)
        for v in geo.faces[fi]['vs'][:3]:
            sel[0].add(v[0])

for foot, entries in sorted(prisms.items()):
    entries.sort()
    runs = []
    for y0v, y1v, m, isl in entries:
        if runs and y0v <= runs[-1][1] + 0.40:
            runs[-1][1] = max(runs[-1][1], y1v)
        else:
            runs.append([y0v, y1v, m, isl, y0v, y1v])
    for y0v, y1v, m, isl, sy0, sy1 in runs:
        if island_closed(m, isl):
            emit_stretched(m, isl, sy0, sy1, y0v, y1v, new_comp())
        else:
            pos = m['pos']
            xs=[];zs=[]
            for t in isl:
                for c in range(3):
                    i=t*3+c
                    xs.append(pos[3*i]);zs.append(pos[3*i+2])
            add_box(geo, (min(xs), y0v, min(zs)), (max(xs), y1v, max(zs)), sel=new_comp())
        geo_mesh_count += 1
open_boxed = 0
for m, isl in odd:
    if island_closed(m, isl):
        add_mesh_component(m, isl, new_comp())
    else:
        pos = m['pos']
        xs=[];ys=[];zs=[]
        for t in isl:
            for c in range(3):
                i=t*3+c
                xs.append(pos[3*i]);ys.append(pos[3*i+1]);zs.append(pos[3*i+2])
        add_box(geo, (min(xs),min(ys),min(zs)), (max(xs),max(ys),max(zs)), sel=new_comp())
        open_boxed += 1
    geo_mesh_count += 1

# PERIMETER SHELL: instead of per-floor facade/glass/parapet components
# (thousands of chord facets), the whole envelope is ~30 full-height convex
# prisms built analytically from the plan: 4 straight walls, 3 rounded corners
# as 8 chord prisms each, the NE chamfer wall. Solid glass by design (fall
# hazard otherwise); visual LODs keep every facade detail untouched.
SHELL_TOP = ROOF_TOP = None
def make_prism(quad, y0v, y1v):
    """quad: 4 (x,z) footprint corners in outline order; extrude y0v..y1v."""
    sel = new_comp()
    pts_top = [(x, y1v, z) for x, z in quad]
    pts_bot = [(x, y0v, z) for x, z in quad]
    cx = sum(x for x, z in quad) / 4.0; cz = sum(z for x, z in quad) / 4.0
    def q(corners, n):
        fi = geo.face([(p, n, (0.0, 0.0)) for p in oriented(corners, n)])
        sel[1].add(fi)
        for v in geo.faces[fi]['vs'][:geo.faces[fi]['nv']]:
            sel[0].add(v[0])
    q(pts_top, (0, 1, 0))
    q(pts_bot, (0, -1, 0))
    for k in range(4):
        a = quad[k]; b = quad[(k + 1) % 4]
        mxp = ((a[0] + b[0]) / 2 - cx, (a[1] + b[1]) / 2 - cz)
        ln = math.hypot(mxp[0], mxp[1]) or 1.0
        n = (mxp[0] / ln, 0, mxp[1] / ln)
        q([(a[0], y0v, a[1]), (b[0], y0v, b[1]), (b[0], y1v, b[1]), (a[0], y1v, a[1])], n)

_OUT, _IN = 18.0, 17.55
ROOFY = max(p['max'][1] for p in registry['ROOF_slab']['prims'])
_TOP = ROOFY + 1.3          # through the parapet band
def _arc(cx, cz, th0):
    for k in range(8):
        a0 = th0 + k * (math.pi / 2) / 8
        a1 = th0 + (k + 1) * (math.pi / 2) / 8
        o0 = (cx + 9.0 * math.cos(a0), cz + 9.0 * math.sin(a0))
        o1 = (cx + 9.0 * math.cos(a1), cz + 9.0 * math.sin(a1))
        i0 = (cx + 8.55 * math.cos(a0), cz + 8.55 * math.sin(a0))
        i1 = (cx + 8.55 * math.cos(a1), cz + 8.55 * math.sin(a1))
        make_prism([o0, o1, i1, i0], 0.0, _TOP)
# straight walls between arc tangents (NE corner is the chamfer).
# r6: the N and S walls carry the F01 street doorways (visual: entrance
# opening 4.2 w x 3.2 h at x 0, exit 1.4 x 2.4) — the full-height prisms
# sealed them, an invisible wall at the entrance (owner-reported b0335;
# every probe spawned INSIDE, so street entry was never walked). Each wall
# becomes side prisms + a header above the opening; the doorway columns
# stay clear for the full opening height.
make_prism([(-9, _OUT), (-2.1, _OUT), (-2.1, _IN), (-9, _IN)], 0.0, _TOP)   # N west of entrance
make_prism([(2.1, _OUT), (9, _OUT), (9, _IN), (2.1, _IN)], 0.0, _TOP)       # N east of entrance
make_prism([(-2.1, _OUT), (2.1, _OUT), (2.1, _IN), (-2.1, _IN)], 3.55, _TOP)  # N header
make_prism([(-9, -_OUT), (-0.7, -_OUT), (-0.7, -_IN), (-9, -_IN)], 0.0, _TOP)  # S west of exit
make_prism([(0.7, -_OUT), (9, -_OUT), (9, -_IN), (0.7, -_IN)], 0.0, _TOP)      # S east of exit
make_prism([(-0.7, -_OUT), (0.7, -_OUT), (0.7, -_IN), (-0.7, -_IN)], 2.75, _TOP)  # S header
make_prism([(-_OUT, -9), (-_OUT, 9), (-_IN, 9), (-_IN, -9)], 0.0, _TOP)    # W
make_prism([(_OUT, -9), (_OUT, 9), (_IN, 9), (_IN, -9)], 0.0, _TOP)        # E

# r6: entrance apron (the street porch, F01_facade_dark visual: z 18..21 slab
# + 21..21.7 step) was VISUAL-ONLY — "the platform you walk on has no
# collision" (owner-reported b0335). Geometry boxes + roadway tops.
APRON = [((-4.5, 0.0, _OUT), (4.5, 0.3, 21.0)),
         ((-4.5, 0.0, 21.0), (4.5, 0.15, 21.7))]
for mn, mx in APRON:
    add_box(geo, mn, mx, sel=new_comp())
_arc(-9, 9, math.pi / 2)     # NW
_arc(-9, -9, math.pi)        # SW
_arc(9, -9, -math.pi / 2)    # SE
make_prism([(9, _OUT), (_OUT, 9), (_IN - 0.32, 9), (9, _IN - 0.32)], 0.0, _TOP)  # NE chamfer
glass_boxes = 36

# stairs: derived ramp-slab system (proven on the 20F tower)
stair_wedges = []
for name in sorted(n for n in registry if n.endswith('_stairA')):
    base = name[:-1]
    laneA = registry[name]['prims']
    laneB = registry[base + 'B']['prims']
    landing = registry[base + 'Land']['prims']
    assert laneA and laneB and len(landing) == 1, name
    topsA = sorted(p['max'][1] for p in laneA)
    gaps = [b2 - a2 for a2, b2 in zip(topsA, topsA[1:])]
    assert all(abs(g - gaps[0]) < 1e-4 for g in gaps), (name, gaps[:4])
    y0 = topsA[0] - gaps[0]
    yA = max(p['max'][1] for p in laneA)
    yB = max(p['max'][1] for p in laneB)
    ax0 = min(p['min'][0] for p in laneA); ax1 = max(p['max'][0] for p in laneA)
    bx0 = min(p['min'][0] for p in laneB); bx1 = max(p['max'][0] for p in laneB)
    az = sorted({round(p['min'][2], 2) for p in laneA} | {round(p['max'][2], 2) for p in laneA})
    zlo, zhi = az[0], az[-1]
    # lane A entry side = the z of the LOWEST tread
    lowA = min(laneA, key=lambda p: p['max'][1])
    entryA = zhi if abs(lowA['max'][2] - zhi) < abs(lowA['min'][2] - zlo) else zlo
    farA = zlo if entryA == zhi else zhi
    wA = (ax0, ax1, y0, yA, entryA, farA)
    wB = (bx0, bx1, yA, yB, farA, entryA)
    add_ramp_slab(geo, *wA, th=min(0.42, y0), sel=new_comp())
    add_ramp_slab(geo, *wB, sel=new_comp())
    L = landing[0]
    add_box(geo, L['min'], L['max'], sel=new_comp())
    for p in laneA + laneB:
        assert p['max'][1] <= (yB if p in laneB else yA) + 1e-4, (name, p)
        assert p['min'][1] >= y0 - 0.161, (name, p)
    stair_wedges.append((name, wA, wB, y0, yA, yB, L, (ax0, ax1, bx0, bx1)))
assert len(stair_wedges) == 30, len(stair_wedges)

# well fall guards, derived from measured lane edges (20F design):
# short edge fences at both landing lines + ramp-parallel side slabs over the
# well side of each lane edge
for name, wA, wB, y0, yA, yB, L, (ax0, ax1, bx0, bx1) in stair_wedges:
    entryA, farA = wA[4], wA[5]
    landTop = L['max'][1]
    wellW, wellE = ax1, bx0            # well spans between lane A east and lane B west
    m0, m1 = wellW + 0.15, wellE - 0.15
    sgn = 1 if entryA > farA else -1
    add_box(geo, (m0, landTop + 0.05, farA - 0.06 * sgn if sgn > 0 else farA),
                 (m1, landTop + 0.95, farA if sgn > 0 else farA + 0.06), sel=new_comp())
    # ENTRY-END FALL GUARD REMOVED (2026-08-19). It spanned x[-4.45,-3.25] at
    # y[0.35,1.25] -- a 0.9 m solid panel directly across the stairwell DOORWAY,
    # whose opening is x[-4.30,-3.30]. Walking in through the door put you into it
    # at z=1.63, too tall to step over: "cannot get in the doorway on the bottom
    # floor", on every floor, in r12 and r13 alike.
    #
    # It is present in r12 too, which is why swapping collision, clearing the fuel
    # station and three separate AABB fixes all changed nothing -- this was never a
    # v20/v21 regression, so nothing that diffed the two builds could find it.
    #
    # The far-end guard below still fences the well at the landing, which is the
    # side you can actually fall down. The entry side is where people walk in, and
    # a stairwell does not get a barrier across its own door.
    add_ramp_slab(geo, ax1, ax1 + 0.06, y0 + 1.05, yA + 1.05, entryA, farA, th=0.95, sel=new_comp())
    add_ramp_slab(geo, bx0 - 0.06, bx0, yA + 1.05, yB + 1.05, farA, entryA, th=0.95, sel=new_comp())

def _axis_aligned(xs, ys, zs, eps=1e-4):
    """True when a mesh really IS its AABB -- i.e. an axis-aligned box.

    v18's GEO_* collision meshes were all axis-aligned boxes, so replacing one
    with its AABB was verbatim. v20 made the stair flights ROTATED convex prisms,
    the first rotated Geometry in this model, and an AABB of a rotated prism fills
    the whole flight volume floor-to-ceiling -- paving the stairwell solid, which
    is precisely the "invisible walls" failure the slab-collision comment below
    warns about. Measured in game: the ground-floor stair doorway was impassable
    and the flights unclimbable, with a solid box (2 unique Y values) sitting
    alongside the correct prism (4) on every floor.
    """
    for lo, hi, vs in ((min(xs), max(xs), xs), (min(ys), max(ys), ys), (min(zs), max(zs), zs)):
        for v in vs:
            if abs(v - lo) > eps and abs(v - hi) > eps:
                return False
    return True


# v18 SLAB COLLISION. The slab/ceiling plates are concave now (plan outline with
# real shaft holes), so they cannot be their own collision -- an AABB would pave
# the stairwell and lift shaft solid, which is exactly the "invisible walls" the
# handoff warns about. The designer ships the convex decomposition instead, as
# hidden GEO_* boxes nested inside each slab. One box -> one component, verbatim,
# never hulled or merged.
geo_boxes = 0
geo_rot = 0
geo_skip_stair = 0
for name in sorted(meshes):
    if not is_geo_box(name):
        continue
    # STAIRS ALREADY HAVE COLLISION. The stair_wedges pass above emits the ramp
    # prism and its fall-guard slab per flight -- exactly the two components r12
    # ships (Component321 y[0.0,3.124] and Component413 y[0.4,4.174], both z +-1.6).
    #
    # v20's `geo='only'` mode added 120 GEO_F##_stair{A,B,Land,rails}_c## meshes
    # that r12 never had. Emitting those here produced a THIRD component per
    # flight, inflated to z +-1.74 and y[-0.086,3.206] -- protruding past the real
    # prism and sealing the ground-floor doorway. Measured in game: doorway
    # impassable, flights unclimbable. r12's stairwell geometry is unchanged in
    # v21, so the correct collision is r12's, and this pass must not add to it.
    if 'stair' in name.lower():
        geo_skip_stair += 1
        continue
    m = meshes[name]
    pos = m['pos']
    xs = pos[0::3]; ys = pos[1::3]; zs = pos[2::3]
    if _axis_aligned(xs, ys, zs):
        add_box(geo, (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs)), sel=new_comp())
    else:
        # Rotated convex prism (v20 stair flights). Emit it VERBATIM -- Arma
        # Geometry takes rotated convex hulls natively, so there is nothing to
        # approximate. Boxing it is what sealed the stairwell.
        for _isl in islands_of(m):
            add_mesh_component(m, _isl, new_comp())
        geo_rot += 1
    geo_boxes += 1
assert geo_boxes > 0, 'v18 expects GEO_* slab collision boxes and found none'

geo.selections = []
for i, (ps, fs) in enumerate(comps, 1):
    geo.selections.append((f'Component{i:02d}', ps, fs))

# ----------------------------------------------------------------- roadway
road = Lod(3e15)
def road_top(prim):
    top_quad(road, (prim['min'][0], prim['min'][2]), (prim['max'][0], prim['max'][2]),
             prim['max'][1], mat=ROADWAY_MAT)
# v18: walkable slab surface comes from the GEO_* boxes. Using the concave slab
# mesh's own AABB would pave over the stair and lift shafts -- you would walk on
# air across the holes.
skipped_rotated = []
for name in sorted(meshes):
    if not is_geo_box(name):
        continue
    m = meshes[name]
    pos = m['pos']
    xs = pos[0::3]; ys = pos[1::3]; zs = pos[2::3]
    # Skip only the STAIR ramps. Their AABB top is a flat plate at the flight's
    # highest point, laid over the whole shaft -- that was the lid you stood on
    # instead of the stairs.
    #
    # Every OTHER rotated mesh is a flat piece rotated in PLAN -- the chamfered
    # corner floor plates especially -- and its AABB top is the correct height, so
    # boxing it is harmless. Skipping those too cost 1155 floor points per storey
    # around the perimeter and corners, which is where you fell through.
    if (not _axis_aligned(xs, ys, zs)) and 'stair' in name.lower():
        skipped_rotated.append(name)
        continue
    top_quad(road, (min(xs), min(zs)), (max(xs), max(zs)), max(ys), mat=ROADWAY_MAT)
if skipped_rotated:
    print(f'roadway: skipped {len(skipped_rotated)} ROTATED geo mesh(es) '
          f'(AABB would pave over them), e.g. {skipped_rotated[:3]}')
# v18: the floor COVERINGS are plan-shaped single pieces too (handoff: "F##_slab
# / F##_floor_* / F##_ceiling are ONE plan-shaped object each"). Taking their
# registry AABB as a roadway quad paved one 35x35 m surface per floor straight
# over the stair and lift shafts -- you would have walked on air across the
# stairwell, and the headroom gate caught it as 319 blocked points because it
# then measured head clearance from that phantom floor instead of from the
# treads. The GEO_* boxes above already provide the walkable surface at slab
# top; the coverings sit 3 cm proud of it and add nothing.
#
# ROOF_deck_tile is likewise plan-shaped now and is covered by GEO_ROOF_slab_c*.
for name, wA, wB, y0, yA, yB, L, _lanes in stair_wedges:
    base = name[:-1]
    for lane in (registry[name]['prims'], registry[base + 'B']['prims']):
        for p in lane:
            top_quad(road, (p['min'][0], p['min'][2]), (p['max'][0], p['max'][2]),
                     p['max'][1], mat=ROADWAY_MAT)
    top_quad(road, (L['min'][0], L['min'][2]), (L['max'][0], L['max'][2]),
             L['max'][1], mat=ROADWAY_MAT)
# dancefloor top (scene mesh, not in registry)
df = meshes.get('ROOF_dancefloor')
if df:
    xs = df['pos'][0::3]; ys = df['pos'][1::3]; zs = df['pos'][2::3]
    top_quad(road, (min(xs), min(zs)), (max(xs), max(zs)), max(ys), mat=ROADWAY_MAT)
# r6: entrance apron walk surfaces.
# v21 split the apron into its OWN mesh (F01_apron) so Roadway can take its top
# faces by name, and the registry-driven pass above now emits them. Emitting the
# hardcoded APRON boxes as well produced the SAME two quads twice -- 5 faces where
# the gate expects 2 (the fifth is the entrance canopy at y=4.34, which the gate's
# bare z>=17.9 filter also catches). The named mesh is the source of truth now.
if 'F01_apron' not in registry:
    for mn, mx in APRON:
        top_quad(road, (mn[0], mn[2]), (mx[0], mx[2]), mx[1], mat=ROADWAY_MAT)

# ------------------------------------------------------------------ shadow
shad = Lod(11002.0)
add_box(shad, (-18, 0, -18), (18, ROOFY + 1.3, 18))
hutp = registry['ROOF_hut']['prims']
add_box(shad, (min(p['min'][0] for p in hutp), ROOFY, min(p['min'][2] for p in hutp)),
              (max(p['max'][0] for p in hutp), max(p['max'][1] for p in hutp),
               max(p['max'][2] for p in hutp)))

# -------------------------------------------------------------------- write
import copy
geo_f = geo.finish(mass_total=900000.0)
fire_f = copy.deepcopy(geo_f)
fire_f['res'] = 7e15
fire_f['taggs'] = [t for t in fire_f['taggs'] if t['name'] != b'#Mass#']
lods = [vis.finish(), shad.finish(), geo_f, road.finish(), fire_f]
n = mlod_rw.write(OUT, 257, lods)
ver2, l2 = mlod_rw.parse(OUT)
mlod_rw.write(OUT + '.rt', ver2, l2)
import filecmp
assert filecmp.cmp(OUT, OUT + '.rt', shallow=False)
os.remove(OUT + '.rt')

xs = [p[0] for p in lods[0]['pts']]; ys = [p[1] for p in lods[0]['pts']]; zs = [p[2] for p in lods[0]['pts']]
print(f'wrote {OUT} bytes={n}')
print(f'visual: faces={len(lods[0]["faces"])}  geometry: comps={len(comps)} '
      f'(verbatim meshes={geo_mesh_count}, glass boxes={glass_boxes}, GEO slab boxes={geo_boxes}, rotated-verbatim={geo_rot}, stair-skipped={geo_skip_stair})  roadway: faces={len(lods[3]["faces"])}')
print(f'bbox x [{min(xs):.2f},{max(xs):.2f}] y [{min(ys):.2f},{max(ys):.2f}] z [{min(zs):.2f},{max(zs):.2f}]')
print(f'halfHeight for placement = {(max(ys)-min(ys))/2:.3f}')
print(f'depth-center for door gen = {(min(zs)+max(zs))/2:.3f}')

# ------------------------------------------------------- designer's leaves
# v19: the designer re-authored the door leaves IN THE TOWER SOURCE -- a walnut
# veneer slab with a proud moulding frame on both faces (door_N) plus separate
# brass hardware: lever sets, rose plates, kick plates, latch edge (door_N_hw).
#
# So we stop hand-rolling panel boxes and BUILD THE LEAF P3D FROM THEIR GEOMETRY.
# The tower itself still ships doorless (no-addon route: leaves are separate
# spawned objects), but the leaf art is now theirs, not our approximation.
#
# Transform: their doors sit in tower model space, axis-aligned along x or z with
# the hinge on one end. The leaf p3d frame is the one lux_doors.sqf places into --
# X = across the opening starting AT THE HINGE, Y = height from the sill, Z =
# thickness centred on 0. That mapping is a signed axis permutation; where its
# determinant is negative the winding must be reversed, or the leaf renders
# inside-out (the exact defect that made the leaves a black silhouette in b0339).
#
# The per-kind OVERSIZE from r6 is preserved by scaling u about the hinge so the
# leaf spans -ext .. span+ext: their leaf is authored to the door box exactly, and
# the openings carry 2-4 cm reveals per kind, so verbatim geometry would put the
# owner's daylight gap straight back.
EXT = {0.92: 0.036, 0.94: 0.026, 1.06: 0.016}
TOP_EXT = 0.026
LEAF_MATS = {'house_big02_multi2': TEX['house_big02_multi2'],
             'door_brass_proc':    TEX['door_brass_proc']}

def leaf_source(sp):
    """A representative door of this span, as (door_id, manifest_row)."""
    for did, d in sorted(DOORS.items(), key=lambda kv: int(kv[0].split('_')[1])):
        b = d['box']
        if round(max(b[1] - b[0], b[5] - b[4]), 2) == sp:
            return did, d
    raise SystemExit(f'no door of span {sp}')

spans = sorted({round(max(d['box'][1]-d['box'][0], d['box'][5]-d['box'][4]), 2) for d in DOORS.values()})
for sp in spans:
    did, d = leaf_source(sp)
    b = d['box']
    along_x = (b[1] - b[0]) > (b[5] - b[4])
    hinge_u = d['axis']['x'] if along_x else d['axis']['z']
    u_lo, u_hi = (b[0], b[1]) if along_x else (b[4], b[5])
    w_c = (b[4] + b[5]) / 2 if along_x else (b[0] + b[1]) / 2
    y0b, y1b = b[2], b[3]
    h = y1b - y0b
    sgn = 1.0 if abs(u_lo - hinge_u) < abs(u_hi - hinge_u) else -1.0
    e = EXT[sp]
    su = (sp + 2 * e) / sp          # stretch across, about the hinge
    sv = (h + TOP_EXT) / h

    def to_leaf(px, py, pz):
        u = ((px if along_x else pz) - hinge_u) * sgn
        w = (pz if along_x else px) - w_c
        return (u * su - e, (py - y0b) * sv, w)
    def n_leaf(nx, ny, nz):
        return ((nx if along_x else nz) * sgn, ny, (nz if along_x else nx))
    # determinant of the linear part: sign permutation, so +-1
    det = sgn * (1.0 if along_x else -1.0)

    # b0356 Z-FIGHTING: the brass latch strip runs from the latch edge INTO the
    # leaf, so its outer face lands on exactly the same plane as the wood slab's
    # edge -- two coplanar surfaces, which the depth buffer resolves as the
    # banding the owner saw on the handle side. Same story where the kick plates
    # sit flat on the moulding. Rather than re-model the designer's hardware,
    # lift every brass vertex 0.6 mm along its own normal: nothing is coplanar
    # any more, and 0.6 mm is invisible on a door handle.
    HW_LIFT = 0.0006

    lv = Lod(1.0)
    nfaces = 0
    for src, matkey in ((did, 'house_big02_multi2'), (did + '_hw', 'door_brass_proc')):
        lift = HW_LIFT if src.endswith('_hw') else 0.0
        m = meshes.get(src)
        if m is None:
            continue
        tex, mat = LEAF_MATS[matkey]
        pos, nrm, uvs = m['pos'], m['norm'], m['uv']
        for t in range(len(pos) // 9):
            corners = []
            for c in range(3):
                i = t * 3 + c
                # carry the designer's UVs, V-FLIPPED like every other surface in
                # this converter (three.js v is bottom-up, p3d v is top-down).
                # Zeroing them would leave the walnut texture unmapped -- a flat
                # smear instead of grain.
                q = to_leaf(pos[3*i], pos[3*i+1], pos[3*i+2])
                nn = n_leaf(nrm[3*i], nrm[3*i+1], nrm[3*i+2])
                if lift > 0.0:
                    q = (q[0] + nn[0] * lift, q[1] + nn[1] * lift, q[2] + nn[2] * lift)
                corners.append((q, nn, (uvs[2*i], 1.0 - uvs[2*i+1])))
            if det < 0:
                corners.reverse()          # mirrored map -> restore outward winding
            # DOUBLE-SIDED: a swinging leaf is seen from both sides, and a
            # single-winding leaf backface-culls to a black silhouette (b0339).
            lv.face(corners, tex=tex, mat=mat)
            inv = [(p, (-n[0], -n[1], -n[2]), uv) for p, n, uv in reversed(corners)]
            lv.face(inv, tex=tex, mat=mat)
            nfaces += 2

    lg = Lod(1e13); lg.comp_key = 1
    csel = (set(), set())
    add_box(lg, (-e, 0.0, -0.055), (sp + e, h * sv, 0.055), sel=csel)
    lg.selections = [('Component01', csel[0], csel[1])]
    lg_f = lg.finish(mass_total=90.0)
    view_f = copy.deepcopy(lg_f); view_f['res'] = 6e15
    view_f['taggs'] = [t for t in view_f['taggs'] if t['name'] != b'#Mass#']
    fire_lf = copy.deepcopy(view_f); fire_lf['res'] = 7e15
    p_out = f'{HERE}/lux_leaf_{int(sp*100)}_r11.p3d'
    nby = mlod_rw.write(p_out, 257, [lv.finish(), lg_f, view_f, fire_lf])
    v2, l3 = mlod_rw.parse(p_out); mlod_rw.write(p_out + '.rt', v2, l3)
    assert filecmp.cmp(p_out, p_out + '.rt', shallow=False); os.remove(p_out + '.rt')
    print(f'lux_leaf_{int(sp*100)}_r11.p3d: from {did} span={sp} faces={nfaces} bytes={nby}')
