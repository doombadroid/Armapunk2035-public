#!/usr/bin/env python3
"""
sign_retext_apd.py -- rework the two "APD" signs on the police HQ into "MCSO".

WHAT THESE SIGNS ACTUALLY ARE. The first attempt read them as lettering stuck on a wall and cut
holes in the building. They are a SANDWICH THROUGH the wall:

    inner skin  (faces the room)      wall texture, with LETTER-SHAPED APERTURES through it
    inlay       (between the skins)   the letter itself -- polished inside, lit outside
    outer skin  (faces the street)    wall texture, same apertures
    backing     (side sign only)      one big emissive quad behind the whole assembly

Each aperture also leaves a COUNTER ISLAND: the middle of an A, P or D is a free-floating scrap of
skin, because the aperture is cut to the letter's OUTER contour.

So re-lettering means filling the old A/P/D apertures back to solid wall and putting MCSO in as new
inlays. The new letters stand a hair proud of both skins and carry the emissive material on the face
that looks outdoors and the mirror material on the face that looks into the room -- lit from the
street, polished from inside, which is how the originals read.

Conventions that matter (see tools/sign_retext.py for the full list): faces are wound so the
right-hand normal points INWARD and the stored normal is that same inward vector; TAGGs sized
npoints+nfaces are rebuilt alongside; a point is only dropped when no surviving face uses it.

Usage:  python3 tools/sign_retext_apd.py <in.p3d> <out.p3d>
"""
import collections
import math
import os
import struct
import sys

sys.path.insert(0, "/home/timb/blender_work")
import mlod_rw

import numpy as np
import mapbox_earcut


def tri_rings(outer, holes):
    """Triangulate a polygon WITH HOLES -> (points, [(i, j, k), ...]).

    Hand-rolled hole bridging was fine for four blocky hand-drawn shapes and fell apart on font
    contours, which carry 50-100 points per letter: the bridges self-crossed and the panel came out
    almost solid. earcut takes the rings directly, so there is nothing to bridge.
    """
    rings = [list(outer)] + [list(h) for h in holes]
    pts, ends = [], []
    for r in rings:
        pts.extend(r)
        ends.append(len(pts))
    idx = mapbox_earcut.triangulate_float64(np.array(pts, dtype=np.float64), np.array(ends))
    return pts, [tuple(idx[i:i + 3]) for i in range(0, len(idx), 3)]

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sign_retext_glyphs as glyphs


# ------------------------------------------------------------------ geometry helpers
def ear_clip(poly):
    """Ear clipping that tolerates BRIDGE VERTICES.

    Bridging a hole into an outer ring duplicates two vertices, so a naive containment test sees a
    polygon vertex sitting exactly on the candidate ear and refuses every ear -- the region then
    triangulates into nothing and the wall comes out with a hole in it. Points that coincide with
    the ear's own corners are therefore skipped.
    """
    n = len(poly)
    idx = list(range(n))
    ar2 = lambda a, b, c: (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    tot = sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n))
    ccw = tot > 0
    EPS = 1e-9

    def same(p, q):
        return abs(p[0] - q[0]) < 1e-7 and abs(p[1] - q[1]) < 1e-7

    def strictly_inside(a, b, c, p):
        if same(p, a) or same(p, b) or same(p, c):
            return False
        d1, d2, d3 = ar2(a, b, p), ar2(b, c, p), ar2(c, a, p)
        if ccw:
            return d1 > EPS and d2 > EPS and d3 > EPS
        return d1 < -EPS and d2 < -EPS and d3 < -EPS

    tris, guard = [], 0
    while len(idx) > 3 and guard < 60000:
        guard += 1
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = poly[i0], poly[i1], poly[i2]
            ar = ar2(a, b, c)
            if (ar <= EPS) if ccw else (ar >= -EPS):
                continue
            if any(strictly_inside(a, b, c, poly[j]) for j in idx if j not in (i0, i1, i2)):
                continue
            tris.append((i0, i1, i2))
            idx.pop(k)
            break
        else:
            break
    if len(idx) == 3:
        tris.append(tuple(idx))
    return tris


