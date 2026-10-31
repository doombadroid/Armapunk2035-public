#!/usr/bin/env python3
"""f770_dump.json -> six MLOD p3ds (one machine, split into parts) + custom_p3ds/fab_parts_data.sqf
                    + the two HMI screen PAAs at the mission root.

    ap_printer_f770_body_r1.p3d            everything static; the ONLY part with collision
    ap_printer_f770_bridge_r1.p3d          moves along X (left/right)         group f770_bridge
    ap_printer_f770_head_r1.p3d            rides the bridge, moves along Z    group f770_head
    ap_printer_f770_platform_r1.p3d        moves down (-Y) as layers stack    group f770_platform
    ap_printer_f770_screen_ready_r1.p3d    HMI quad, shown when idle
    ap_printer_f770_screen_printing_r1.p3d HMI quad, shown while printing

WHY PARTS. Mission-embedded p3ds have no config, so no model.cfg animation: motion is separate
objects moved by script, the way the Resource Extractor's arm and bit are. The split follows the
harness's `group` field (the three.js parent), never a name prefix.

ORIGINS. Every part is centred on ITS OWN bbox (simple objects are autocentred by the engine, so
this makes the engine's centre and ours agree), and the data file records where each part's centre
stands relative to the BODY's centre as an attachTo offset [right, forward, up] = design [dx, dz, dy].
Nothing in the mission is typed by hand: fn_fabModel reads the offsets from the generated file, and
fn_fabAnim reads the print-cycle constants (PASS/XT/ZT/NPASS/layer) that this script lifts out of
f770.js with an asserted regex, so the in-game motion and the design page's poseF770 share a source.

The dump is the CONSTRUCTION pose (poseF770 not applied): bridge at the centre of its X travel, head
at the centre of its Z travel, platform at layer 0. fn_fabAnim moves parts by +-XT / +-ZT / -layer*mm
FROM these rest offsets.

MATERIALS come from the dump. A material with a `map` is a real texture: 'textures/a3/...png' is the
vanilla .paa at that path (verify_f770.py checks each against textures_png/INDEX.txt),
'textures/ap/...png' is a mission-root .paa this script builds from the handoff PNG. Everything else
is a procedural colour from the dumped hex (emissive LEDs use their emissive hex, as the desktop
printers did). rvmats by material CLASS, per the handoff: shell/dark/plinth/trim -> metal_plate;
rails/liner/tray/brass/heater -> metalclean1; screens + LEDs -> the printers' mild emissive
ap_printer_screen.rvmat; rubber/belt/cable -> none. UVs are scaled by the material's three.js
`repeat`, so a 2x2 tiled shell tiles 2x2 in-game too.

LODs per part: visual 1.0 (every mesh) + coarse 50.0 (one box per part, its dominant texture). The
BODY also carries Geometry (1e13) / View (6e15) / Fire (7e15): ONE convex box = the body's own bbox,
mass 900 (LESSONS.md: every component one convex box; the handoff's three boxes differ from one by
a 3 cm plinth inset nobody can see or feel). Spec R1: collision ON for the body, owner may flip.
"""
import collections
import copy
import filecmp
import json
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, '/home/timb/blender_work')
sys.path.insert(0, os.path.abspath(os.path.join(HERE, '..', '..', 'tools')))
import mlod_rw                                                    # noqa: E402
import make_paa                                                   # noqa: E402
from PIL import Image                                             # noqa: E402

MISSION = os.path.abspath(os.path.join(HERE, '..', '..', 'mission', 'Armapunk2035.Malden'))
HANDOFF_TEX = os.path.join(HERE, 'f770_textures', 'ap')
REV = 'r4'
# MIRROR. three.js is right-handed, Arma's model space is left-handed: identical coordinates render as a
# mirror image (r1 in game: HMI on the wrong side, READY/PRINTING reading backwards). A mirror across Z
# (not X: that one, r2, stood 180 degrees from the placement preview) is the same handedness conversion
# rotated half a turn. Z is negated on the way in, the winding reversed once to keep faces outward, and
# the attach offsets follow.
MIRROR_Z = True
BASE = 'ap_printer_f770'
MASS = 900.0
PARTS = [('bridge', 'f770_bridge'), ('head', 'f770_head'), ('platform', 'f770_platform'),
         ('screen_ready', 'f770_screen_ready'), ('screen_printing', 'f770_screen_printing')]

