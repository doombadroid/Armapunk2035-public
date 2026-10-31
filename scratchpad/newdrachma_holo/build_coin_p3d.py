#!/usr/bin/env python3
"""newdrachma_holo.p3d — built to the letter of the design handoff
(Holographic Shop Icon Design.zip README + the module script in
newdrachma-holo.html, which the handoff names as the authoritative spec).

No Blender, no Object Builder: the geometry is all cylinders, annuli and
extruded prisms, so it is generated straight into MLOD via the byte-exact
toolkit in ~/blender_work (Blender round-trips split every shared vertex —
p3dmemories.md). Winding convention measured off EvidenceSign.p3d:
cross(v1-v0, v2-v0) points along the stored normal, 60/60 faces.

Coordinate frame: y-up, coin faces +/-Z, pivot at the LOWEST point (y=0)
per the spec. One visual LOD, NO geometry LOD — a hologram has no
collision. Materials/textures are RELATIVE refs resolved beside the p3d in
the mission root (fallback plan if that fails live: rebuild with
\\armapunk_light\\ absolute refs and ship in the addon PBO).
"""
import math
import os
import sys

sys.path.insert(0, os.path.expanduser('~/blender_work'))
import mlod_rw  # noqa: E402

OUT = os.path.expanduser('~/Armapunk2035-atmo/mission/Armapunk2035.Malden/newdrachma_holo.p3d')

# spec: group scale 1.052 on base coords = 1.0 m diameter. The coin hangs
# 15 m over shop roofs (owner), so scale uniformly (README allows) to stay
# readable from the street.
SCALE = 1.052 * 2.5
ARC_N = 48          # bowl arc segments
CIRC_N = 64         # full-circle segments

# material -> (rvmat, texture, scanline repeats per metre of base coords)
# measured live (b0287): a mission-loaded p3d KEEPS its mesh but silently
# DROPS relative rvmat refs (coin rendered plain white) — materials must
# come from an addon PBO. Textures ride along in the same PBO.
# no leading backslash: EvidenceSign's working refs are 'a3\\...' bare —
# a leading slash is what silently kills resolution for pbo-prefixed paths
AP = 'armapunk_light\\'
MATS = {
    'cyan':    (AP + 'holo_cyan.rvmat',    AP + 'holo_scan_a.paa', 34),
    'magenta': (AP + 'holo_magenta.rvmat', AP + 'holo_scan_b.paa', 21),
    'trace':   (AP + 'holo_trace.rvmat',   AP + 'holo_scan_a.paa', 34),
    'panel':   (AP + 'holo_panel.rvmat',   AP + 'holo_scan_p.paa', 27),
    'void':    (AP + 'holo_void.rvmat',    AP + 'holo_scan_a.paa', 34),
}

pts, norms, faces = [], [], []
_pt_ix, _nm_ix = {}, {}


def P(x, y, z):
    k = (round(x, 6), round(y, 6), round(z, 6))
    if k not in _pt_ix:
        _pt_ix[k] = len(pts)
        pts.append((k[0], k[1], k[2], 0))
    return _pt_ix[k]


def N(x, y, z):
    m = math.sqrt(x * x + y * y + z * z) or 1.0
    k = (round(x / m, 5), round(y / m, 5), round(z / m, 5))
    if k not in _nm_ix:
        _nm_ix[k] = len(norms)
        norms.append(k)
    return _nm_ix[k]


def face(verts, mat):
    """verts: list of 3-4 (xyz, uv) in CCW-from-front order (spec frame).
    Normal computed from winding (matches the measured convention)."""
    rv, tex, _ = MATS[mat]
    p = [v[0] for v in verts]
    ux = [p[1][i] - p[0][i] for i in range(3)]
    vx = [p[2][i] - p[0][i] for i in range(3)]
    c = (ux[1] * vx[2] - ux[2] * vx[1], ux[2] * vx[0] - ux[0] * vx[2], ux[0] * vx[1] - ux[1] * vx[0])
    ni = N(*c)
    vs = []
    for (xyz, uv) in verts:
        vs.append((P(*xyz), ni, uv[0], uv[1]))
    while len(vs) < 4:
        vs.append(vs[-1])
    faces.append(dict(nv=len(verts), vs=vs, flags=0, tex=tex.encode(), mat=rv.encode()))


def uv(mat, x, y):
    # scanlines are horizontal across the face: v follows y. u follows x at
    # a gentle tile so the stripe texture doesn't smear.
    rep = MATS[mat][2]
    return (x * 4.0, y * rep)


def xf(x, y, z):
    """base spec coords -> final model coords (scale + bottom pivot)."""
    return (x * SCALE, y * SCALE + 0.475 * SCALE, z * SCALE)


