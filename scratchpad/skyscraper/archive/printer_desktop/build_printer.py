#!/usr/bin/env python3
"""printer_dump.json -> ap_printer_i3_r1.p3d / ap_printer_corexy_r1.p3d

Two desktop 3D printers, from printer.js via harness_printer.mjs. Per ARMA3_HANDOFF_PRINTER.md,
with one owner override that removes most of that document's work:

    NO COLLISION (owner 2026-08-22). The handoff specifies Geometry/Fire/View convex components
    and masses 14/32. Skipped entirely -- these are 0.5 m desk props inside a house, and a player
    who can snag on one is a player stuck in his own printer room. So this builds VISUAL LODs only:
    no Geometry, no Fire, no View, no Mass, no Roadway, no Memory, no model.cfg.

That also retires a conflict in the handoff worth recording. Its geometry section is headed
"convex components only, 1:1 with source boxes" but the dimensions under it are eyeballed and do
not match the source: it calls for a 0.50x0.09x0.50 base slab where the model's base is two 0.38 m
plates spanning 0.413 m overall, and a 0.30x0.30 bed where i3_heatbed measures 0.250x0.210. Had
collision shipped, the boxes would have been derived from the measured mesh bounds and the prose
treated as illustration -- the same rule the winding audit exists for: measure the geometry, do not
read the description.

LODs
  1.0   visual, every mesh verbatim (tri soup, V-flip, per-material texture)
  50.0  coarse, primary masses only as single boxes derived from measured group bounds
        (handoff LOD2 intent; the fixtures' toilet does the same thing at the same resolution)

ORIGIN: centred on each printer's own bbox, following build_fixtures.py -- simple objects are
autocentred by the engine and authored origins are discarded, so centring here makes the engine's
centre and ours agree and a plain setPosASL lands the model exactly where it was asked for.

MATERIALS are not written down here. printer.js declares every colour on a named
MeshStandardMaterial; the harness dumps those, and the palette below is DERIVED from that dump at
build time. A hex typed a second time in this file is a hex that silently disagrees with the
prototype after the next re-drop.
"""
import copy
import filecmp
import json
import os
import struct
import sys

sys.path.insert(0, '/home/timb/blender_work')
import mlod_rw                                                    # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import collections                                                # noqa: E402


def f32(x):
    return struct.unpack('<f', struct.pack('<f', x))[0]


class Lod:
    """Local copy, following build_garage.py rather than importing from build_lux.

    build_lux.py does its work at module scope, so `from build_lux import Lod` REBUILDS the whole
    lux tower and rewrites the door-leaf p3ds as an import side effect. Harmless in that the output
    is deterministic, but a build script that silently regenerates three unrelated models is a
    build script that will one day overwrite something during an unrelated edit.
    """

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

    def finish(self):
        taggs = [dict(b=b'\x01', name=b'#SharpEdges#', data=self.sharp_edges())]
        uv = bytearray(struct.pack('<I', 0))
        for f in self.faces:
            for v in f['vs'][:f['nv']]:
                uv += struct.pack('<ff', v[2], v[3])
        taggs.append(dict(b=b'\x01', name=b'#UVSet#', data=bytes(uv)))
        taggs.append(dict(b=b'\x01', name=b'#EndOfFile#', data=b''))
        return dict(hs=0x1c, lv=0x100, flags=0,
                    pts=[(x, y, z, 0) for x, y, z in self.pts],
                    norms=list(self.norms), faces=self.faces, taggs=taggs, res=self.res)

REV = 'r1'
MISSION = os.path.join(HERE, '..', '..', 'mission', 'Armapunk2035.Malden')

# rvmat per material CLASS, not per material. Everything else renders as its flat procedural colour,
# which at 0.5 m is indistinguishable from a textured surface and costs no assets.
METAL_RVMAT = b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'
GLASS_RVMAT = b'mpmissions\\__cur_mp.Malden\\glass_interior.rvmat'
SCREEN_RVMAT = b'mpmissions\\__cur_mp.Malden\\ap_printer_screen.rvmat'

METALS = {'alu', 'alu_dark', 'steel', 'brass', 'motor_black'}
GLASSY = {'glass_smoke'}
EMISSIVE = {'lcd', 'screen', 'led'}

# Which meshes collapse into which coarse-LOD box, and what that box is painted with. Membership
# by name; the BOX ITSELF is the measured union bbox of its members, never a number from the
# handoff. The material is per-printer because the two do not share a palette -- the i3's spool is
# filament_orange and the CoreXY's is filament_teal, and a shared table silently KeyErrors on the
# second printer (it did).
COARSE = {
    'i3': {
        'base':   ('alu_dark', ('i3_rail_l', 'i3_rail_r', 'i3_plate_front', 'i3_plate_rear',
                                'i3_foot_-1-1', 'i3_foot_-11', 'i3_foot_1-1', 'i3_foot_11')),
        'frame':  ('alu', ('i3_frame_plate',)),
        'bed':    ('pei', ('i3_heatbed', 'i3_pei_sheet')),
        'gantry': ('steel', ('i3_xrod_top', 'i3_xrod_bot', 'i3_xmotor')),
        'spool':  ('filament_orange', ('i3_spool_rim_l', 'i3_spool_rim_r', 'i3_spool_hub',
                                       'i3_spool_filament', 'i3_spool_rod')),
    },
    'corexy': {
        'shell':  ('glass_smoke', ('cx_post_-1-1', 'cx_post_-11', 'cx_post_1-1', 'cx_post_11',
                                   'cx_panel_left', 'cx_panel_right', 'cx_panel_rear',
                                   'cx_panel_top', 'cx_door', 'cx_rail_front_t', 'cx_rail_rear_t',
                                   'cx_rail_left_t', 'cx_rail_right_t')),
        'skirt':  ('plastic_teal', ('cx_skirt_front', 'cx_skirt_rear', 'cx_skirt_left',
                                    'cx_skirt_right', 'cx_deck', 'cx_foot_-1-1', 'cx_foot_-11',
                                    'cx_foot_1-1', 'cx_foot_11')),
        'bed':    ('pei', ('cx_bed_plate', 'cx_bed_pei')),
        'spool':  ('filament_teal', ('cx_spool_rim_l', 'cx_spool_rim_r', 'cx_spool_hub',
                                     'cx_spool_filament', 'cx_spool_rod')),
    },
}