# metal_plate.rvmat does NOT exist in the game (texture audit 2026-09-03: no such file in any PBO); the faces
# that referenced it rendered with a missing material -- the "rusty" shell. metalclean1.rvmat is the one that
# exists (Super shader, its own _nohq/_smdi), so every metal class uses it.
METAL_PLATE = b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'
METALCLEAN1 = b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'
SCREEN_RVMAT = b'mpmissions\\__cur_mp.Malden\\ap_printer_screen.rvmat'
RVMAT = {
    'metal_panels_white_co': METAL_PLATE, 'metal_servicehangar_black_co': METAL_PLATE,
    'metalcoloureddark_co': METAL_PLATE, 'trim_charcoal_proc': METAL_PLATE,
    'metal_seams_01_co': METALCLEAN1, 'metal_gray_clean_co': METALCLEAN1, 'metalclean1_co': METALCLEAN1,
    'brass_proc': METALCLEAN1, 'heater_proc': METALCLEAN1,
    'ap_f770_screen_ready_co': SCREEN_RVMAT, 'ap_f770_screen_printing_co': SCREEN_RVMAT,
    'led_proc': SCREEN_RVMAT, 'led_amber_proc': SCREEN_RVMAT,
    'rubber_proc': b'', 'belt_proc': b'', 'cable_proc': b'',
}
EMISSIVE = {'led_proc', 'led_amber_proc'}
# TEXTURE SUBSTITUTIONS (r4). The design tints every texture by a material colour Arma cannot apply, so
# three of its picks show their NATIVE look in game: metal_servicehangar_black is rusted corrugated steel,
# metalcoloureddark is peeling rust, metal_seams_01 is an atlas (circles, a black block, plates) that
# world-scaled UVs turn to garbage. The owner: "it's rusted". Clean, neutral vanilla metals instead --
# chosen by luminance/chroma scan of textures_png plus eyeballing the PNGs (2026-09-03).
TEX_OVERRIDE = {
    'metal_servicehangar_black_co': b'a3\\structures_f_exp\\data\\metal\\metal_plate_04_co.paa',   # cap ring, top, trim, bay doors, head body
    'metalcoloureddark_co':         b'a3\\structures_f_exp\\data\\metal\\metal_plate_04_co.paa',   # plinth
    'metal_seams_01_co':            b'a3\\structures_f\\data\\metal\\metalclean1_co.paa',          # chamber liner
}
COARSE_TEX = {'body': 'metal_panels_white_co', 'bridge': 'metal_gray_clean_co', 'head': 'trim_charcoal_proc',
              'platform': 'metalclean1_co', 'screen_ready': 'ap_f770_screen_ready_co',
              'screen_printing': 'ap_f770_screen_printing_co'}


def f32(x):
    return struct.unpack('<f', struct.pack('<f', x))[0]


class Lod:
    """Local copy (build_gunsmith.py's, with selections + #Mass#): importing build_lux rebuilds the
    tower as a side effect, and a build script that regenerates unrelated models is a build script
    that will one day overwrite something during an unrelated edit."""

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