def signed_area(poly):
    n = len(poly)
    return sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1]
               for i in range(n)) / 2.0


def point_in(poly, p):
    x, y = p
    inside = False
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        if (y0 > y) != (y1 > y):
            if x0 + (y - y0) * (x1 - x0) / (y1 - y0) > x:
                inside = not inside
    return inside


def comps_of(faces, fis):
    """Connected components of a face subset, by shared points."""
    parent = {}

    def find(a):
        parent.setdefault(a, a)
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def uni(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    for fi in fis:
        f = faces[fi]
        ids = [f["vs"][k][0] for k in range(f["nv"])]
        for k in range(1, len(ids)):
            uni(ids[0], ids[k])
    g = collections.defaultdict(list)
    for fi in fis:
        g[find(faces[fi]["vs"][0][0])].append(fi)
    return list(g.values())


def point_in_or_near(poly, p, tol):
    """Inside, or within tol of the boundary. The old aperture REVEAL walls have their corners
    exactly ON the aperture outline, so a strict test left them behind as ghost lettering."""
    if point_in(poly, p):
        return True
    x, y = p
    n = len(poly)
    for i in range(n):
        ax_, ay_ = poly[i]
        bx_, by_ = poly[(i + 1) % n]
        dx, dy = bx_ - ax_, by_ - ay_
        L2 = dx * dx + dy * dy
        t = 0.0 if L2 < 1e-12 else max(0.0, min(1.0, ((x - ax_) * dx + (y - ay_) * dy) / L2))
        if math.hypot(x - (ax_ + t * dx), y - (ay_ + t * dy)) <= tol:
            return True
    return False


def loops_of(faces, pts, fis, ax, ay):
    """Boundary loops of a coplanar face set, projected onto the (ax, ay) axes."""
    edges, ep = collections.Counter(), {}
    for fi in fis:
        f = faces[fi]
        ids = [f["vs"][k][0] for k in range(f["nv"])]
        for k in range(len(ids)):
            p, q = ids[k], ids[(k + 1) % len(ids)]
            kp = (round(pts[p][ax], 4), round(pts[p][ay], 4))
            kq = (round(pts[q][ax], 4), round(pts[q][ay], 4))
            key = tuple(sorted([kp, kq]))
            edges[key] += 1
            ep[key] = (kp, kq)
    adj = collections.defaultdict(list)
    for k, n in edges.items():
        if n != 1:
            continue
        a, b = ep[k]
        adj[a].append(b)
        adj[b].append(a)
    out, seen = [], set()
    for s in adj:
        if s in seen:
            continue
        loop, cur, prev = [s], s, None
        seen.add(s)
        while True:
            nxt = [n for n in adj[cur] if n != prev and (n not in seen or n == s)]
            if not nxt:
                break
            n = nxt[0]
            if n == s or n in seen:
                break
            loop.append(n)
            seen.add(n)
            prev, cur = cur, n
        if len(loop) > 2:
            out.append(loop)
    return out



def bridge_holes(outer, holes):
    """Merge holes into an outer loop with bridge cuts -> one simple polygon.

    Ear clipping cannot see holes, so each hole is spliced into the outer ring by a pair of
    coincident edges. Bridges are tried nearest-first and rejected if they cross any edge, which
    is enough for well-separated letter apertures inside a wall panel.
    """
    def area(p):
        n = len(p)
        return sum(p[i][0] * p[(i + 1) % n][1] - p[(i + 1) % n][0] * p[i][1] for i in range(n)) / 2.0

    def seg_hit(a, b, c, d):
        def o(p, q, r):
            v = (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
            return 0 if abs(v) < 1e-12 else (1 if v > 0 else -1)
        if a in (c, d) or b in (c, d):
            return False
        o1, o2, o3, o4 = o(a, b, c), o(a, b, d), o(c, d, a), o(c, d, b)
        return o1 != o2 and o3 != o4

    poly = list(outer) if area(outer) > 0 else list(reversed(outer))
    hs = [list(h) if area(h) < 0 else list(reversed(h)) for h in holes]      # holes wind opposite
    hs.sort(key=lambda h: -max(p[0] for p in h))

    for h in hs:
        edges = [(poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly))]
        for hh in hs:
            if hh is h:
                continue
            edges += [(hh[i], hh[(i + 1) % len(hh)]) for i in range(len(hh))]
        best = None
        hi_order = sorted(range(len(h)), key=lambda i: -h[i][0])
        for hi in hi_order:
            cands = sorted(range(len(poly)), key=lambda pi:
                           (poly[pi][0] - h[hi][0]) ** 2 + (poly[pi][1] - h[hi][1]) ** 2)
            for pi in cands[:40]:
                a, b = poly[pi], h[hi]
                if any(seg_hit(a, b, c, d) for (c, d) in edges):
                    continue
                best = (pi, hi)
                break
            if best:
                break
        if not best:
            return None
        pi, hi = best
        poly = (poly[:pi + 1] + h[hi:] + h[:hi + 1] + poly[pi:])
    return poly


def fit_affine(samples):
    """least squares (x, y, 1) -> t, for UVs that continue the surrounding wall"""
    A = [(s[0], s[1], 1.0) for s in samples]
    outs = []
    for col in (2, 3):
        b = [s[col] for s in samples]
        n = 3
        ata = [[sum(A[r][i] * A[r][j] for r in range(len(A))) for j in range(n)] for i in range(n)]
        atb = [sum(A[r][i] * b[r] for r in range(len(A))) for i in range(n)]
        for c in range(n):
            pv = max(range(c, n), key=lambda r: abs(ata[r][c]))
            ata[c], ata[pv] = ata[pv], ata[c]
            atb[c], atb[pv] = atb[pv], atb[c]
            for r in range(n):
                if r == c or abs(ata[c][c]) < 1e-12:
                    continue
                f = ata[r][c] / ata[c][c]
                for k in range(c, n):
                    ata[r][k] -= f * ata[c][k]
                atb[r] -= f * atb[c]
        outs.append([atb[i] / ata[i][i] if abs(ata[i][i]) > 1e-12 else 0.0 for i in range(n)])
    cu, cv = outs
    return lambda x, y: (cu[0] * x + cu[1] * y + cu[2], cv[0] * x + cv[1] * y + cv[2])


EMISSIVE_TEX = b"#(argb,8,8,3)color(1.000,1.000,1.000,1.0,co)"
EMISSIVE_MAT = b"a3\\data_f\\lights\\car_headlight_emit.rvmat"
MIRROR_TEX = b"#(argb,8,8,3)color(1.000,0.929,0.856,1.0,co)"
MIRROR_MAT = b"a3\\data_f\\mirror.rvmat"

WORD = "MCSO"


def main():
    src, out = sys.argv[1], sys.argv[2]
    ver, lods = mlod_rw.parse(src)
    L = lods[0]
    pts, faces, norms = L["pts"], L["faces"], L["norms"]
    npt0, nface0 = len(pts), len(faces)

    # Reading direction is READ OFF the designer's own letters, not assumed: on the interior sign
    # A/P/D run from high X to low X, on the side sign from low to high. Get it wrong and the sign
    # comes out mirrored, which is exactly what the first pass shipped.
    SIGNS = [
        # panel_z = the face the letters are cut through; back_z = the far side of the wall.
        # reveal/back materials are the ones the designer used, read out of the original model.
        dict(name="interior", z_room=5.441, z_street=5.509, read=-1,
             box=(-7.0, 14.0, -1.0, 5.0), skins=(5.509,),
             panel_z=5.509, back_z=5.441, max_width=9.5, x_shift=-1.6,
             reveal=(MIRROR_TEX, MIRROR_MAT),
             # owner: the shine belongs on the letter's FACE as well as its edges, so the back of
             # the recess is mirror too rather than the wall texture the designer used there
             back=(MIRROR_TEX, MIRROR_MAT)),
        dict(name="side", z_room=-14.028, z_street=-14.091, read=+1,
             box=(5.5, 15.0, -1.0, 10.0), skins=(-14.091,),
             panel_z=-14.091, back_z=-14.028, max_width=7.2, x_shift=0.0,
             reveal=(b"a3\\structures_f_epc\\dominants\\ghosthotel\\data\\gh_gazebo_out_co.paa",
                     b"a3\\structures_f\\data\\metal\\metal_red_dirty.rvmat"),
             back=None),
    ]

    del_faces = set()
    flat = []      # (poly2, z, tex, mat, flags, uv)        -- rebuilt panel surface
    walls = []     # (loop, z_panel, z_back, texmat, flags, sense) -- recess reveals
    backs = []     # (poly2, z, texmat, flags, uv)          -- recess back plates

    def faces_in(zv, box):
        x0, x1, y0, y1 = box
        out = []
        for fi, f in enumerate(faces):
            P = [pts[f["vs"][k][0]] for k in range(f["nv"])]
            if all(abs(p[2] - zv) < 2e-3 and x0 <= p[0] <= x1 and y0 <= p[1] <= y1 for p in P):
                out.append(fi)
        return out

    for S in SIGNS:
        z_room, z_street = S["z_room"], S["z_street"]
        lo, hi = min(z_room, z_street), max(z_room, z_street)
        skin_z = S["skins"]

        ref_skin = faces_in(skin_z[-1], S["box"]) or faces_in(skin_z[0], S["box"])
        lps = sorted(loops_of(faces, pts, ref_skin, 0, 1), key=lambda l: -abs(signed_area(l)))
        sgn = 1.0 if signed_area(lps[0]) > 0 else -1.0
        old_ap = [l for l in lps[1:] if signed_area(l) * sgn < 0]
        old_isl = [l for l in lps[1:] if signed_area(l) * sgn > 0]

        xs = [p[0] for l in old_ap for p in l]
        ys = [p[1] for l in old_ap for p in l]
        cap, y0 = max(ys) - min(ys), min(ys)
        cu = (min(xs) + max(xs)) / 2.0
        # Letterforms come from a real font now. Scale the word uniformly to fit the panel: the
        # font is far less condensed than the designer's own lettering, so at the original cap
        # height MCSO would overrun the wall.
        max_w = S["max_width"]
        nat_w, _ = glyphs.layout(WORD, cap)
        scale = min(1.0, max_w / nat_w)
        cap_used = cap * scale
        total, letters = glyphs.layout(WORD, cap_used)
        start_x = cu - total / 2.0
        print("%-9s font %s: natural %.2f m at cap %.2f -> cap %.2f, word %.2f m at x %.2f..%.2f, reads %s"
              % (S["name"], os.path.basename(glyphs.FONT), nat_w, cap, cap_used, total,
                 start_x, start_x + total, "+X" if S["read"] > 0 else "-X"))

        def place(poly):
            out = [(start_x + x, y0 + y) for (x, y) in poly]
            if S["read"] < 0:
                out = [(2 * cu - x, y) for (x, y) in out][::-1]
            # x_shift is applied AFTER the mirror, so it always means the same direction on the
            # finished sign regardless of which way that sign reads
            return [(x + S["x_shift"], y) for (x, y) in out]

        pieces, apertures, islands = [], [], []
        for (outers, holes) in letters:
            for o in outers:
                ap = place(o)
                apertures.append(ap)
                inner = [place(h) for h in holes if point_in(o, h[0])]
                islands += inner
                pieces.append((ap, inner))       # filled letter: outline plus its counters

        # Rebuild the WHOLE coplanar panel each skin sits in, not a patch rectangle over it.
        # Patching left the wall's own big triangles straddling the patch edge, and two coplanar
        # surfaces in the same place is z-fighting -- the speckle and the visible rectangle.
        for zv in skin_z:
            fis = faces_in(zv, S["box"])
            if not fis:
                continue
            comps = comps_of(faces, fis)
            target = None
            for c in comps:
                P = [pts[faces[fi]["vs"][k][0]] for fi in c for k in range(faces[fi]["nv"])]
                if (min(p[0] for p in P) <= min(xs) and max(p[0] for p in P) >= max(xs)
                        and min(p[1] for p in P) <= min(ys) and max(p[1] for p in P) >= max(ys)):
                    target = c
                    break
            if target is None:
                raise SystemExit("%s z=%.3f: no panel component contains the lettering" % (S["name"], zv))

            plps = sorted(loops_of(faces, pts, target, 0, 1), key=lambda l: -abs(signed_area(l)))
            outer = plps[0]
            osgn = 1.0 if signed_area(outer) > 0 else -1.0
            sign_bb = (min(xs) - 0.05, max(xs) + 0.05, min(ys) - 0.05, max(ys) + 0.05)

            def is_old_sign(l):
                cx = sum(p[0] for p in l) / len(l)
                cy = sum(p[1] for p in l) / len(l)
                return sign_bb[0] <= cx <= sign_bb[1] and sign_bb[2] <= cy <= sign_bb[3]

            # keep every feature of the panel except the old lettering; add the new lettering
            keep_holes = [l for l in plps[1:] if signed_area(l) * osgn < 0 and not is_old_sign(l)]
            keep_isl = [l for l in plps[1:] if signed_area(l) * osgn > 0 and not is_old_sign(l)]

            samples = []
            for fi in target:
                f = faces[fi]
                for k in range(f["nv"]):
                    pi, ni, tu, tv = f["vs"][k]
                    samples.append((pts[pi][0], pts[pi][1], tu, tv))
            uv = fit_affine(samples)
            err = max(max(abs(uv(s[0], s[1])[0] - s[2]), abs(uv(s[0], s[1])[1] - s[3])) for s in samples)
            c = collections.Counter((faces[fi]["tex"], faces[fi]["mat"], faces[fi]["flags"]) for fi in target)
            tex, mat, flg = c.most_common(1)[0][0]
            del_faces |= set(target)

            flat.append(((outer, keep_holes + apertures), zv, tex, mat, flg, uv))
            flg_panel, uv_panel = flg, uv
            for isl in islands + keep_isl:
                flat.append(((isl, []), zv, tex, mat, flg, uv))
            print("          panel z=%+8.3f: %3d faces rebuilt, %d kept feature(s), UV residual %.4f"
                  % (zv, len(target), len(keep_holes) + len(keep_isl), err))

        # old sign guts: anything inside an old aperture, anywhere through the sandwich
        for fi, f in enumerate(faces):
            P = [pts[f["vs"][k][0]] for k in range(f["nv"])]
            if not all(lo - 8e-3 <= p[2] <= hi + 8e-3 for p in P):
                continue
            # every corner must be inside one aperture -- testing the centroid alone deleted the
            # side sign's backlight panel, whose centre happens to fall inside the old P
            if any(all(point_in_or_near(al, (p[0], p[1]), 0.03) for p in P) for al in old_ap):
                del_faces.add(fi)

        # THE LETTERS ARE RECESSES, not slabs. The designer cut each letter through the street-side
        # panel and lined the hole: reveal walls down the sides, and (on the interior sign) a back
        # plate at the far face. The shine is the REVEAL material, which is why a flat panel of
        # mirror never looked like the original. The side sign has no back plate at all -- it is a
        # through-hole with the lit panel behind it, and that is what makes those letters glow.
        panel_z = S["panel_z"]
        back_z = S["back_z"]
        rev_tm = S["reveal"]
        back_tm = S["back"]
        for ap in apertures:
            walls.append((ap, panel_z, back_z, rev_tm, flg_panel, +1))
        for isl in islands:
            walls.append((isl, panel_z, back_z, rev_tm, flg_panel, -1))
        if back_tm is not None:
            merged_back = bridge_holes(apertures[0], []) if False else None
            for ap in apertures:
                inner = [i for i in islands if point_in(ap, (sum(p[0] for p in i) / len(i),
                                                             sum(p[1] for p in i) / len(i)))]
                backs.append(((ap, inner), back_z, back_tm, flg_panel, uv_panel,
                              1.0 if panel_z > back_z else -1.0))

    # ------------------------------------------------------------------ rebuild
    still_used = set()
    for fi, f in enumerate(faces):
        if fi in del_faces:
            continue
        for k in range(f["nv"]):
            still_used.add(f["vs"][k][0])
    del_pts = {f["vs"][k][0] for fi in del_faces for f in [faces[fi]] for k in range(f["nv"])}
    del_pts -= still_used

    keep_pts = [i for i in range(npt0) if i not in del_pts]
    pmap = {o: n for n, o in enumerate(keep_pts)}
    new_pts = [pts[i] for i in keep_pts]
    pt_src = [("old", i) for i in keep_pts]
    new_norms, nmap = [], {}

    def nidx(key, vec):
        if key not in nmap:
            nmap[key] = len(new_norms)
            new_norms.append(vec)
        return nmap[key]

    keep_faces = [i for i in range(nface0) if i not in del_faces]
    new_faces, face_src = [], []
    for fi in keep_faces:
        f = faces[fi]
        vs = []
        for k in range(4):
            pi, ni, tu, tv = f["vs"][k]
            if k < f["nv"]:
                vs.append((pmap[pi], nidx(("o", ni), norms[ni]), tu, tv))
            else:
                vs.append((0, 0, tu, tv))
        new_faces.append(dict(nv=f["nv"], vs=vs, flags=f["flags"], tex=f["tex"], mat=f["mat"]))
        face_src.append(("old", fi))

    pflag = pts[keep_pts[0]][3]

    def add_face(idxs, base, nrm, texmat, flg, uvfn):
        ni = nidx(("s", round(nrm[0], 4), round(nrm[1], 4), round(nrm[2], 4)), nrm)
        vs = []
        for k in range(4):
            if k < len(idxs):
                px, py = new_pts[base + idxs[k]][0], new_pts[base + idxs[k]][1]
                tu, tv = uvfn(px, py)
                vs.append((base + idxs[k], ni, tu, tv))
            else:
                vs.append((0, 0, 0.0, 0.0))
        new_faces.append(dict(nv=len(idxs), vs=vs, flags=flg, tex=texmat[0], mat=texmat[1]))
        face_src.append(("synth", None))

    def emit_poly(rings, zv, texmat, flg, uvfn, view_dir):
        """One-sided surface from (outer, holes). Wound so the right-hand normal points AWAY from
        the viewer, into the material -- the convention the model's own letters use."""
        outer, holes = rings
        poly, tris = tri_rings(outer, holes)
        base = len(new_pts)
        for (x, y) in poly:
            new_pts.append((x, y, zv, pflag))
            pt_src.append(("synth", None))
        for (i0, i1, i2) in tris:
            a, b, c = poly[i0], poly[i1], poly[i2]
            ccw = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) > 0
            tri = [i0, i1, i2]
            if ccw:
                tri.reverse()                 # CW in XY -> RH normal is -Z
            if view_dir < 0:
                tri.reverse()
            add_face(tuple(tri), base, (0.0, 0.0, -view_dir), texmat, flg, uvfn)

    for (poly, zv, tex, mat, flg, uv) in flat:
        emit_poly(poly, zv, (tex, mat), flg, uv, 1.0 if zv > 0 else -1.0)

    for (poly, zv, texmat, flg, uv, view_dir) in backs:
        # seen THROUGH the letter, so it faces whichever side the recess opens to -- getting this
        # from the sign of z instead made it backface-cull, and the wall read as see-through
        emit_poly(poly, zv, texmat, flg, uv, view_dir)

    for (loop, z_panel, z_back, texmat, flg, sense) in walls:
        n = len(loop)
        ccw = signed_area(loop) > 0
        base = len(new_pts)
        for (x, y) in loop:
            new_pts.append((x, y, z_panel, pflag))
            pt_src.append(("synth", None))
        for (x, y) in loop:
            new_pts.append((x, y, z_back, pflag))
            pt_src.append(("synth", None))
        uvfn = lambda x, y: (x * 0.5, 1.0 - y * 0.5)
        for i in range(n):
            j = (i + 1) % n
            ax_, ay_ = loop[i]
            bx_, by_ = loop[j]
            ex, ey = bx_ - ax_, by_ - ay_
            ln = math.hypot(ex, ey)
            if ln < 1e-9:
                continue
            # outward = out of the enclosed area; for an aperture that is INTO the wall (away from
            # the void), for a counter island it is the other way round
            ox, oy = (ey / ln, -ex / ln) if ccw else (-ey / ln, ex / ln)
            ox, oy = ox * sense, oy * sense
            quad = [i, i + n, j + n, j]
            p0, p1, p2 = (new_pts[base + q] for q in quad[:3])
            e1 = tuple(p1[k] - p0[k] for k in range(3))
            e2 = tuple(p2[k] - p0[k] for k in range(3))
            cr = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2],
                  e1[0] * e2[1] - e1[1] * e2[0])
            if cr[0] * ox + cr[1] * oy < 0:        # want the RH normal pointing into the material
                quad.reverse()
            add_face(tuple(quad), base, (ox, oy, 0.0), texmat, flg, uvfn)

    npt1, nface1 = len(new_pts), len(new_faces)
    print("LOD0: pts %d -> %d, norms %d -> %d, faces %d -> %d (deleted %d faces, %d points)"
          % (npt0, npt1, len(norms), len(new_norms), nface0, nface1, len(del_faces), len(del_pts)))

    new_taggs = []
    for t in L["taggs"]:
        nm, d = t["name"], t["data"]
        if nm == b"#SharpEdges#":
            pairs = [struct.unpack_from("<II", d, i * 8) for i in range(len(d) // 8)]
            keep = [(pmap[a], pmap[b]) for a, b in pairs if a not in del_pts and b not in del_pts]
            new_taggs.append(dict(b=t["b"], name=nm,
                                  data=b"".join(struct.pack("<II", a, b) for a, b in keep)))
        elif nm == b"#UVSet#":
            setid = struct.unpack_from("<I", d, 0)[0]
            offs, o = [], 4
            for f in faces:
                offs.append(o)
                o += 8 * f["nv"]
            buf = bytearray(struct.pack("<I", setid))
            for i, (kind, fi) in enumerate(face_src):
                if kind == "old":
                    buf += d[offs[fi]:offs[fi] + 8 * faces[fi]["nv"]]
                else:
                    f = new_faces[i]
                    for k in range(f["nv"]):
                        buf += struct.pack("<ff", f["vs"][k][2], f["vs"][k][3])
            new_taggs.append(dict(b=t["b"], name=nm, data=bytes(buf)))
        elif nm == b"#EndOfFile#":
            new_taggs.append(dict(b=t["b"], name=nm, data=b""))
        elif len(d) == npt0 + nface0:
            buf = bytearray()
            for kind, i in pt_src:
                buf.append(d[i] if kind == "old" else 0)
            for kind, fi in face_src:
                buf.append(d[npt0 + fi] if kind == "old" else 0)
            assert len(buf) == npt1 + nface1
            new_taggs.append(dict(b=t["b"], name=nm, data=bytes(buf)))
        else:
            raise SystemExit("unhandled tagg %r" % nm)

    L["pts"], L["norms"], L["faces"], L["taggs"] = new_pts, new_norms, new_faces, new_taggs
    print("wrote %s (%d bytes)" % (out, mlod_rw.write(out, ver, lods)))


if __name__ == "__main__":
    main()
