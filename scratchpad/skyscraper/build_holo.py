#!/usr/bin/env python3
"""ap_holo_tower_r1.p3d -- the rotating hologram of the tower for the lobby kiosk.

A stylised massing of Skyscraper30, not a copy of it: 30 floor plates, four
corner mullions and a crown, in the tower's own holo cyan. A decimated copy of
the real 132k-face model would be pointless at 1.75 m tall and would cost every
client the whole mesh again; this is ~450 faces.

MATERIAL is the existing holo_cyan_proc from build_lux's table -- alpha 0.55
cyan over the mission's neon_cyan.rvmat, the same combination the tower's own
hologram layer used before the designer removed it. Nothing new to ship.

ORIGIN: centred on its own bbox, for the reason build_fixtures.py documents --
simple objects are autocentred by the engine and authored origins are discarded,
so centring here means a plain setPosASL lands it exactly where asked.

VISUAL LOD ONLY. No geometry, no fire geometry, no roadway: it is a projection
floating in the air and must never be something a player can collide with,
shoot, or stand on.

Run:  python3 scratchpad/skyscraper/build_holo.py
"""
import os
import sys

sys.path.insert(0, '/home/timb/blender_work')
import mlod_rw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_lux import Lod, TEX      # noqa: E402  (reuses the tower's writer + materials)

OUT = f'{HERE}/ap_holo_tower_r1.p3d'
TEXTURE, RVMAT = TEX['holo_cyan_proc']

H       = 1.75      # overall height of the projection
W       = 0.26      # half-width of the footprint
FLOORS  = 30
PLATE_T = 0.006     # floor plate thickness
MULLION = 0.014     # corner post half-section
CROWN_H = 0.055


def box(lod, mn, mx):
    """Textured axis-aligned box. add_box in build_lux emits UNtextured faces --
    it exists for geometry LODs -- so the visual shell needs its own emitter."""
    x0, y0, z0 = mn
    x1, y1, z1 = mx
    P = {(i, j, k): (x1 if i else x0, y1 if j else y0, z1 if k else z0)
         for i in (0, 1) for j in (0, 1) for k in (0, 1)}
    quads = [
        ([(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)], (-1, 0, 0)),
        ([(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)], (1, 0, 0)),
        ([(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)], (0, -1, 0)),
        ([(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)], (0, 1, 0)),
        ([(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)], (0, 0, -1)),
        ([(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)], (0, 0, 1)),
    ]
    for keys, n in quads:
        corners = [(P[k], n, (0.0, 0.0)) for k in keys]
        lod.face(corners, tex=TEXTURE, mat=RVMAT)
        # Double-sided, deliberately. A hologram is looked at from every angle
        # while it turns, and a single-winding face backface-culls to nothing
        # from behind -- the same trap that made the curtain wall see-through.
        inv = [(p, (-n[0], -n[1], -n[2]), uv) for p, n, uv in reversed(corners)]
        lod.face(inv, tex=TEXTURE, mat=RVMAT)


def build():
    vis = Lod(1.0)
    vis.comp_key = 0

    body_h = H - CROWN_H
    # floor plates: the tower's silhouette is legible from the stack of floors,
    # so the plates carry the read and the mullions just tie them together.
    for i in range(FLOORS):
        y = body_h * (i + 1) / FLOORS
        inset = 0.012 if i else 0.0            # ground plate reads as the plinth
        box(vis, (-W + inset, y, -W + inset), (W - inset, y + PLATE_T, W - inset))

    # four corner mullions
    for sx in (-1, 1):
        for sz in (-1, 1):
            cx, cz = sx * (W - MULLION), sz * (W - MULLION)
            box(vis, (cx - MULLION, 0.0, cz - MULLION),
                     (cx + MULLION, body_h, cz + MULLION))

    # crown
    box(vis, (-W * 0.42, body_h, -W * 0.42), (W * 0.42, body_h + CROWN_H, W * 0.42))

    # centre on the bbox so the engine's autocentre agrees with ours
    ys = [p[1] for p in vis.pts]
    dy = (min(ys) + max(ys)) / 2.0
    vis.pts = [(p[0], p[1] - dy, p[2]) for p in vis.pts]

    mlod_rw.write(OUT, 257, [vis.finish()])
    return vis


if __name__ == '__main__':
    v = build()
    print(f'wrote {OUT} faces={len(v.faces)} pts={len(v.pts)}')