def tex_for(name, m):
    """(texture, rvmat) for one dumped material: a3 map -> vanilla .paa; ap map -> mission-root .paa;
    otherwise the dumped colour (emissive hex for the LEDs) as a procedural."""
    mp = m.get('map')
    if name in TEX_OVERRIDE:
        tex = TEX_OVERRIDE[name]
    elif mp and mp.startswith('textures/a3/'):
        tex = mp[len('textures/'):].replace('/', '\\').replace('.png', '.paa').encode()
    elif mp and mp.startswith('textures/ap/'):
        tex = ('mpmissions\\__cur_mp.Malden\\' + os.path.basename(mp).replace('.png', '.paa')).encode()
    else:
        h = m['emissive'] if name in EMISSIVE else m['color']
        r, g, b = (int(h[1:3], 16) / 255.0, int(h[3:5], 16) / 255.0, int(h[5:7], 16) / 255.0)
        tex = f'#(argb,8,8,3)color({r:.3f},{g:.3f},{b:.3f},{m["opacity"]:.2f},co)'.encode()
    assert name in RVMAT, f'material {name!r} has no rvmat class here -- the design source added one'
    return tex, RVMAT[name]


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


def emit_mesh(lod, m, ctr, tex=b'', mat=b'', repeat=(1, 1)):
    rx, ry = repeat
    sz = -1.0 if MIRROR_Z else 1.0
    for corners in mesh_tris(m):
        cs = [((p[0] - ctr[0], p[1] - ctr[1], (p[2] - ctr[2]) * sz), (n[0], n[1], n[2] * sz), (u * rx, 1.0 - v * ry))
              for p, n, (u, v) in corners]
        if MIRROR_Z:
            cs.reverse()   # a mirror flips winding; reverse once so lod.face's own reversal lands outward
        lod.face(cs, tex=tex, mat=mat)


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


def bounds(meshes):
    xs, ys, zs = [], [], []
    for m in meshes:
        p = m['pos']
        xs += p[0::3]; ys += p[1::3]; zs += p[2::3]
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def anim_constants():
    """[PASS s, XT m, ZT m, NPASS, LAYER m, NLAYERS] read out of poseF770 in f770.js."""
    src = open(os.path.join(HERE, 'f770.js'), encoding='utf-8').read()
    m = re.findall(r'const PASS = ([\d.]+), XT = ([\d.]+), ZT = ([\d.]+), NPASS = (\d+);', src)
    assert len(m) == 1, f'PASS/XT/ZT/NPASS line matched {len(m)}x in f770.js, want 1'
    lay = re.findall(r'plat\.position\.y = -\(layer % (\d+)\) \* ([\d.]+);', src)
    assert len(lay) == 1, f'platform layer line matched {len(lay)}x in f770.js, want 1'
    return [float(m[0][0]), float(m[0][1]), float(m[0][2]), int(m[0][3]), float(lay[0][1]), int(lay[0][0])]


def build_part(part, meshes, lookup, mats, geometry=False):
    lo, hi = bounds(meshes)
    ctr = tuple((lo[i] + hi[i]) / 2 for i in range(3))
    mn = tuple(lo[i] - ctr[i] for i in range(3))
    mx = tuple(hi[i] - ctr[i] for i in range(3))
    if MIRROR_Z:   # the box bounds mirror too (symmetric about the part centre, so only the sign flips)
        mn, mx = (mn[0], mn[1], -mx[2]), (mx[0], mx[1], -mn[2])
    vis = Lod(1.0)
    for m in meshes:
        tex, mat = lookup[m['mat']]
        emit_mesh(vis, m, ctr, tex=tex, mat=mat, repeat=tuple(mats[m['mat']].get('repeat') or (1, 1)))
    coarse = Lod(50.0)
    tex, mat = lookup[COARSE_TEX[part]]
    add_box(coarse, mn, mx, tex=tex, mat=mat)
    lods = [vis.finish(), coarse.finish()]
    if geometry:
        geo = Lod(1e13)
        sel = (set(), set())
        geo.comp_key = 1
        add_box(geo, mn, mx, sel=sel)
        geo.selections = [('Component01', sel[0], sel[1])]
        geo_f = geo.finish(mass_total=MASS)
        view_f = copy.deepcopy(geo_f); view_f['res'] = 6e15
        view_f['taggs'] = [t for t in view_f['taggs'] if t['name'] != b'#Mass#']
        fire_f = copy.deepcopy(geo_f); fire_f['res'] = 7e15
        fire_f['taggs'] = [t for t in fire_f['taggs'] if t['name'] != b'#Mass#']
        lods += [geo_f, view_f, fire_f]
    name = f'{BASE}_{part}_{REV}.p3d'
    out = os.path.join(HERE, name)
    n = mlod_rw.write(out, 257, lods)
    ver2, l2 = mlod_rw.parse(out)
    mlod_rw.write(out + '.rt', ver2, l2)
    assert filecmp.cmp(out, out + '.rt', shallow=False), f'{name}: round-trip mismatch'
    os.remove(out + '.rt')
    print(f'wrote {name} bytes={n} visual faces={len(lods[0]["faces"])} '
          f'size {hi[0]-lo[0]:.3f} x {hi[1]-lo[1]:.3f} x {hi[2]-lo[2]:.3f} m')
    return ctr, (hi[1] - lo[1]) / 2