def tex_for(name, m):
    """(texture, rvmat) for one dumped material -- colour read from the design source."""
    r = int(m['color'][1:3], 16) / 255.0
    g = int(m['color'][3:5], 16) / 255.0
    b = int(m['color'][5:7], 16) / 255.0
    a = m['opacity']
    if name in EMISSIVE:
        # Use the EMISSIVE colour as the surface colour: three.js shows an emissive material as its
        # emissive hue, while its base `color` is the near-black the panel would be when off. Taking
        # `color` here would ship every screen dead.
        e = m['emissive']
        r, g, b = (int(e[1:3], 16) / 255.0, int(e[3:5], 16) / 255.0, int(e[5:7], 16) / 255.0)
    tex = f'#(argb,8,8,3)color({r:.3f},{g:.3f},{b:.3f},{a:.2f},co)'.encode()
    if name in GLASSY:
        return tex, GLASS_RVMAT
    if name in EMISSIVE:
        return tex, SCREEN_RVMAT
    if name in METALS:
        return tex, METAL_RVMAT
    return tex, b''


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


def emit_mesh(lod, m, ctr, tex=b'', mat=b'', vflip=True):
    for corners in mesh_tris(m):
        cs = [((p[0] - ctr[0], p[1] - ctr[1], p[2] - ctr[2]), n,
               (u, 1.0 - v) if vflip else (u, v)) for p, n, (u, v) in corners]
        lod.face(cs, tex=tex, mat=mat)


def add_box(lod, mn, mx, tex=b'', mat=b''):
    P = {(i, j, k): (mx[0] if i else mn[0], mx[1] if j else mn[1], mx[2] if k else mn[2])
         for i in (0, 1) for j in (0, 1) for k in (0, 1)}
    quads = [([(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)], (-1, 0, 0)),
             ([(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)], (1, 0, 0)),
             ([(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)], (0, -1, 0)),
             ([(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)], (0, 1, 0)),
             ([(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)], (0, 0, -1)),
             ([(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)], (0, 0, 1))]
    for keys, n in quads:
        lod.face([(P[k], n, (0.5, 0.5)) for k in keys], tex=tex, mat=mat)


def bounds(meshes):
    xs, ys, zs = [], [], []
    for m in meshes:
        p = m['pos']
        xs += p[0::3]; ys += p[1::3]; zs += p[2::3]
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def build(key, out_name):
    data = json.load(open(f'{HERE}/printer_dump.json'))[key]
    meshes, mats = data['meshes'], data['mats']
    lookup = {n: tex_for(n, m) for n, m in mats.items()}

    lo, hi = bounds(meshes)
    ctr = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2)

    vis = Lod(1.0)
    for m in meshes:
        tex, mat = lookup[m['mat']]
        emit_mesh(vis, m, ctr, tex=tex, mat=mat)

    coarse = Lod(50.0)
    by_name = {m['name']: m for m in meshes}
    for group, (gmat, members) in COARSE[key].items():
        missing = [n for n in members if n not in by_name]
        assert not missing, f'{key}/{group}: no such mesh {missing} -- the design source renamed it'
        gl, gh = bounds([by_name[n] for n in members])
        tex, mat = lookup[gmat]
        add_box(coarse,
                (gl[0] - ctr[0], gl[1] - ctr[1], gl[2] - ctr[2]),
                (gh[0] - ctr[0], gh[1] - ctr[1], gh[2] - ctr[2]),
                tex=tex, mat=mat)

    lods = [vis.finish(), coarse.finish()]
    out = os.path.join(HERE, out_name)
    n = mlod_rw.write(out, 257, lods)

    # byte round-trip: parse what we wrote and re-emit it; any difference means the writer and the
    # reader disagree about the file we are about to ship.
    ver2, l2 = mlod_rw.parse(out)
    mlod_rw.write(out + '.rt', ver2, l2)
    assert filecmp.cmp(out, out + '.rt', shallow=False), f'{out}: round-trip mismatch'
    os.remove(out + '.rt')

    print(f'wrote {out_name} bytes={n}')
    print(f'  visual faces={len(lods[0]["faces"])}  coarse faces={len(lods[1]["faces"])} '
          f'({len(COARSE[key])} boxes)')
    print(f'  size {hi[0]-lo[0]:.3f} x {hi[1]-lo[1]:.3f} x {hi[2]-lo[2]:.3f} m   '
          f'halfHeight={(hi[1]-lo[1])/2:.4f}  (floor offset +{(hi[1]-lo[1])/2:.4f})')
    return (hi[1] - lo[1]) / 2


if __name__ == '__main__':
    for key, name in (('i3', f'ap_printer_i3_{REV}.p3d'),
                      ('corexy', f'ap_printer_corexy_{REV}.p3d')):
        build(key, name)