def prism(contour_outer, contour_inner, h, mat):
    """Closed extrusion between z=-h/2..+h/2 of an annular region.
    Contours CCW in XY, same point count, index-paired. inner=None => solid
    (triangle-fan caps around the centroid)."""
    zf, zb = h / 2.0, -h / 2.0
    o = contour_outer
    n = len(o)
    if contour_inner is None:
        cx = sum(p[0] for p in o) / n
        cy = sum(p[1] for p in o) / n
        for i in range(n):
            a, b = o[i], o[(i + 1) % n]
            face([(xf(cx, cy, zf), uv(mat, cx, cy)), (xf(*a, zf), uv(mat, *a)), (xf(*b, zf), uv(mat, *b))], mat)
            face([(xf(cx, cy, zb), uv(mat, cx, cy)), (xf(*b, zb), uv(mat, *b)), (xf(*a, zb), uv(mat, *a))], mat)
    else:
        q = contour_inner
        assert len(q) == n
        for i in range(n):
            a, b = o[i], o[(i + 1) % n]
            c, d = q[i], q[(i + 1) % n]
            face([(xf(*a, zf), uv(mat, *a)), (xf(*b, zf), uv(mat, *b)),
                  (xf(*d, zf), uv(mat, *d)), (xf(*c, zf), uv(mat, *c))], mat)
            face([(xf(*a, zb), uv(mat, *a)), (xf(*c, zb), uv(mat, *c)),
                  (xf(*d, zb), uv(mat, *d)), (xf(*b, zb), uv(mat, *b))], mat)
        for i in range(n):   # inner wall (normal toward the hole)
            c, d = q[i], q[(i + 1) % n]
            face([(xf(*c, zb), uv(mat, *c)), (xf(*c, zf), uv(mat, *c)),
                  (xf(*d, zf), uv(mat, *d)), (xf(*d, zb), uv(mat, *d))], mat)
    for i in range(n):       # outer wall
        a, b = o[i], o[(i + 1) % n]
        face([(xf(*a, zb), uv(mat, *a)), (xf(*b, zb), uv(mat, *b)),
              (xf(*b, zf), uv(mat, *b)), (xf(*a, zf), uv(mat, *a))], mat)


def circle(r, n=CIRC_N, cx=0.0, cy=0.0):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


# ---- parts, dimensions verbatim from the handoff module script ----
# disc: cylinder r 0.40, thickness 0.03 (spec 96 seg; 64 is visually identical at 2.5 m)
prism(circle(0.40), None, 0.03, 'panel')
# ring_outer: annulus 0.432 -> 0.475, extruded 0.050
prism(circle(0.475), circle(0.432), 0.050, 'magenta')
# ring_trace: annulus 0.345 -> 0.353, extruded 0.044
prism(circle(0.353), circle(0.345), 0.044, 'trace')


def d_contour(stem_x, half_h, r, cx=-0.06):
    """The Đ letterform path: stem left edge, top, right bowl arc, bottom.
    Both outer and hole follow this shape with their own dims (spec)."""
    c = [(stem_x, -half_h), (stem_x, half_h), (cx, half_h)]
    for i in range(1, ARC_N):
        th = math.pi / 2 - math.pi * i / ARC_N     # +90deg -> -90deg, clockwise
        c.append((cx + r * math.cos(th), r * math.sin(th)))
    c.append((cx, -half_h))
    return c


# glyph_D: outer stem x -0.157 w 0.058, cap +/-0.267, bowl r 0.267/0.209.
# hole contour runs CCW-in-shape-terms too; prism() pairs them index-wise —
# both lists run the same direction so the bridge quads don't twist.
outer_d = d_contour(-0.157, 0.267, 0.267)
inner_d = d_contour(-0.099, 0.209, 0.209)
prism(outer_d, inner_d, 0.056, 'cyan')


def box(cx, cy, ln, w, h, rot, mat):
    cs, sn = math.cos(rot), math.sin(rot)
    pts4 = []
    for dx, dy in [(-ln / 2, -w / 2), (ln / 2, -w / 2), (ln / 2, w / 2), (-ln / 2, w / 2)]:
        pts4.append((cx + dx * cs - dy * sn, cy + dx * sn + dy * cs))
    prism(pts4, None, h, mat)


# strike-through: dark gap bars behind, cyan slashes in front (z-layering is
# carried by the differing extrusion depths, exactly like the three.js model)
box(-0.09, -0.021, 0.57, 0.062, 0.064, 0.342, 'void')
box(-0.09, -0.108, 0.57, 0.062, 0.064, 0.342, 'void')
box(-0.09, -0.021, 0.55, 0.036, 0.072, 0.342, 'cyan')
box(-0.09, -0.108, 0.55, 0.036, 0.072, 0.342, 'cyan')

lod = dict(hs=28, lv=256, flags=0x0, pts=pts, norms=norms, faces=faces,
           taggs=[dict(b=b'\x01', name=b'#EndOfFile#', data=b'')], res=1.0)
n = mlod_rw.write(OUT, 257, [lod])
print(f'{OUT}: {n} bytes, {len(pts)} pts, {len(norms)} norms, {len(faces)} faces')

ver, lods = mlod_rw.parse(OUT)   # round-trip sanity
assert ver == 257 and len(lods) == 1 and len(lods[0]['faces']) == len(faces)
ys = [p[1] for p in pts]
zs = [p[2] for p in pts]
xs = [p[0] for p in pts]
print(f'bounds x [{min(xs):.3f},{max(xs):.3f}] y [{min(ys):.3f},{max(ys):.3f}] z [{min(zs):.3f},{max(zs):.3f}]')
assert abs(min(ys)) < 1e-4, 'pivot must sit at the lowest point'
print('round-trip OK')