def build_screens():
    """Handoff PNGs (512x358) -> 512x256 DXT5 .paa at the mission root: power-of-two so the mip
    chain is whole. The quad's UVs span the whole texture, so the aspect change is undone on the face."""
    for k in ('ready', 'printing'):
        png = os.path.join(HANDOFF_TEX, f'ap_f770_screen_{k}_co.png')
        tmp = os.path.join(HERE, f'_f770_screen_{k}_512x256.png')
        Image.open(png).convert('RGBA').resize((512, 256), Image.LANCZOS).save(tmp)
        paa = os.path.join(MISSION, f'ap_f770_screen_{k}_co.paa')
        make_paa.build_paa_dxt5(tmp, paa)
        ok, msg = make_paa.verify_paa(paa)
        assert ok, f'{paa}: {msg}'
        os.remove(tmp)
        print(f'wrote {os.path.basename(paa)}: {msg}')


def main():
    data = json.load(open(os.path.join(HERE, 'f770_dump.json')))
    meshes, mats = data['meshes'], data['mats']
    lookup = {n: tex_for(n, m) for n, m in mats.items()}
    groups = collections.defaultdict(list)
    for m in meshes:
        groups[m['group']].append(m)
    expected = {'body'} | {g for _, g in PARTS}
    assert set(groups) == expected, f'groups {sorted(groups)} != {sorted(expected)} -- f770.js changed its group names'

    body_ctr, half = build_part('body', groups['body'], lookup, mats, geometry=True)
    rows = []
    for suffix, g in PARTS:
        ctr, _ = build_part(suffix, groups[g], lookup, mats)
        d = [ctr[i] - body_ctr[i] for i in range(3)]
        rows.append((suffix, [d[0], -d[2] if MIRROR_Z else d[2], d[1]]))   # design [x, y(up), z(fwd)] -> attachTo [right, forward, up], mirrored with the mesh
    build_screens()
    anim = anim_constants()

    out = os.path.join(MISSION, 'custom_p3ds', 'fab_parts_data.sqf')
    parts = ', '.join(f'["{s}", [{o[0]:.4f}, {o[1]:.4f}, {o[2]:.4f}]]' for s, o in rows)
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        f.write('// GENERATED by scratchpad/skyscraper/build_f770.py from f770_dump.json (f770.js) -- do not hand-edit\n')
        f.write('// one row per multi-part fabricator model:\n')
        f.write('//   [basename, rev, lift (body half-height, m),\n')
        f.write('//    [[partSuffix, [right, forward, up]] ...]  attachTo offset of the part centre from the body centre,\n')
        f.write('//    [PASS s, XT m, ZT m, NPASS, LAYER m, NLAYERS]]  the print cycle, read out of poseF770 in f770.js\n')
        f.write('[\n')
        f.write(f'    ["{BASE}", "{REV}", {half:.4f}, [{parts}], '
                f'[{anim[0]}, {anim[1]}, {anim[2]}, {anim[3]}, {anim[4]}, {anim[5]}]]\n')
        f.write(']\n')
    print(f'wrote custom_p3ds/fab_parts_data.sqf  lift={half:.4f}  parts={[s for s, _ in rows]}  anim={anim}')


if __name__ == '__main__':
    main()
