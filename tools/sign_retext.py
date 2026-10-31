#!/usr/bin/env python3
"""
sign_retext.py -- letter the two RAISED signs on HQMesh.p3d.

    front, above the door        "ASYLUM POLICE DEPARTMENT" -> "MALDEN COUNTY SHERIFF'S OFFICE"
    carport, under the windows   bare wall                  -> "MALDEN COUNTY SHERIFF'S OFFICE"

Both are letters that STAND PROUD of the wall: every glyph is a prism with a front cap and side
walls and NO back cap, rooted 0.05 m inside the wall so the open back can never be seen. That is
how the designer built the front sign. The two APD signs are a different animal entirely -- they
are RECESSES cut through the wall, and tools/sign_retext_apd.py handles those.

Letterforms come from a real font (Audiowide, the face the cyberdeck UI uses) via
sign_retext_glyphs.py. Two earlier approaches are worth not repeating: hand-authored letterforms
were rejected three times ("looks like a 0"), and REUSING the designer's own glyph components --
which kept his exact letterforms -- can only ever spell words built from letters the sign already
contained, so F, H and the apostrophe still had to be drawn by hand and stood out next to the rest.

CONVENTIONS, measured off this model and easy to get wrong:
  * a letter is a prism with a FRONT cap only -- there is no back cap, the wall closes it
  * faces are wound so the right-hand-rule normal points INWARD (into the material, away from the
    viewer) and the stored per-corner normal is that same inward vector; get it wrong and the
    letter is silently backface-culled into nothing
  * counters -- the middle of an O, A, D, R -- are HOLES in the cap and carry their own side
    walls, wound the other way round: the material is OUTSIDE those loops, not inside
  * TAGGs sized npoints+nfaces are per-point-then-per-face byte arrays and must be rebuilt
    alongside any face or point edit; #SharpEdges# is POINT-index pairs; #UVSet# is per face
  * points are never compacted, exactly as tools/p3d_replay_edit.py relies on

Each sign works in its own right-handed (u, v, w) frame with w pointing OUT of the wall, v up, and
the text reading along -u. Those frames are the only thing that differs between the two signs.

Writes a NEW filename because Arma caches models by path -- an in-place swap ships but keeps
rendering the cached copy. Update custom_p3ds/malden_buildings.sqf to match.

Run with ~/.venvs/signtools/bin/python -- earcut will not install into the system Python (PEP 668).

Usage:  python3 tools/sign_retext.py [--out <path>] [--dry-run]
"""
import collections
import math
import os
import struct
import sys

sys.path.insert(0, "/home/timb/blender_work")
import mlod_rw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sign_retext_glyphs as glyphs

import numpy as np
import mapbox_earcut

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "mission/Armapunk2035.Malden/HQMesh.p3d")
SQRT2 = math.sqrt(2.0)

FRONT_OLD = "ASYLUMPOLICEDEPARTMENT"
WORD = "MALDEN COUNTY SHERIFF'S OFFICE"

# How wide each sign is allowed to be, and where its centre sits. Both were measured off the model,
# and both are the whole design decision on these signs -- the wording is 30 characters against the
# designer's 22, and Audiowide is a wide face (the word is 30.7 x cap height), so the letters can
# only be as tall as the wall is long.
#
# FRONT. The flat wall panel behind the letters runs u -4.724..3.617 and the designer centred
# "ASYLUM POLICE DEPARTMENT" on u -0.273 -- which is the centre of the DOOR below it (u -0.271),
# not the centre of the panel (u -0.554). Keep his centre, so the sign still sits over the door,
# and let the right-hand panel edge set the width: 7.20 m leaves ~0.29 m clear on the right and
# 0.85 m on the left.
FRONT_CENTRE = -0.2705
FRONT_WIDTH = 7.20
FRONT_PANEL_U = (-4.724, 3.617)

# CARPORT. Wall plane x = 14.0073 facing +X, solid from y 4.438 (its bottom edge) up to y 5.378
# (the sill of the three narrow windows, whose apertures span z -7.173..-6.339, -0.033..0.801 and
# 6.580..7.413). The word goes under the windows, centred on that window band (z 0.120) and
# vertically centred in the 0.94 m of wall below it, which puts the baseline at 4.70.
CARPORT_WALL_X = 14.0073
CARPORT_CENTRE = -0.120                   # the window band is centred on z +0.120, and u = -Z
CARPORT_WIDTH = 13.80
CARPORT_BASE = 4.70
CARPORT_BAND_V = (4.438, 5.378)
CARPORT_BAND_U = (-7.413, 7.173)          # the window band, in the carport frame (u = -Z)

# The designer's letters stand 0.066 m proud of the wall and root the rest of their 0.116 m depth
# inside it. The front sign keeps its own measured values; the carport sign copies these.
PROUD = 0.066

# Texture density on the letters, in texture units per metre. The designer's own glyphs carry no
# usable mapping to copy -- each one is mapped locally and a plane fitted to any of them leaves a
# residual of 0.5-1.9 -- but they do average about 0.8 u/m, i.e. the concrete repeats every 1.25 m,
# and that is what makes them read as concrete rather than as a smear.
UV_SCALE = 0.8

# These letters are 0.23-0.45 m tall, an order smaller than the 2 m MCSO letters the glyph module
# was tuned for, and every contour point costs a cap triangle and a side quad on both signs. Six
# steps per curve puts the flattening error under 3 mm here, which is well past invisible.
glyphs.CURVE_STEPS = 6


# ----------------------------------------------------------------- frames
def frame_front():
    """The front sign sits on a 45-degree wall: u runs along the text, v is up, w is outward."""
    to_uvw = lambda p: ((p[0] - p[2]) / SQRT2, p[1], (p[0] + p[2]) / SQRT2)
    to_xyz = lambda u, v, w: ((u + w) / SQRT2, v, (w - u) / SQRT2)
    return to_uvw, to_xyz


def frame_carport():
    """The carport wall faces +X, so w = X and v = Y.

    u is -Z, not +Z, for two reasons that happen to agree: it keeps the frame right-handed
    (u x v = w, same as the front sign's), and it makes the text read along -u there too, because
    someone standing outside at +X with +Y up reads left-to-right along +Z.
    """
    to_uvw = lambda p: (-p[2], p[1], p[0])
    to_xyz = lambda u, v, w: (w, v, -u)
    return to_uvw, to_xyz


# ----------------------------------------------------------------- model helpers
def components(L):
    pts, faces = L["pts"], L["faces"]
    parent = list(range(len(pts)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def uni(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    for f in faces:
        ids = [f["vs"][k][0] for k in range(f["nv"])]
        for k in range(1, len(ids)):
            uni(ids[0], ids[k])
    out = collections.defaultdict(list)
    for fi, f in enumerate(faces):
        out[find(f["vs"][0][0])].append(fi)
    return list(out.values())


def comp_points(L, fl):
    ps = set()
    for fi in fl:
        f = L["faces"][fi]
        for k in range(f["nv"]):
            ps.add(f["vs"][k][0])
    return ps


def front_glyphs(L):
    """The 22 letters of the old front sign, ordered as they read."""
    to_uvw, _ = frame_front()
    pts = L["pts"]
    out = []
    for fl in components(L):
        if len(fl) > 200:
            continue
        ps = comp_points(L, fl)
        uvw = [to_uvw(pts[p]) for p in ps]
        cu = sum(a[0] for a in uvw) / len(uvw)
        cv = sum(a[1] for a in uvw) / len(uvw)
        if not (3.7 < cv < 4.2 and -4.0 < cu < 3.5):
            continue
        if min(a[2] for a in uvw) < 15.0:
            continue
        out.append(dict(fl=fl, ps=ps,
                        u=(min(a[0] for a in uvw), max(a[0] for a in uvw)),
                        v=(min(a[1] for a in uvw), max(a[1] for a in uvw)),
                        w=(min(a[2] for a in uvw), max(a[2] for a in uvw))))
    out.sort(key=lambda g: -g["u"][0])          # the text reads along -u
    return out


# ----------------------------------------------------------------- glyph geometry
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
        if (y0 > y) != (y1 > y) and x0 + (y - y0) * (x1 - x0) / (y1 - y0) > x:
            inside = not inside
    return inside


def tri_rings(outer, holes):
    """Triangulate a polygon WITH HOLES -> (points, [(i, j, k), ...]).

    Font contours carry 50-100 points each; hand-rolled hole bridging self-crosses on them (that
    is what turned the first cut of the MCSO signs into a nearly solid panel). earcut takes the
    rings directly -- outer first, holes after -- so there is nothing to bridge.
    """
    rings = [list(outer)] + [list(h) for h in holes]
    pts, ends = [], []
    for r in rings:
        pts.extend(r)
        ends.append(len(pts))
    idx = mapbox_earcut.triangulate_float64(np.array(pts, dtype=np.float64), np.array(ends))
    return pts, [tuple(idx[i:i + 3]) for i in range(0, len(idx), 3)]


def build_prism(outer, holes, w_back, w_front):
    """One raised letter -> (verts in (u, v, w), [(indices, inward normal, [(tu, tv), ...]), ...]).

    Front cap with the counters cut out of it, side walls down every ring, no back cap.
    """
    rings = [list(outer)] + [list(h) for h in holes]
    pts2, tris = tri_rings(outer, holes)         # pts2 is the rings, concatenated in that order
    verts = [(x, y, w_front) for (x, y) in pts2]
    faces = []

    cap_uv = lambda i: (UV_SCALE * pts2[i][0], -UV_SCALE * pts2[i][1])
    for (i0, i1, i2) in tris:
        a, b, c = pts2[i0], pts2[i1], pts2[i2]
        tri = [i0, i1, i2]
        if (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) > 0:
            tri.reverse()                        # CW in (u, v) -> RH normal is -w, into the wall
        faces.append((tuple(tri), (0.0, 0.0, -1.0), [cap_uv(i) for i in tri]))

    off = 0
    for ri, r in enumerate(rings):
        n = len(r)
        ccw = signed_area(r) > 0
        back = []
        for (x, y) in r:
            back.append(len(verts))
            verts.append((x, y, w_back))
        arc = [0.0]
        for i in range(n):
            j = (i + 1) % n
            arc.append(arc[-1] + math.hypot(r[j][0] - r[i][0], r[j][1] - r[i][1]))
        for i in range(n):
            j = (i + 1) % n
            eu, ev = r[j][0] - r[i][0], r[j][1] - r[i][1]
            ln = math.hypot(eu, ev)
            if ln < 1e-9:
                continue
            # out of the enclosed area; the letter's material is INSIDE the outer ring and OUTSIDE
            # a counter, and the stored normal has to point into the material either way
            ou, ov = (ev / ln, -eu / ln) if ccw else (-ev / ln, eu / ln)
            if ri == 0:
                ou, ov = -ou, -ov
            quad = [off + i, back[i], back[j], off + j]
            p0, p1, p2 = verts[quad[0]], verts[quad[1]], verts[quad[2]]
            e1 = tuple(p1[k] - p0[k] for k in range(3))
            e2 = tuple(p2[k] - p0[k] for k in range(3))
            cr = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2],
                  e1[0] * e2[1] - e1[1] * e2[0])
            uv = [(UV_SCALE * arc[i], 0.0), (UV_SCALE * arc[i], -UV_SCALE * (w_front - w_back)),
                  (UV_SCALE * arc[i + 1], -UV_SCALE * (w_front - w_back)), (UV_SCALE * arc[i + 1], 0.0)]
            if cr[0] * ou + cr[1] * ov < 0:      # RH normal is pointing out of the material
                quad.reverse()
                uv.reverse()
            faces.append((tuple(quad), (ou, ov, 0.0), uv))
        off += n
    return verts, faces


def lay_out(word, width, v_base, centre):
    """Fit the word to `width` metres and place it -> (cap height, [(outer, [holes]), ...]).

    The word is laid out on the font's own advances, scaled uniformly to the width the wall allows,
    then mapped into the sign frame -- which runs the text along -u, so the first letter lands at
    the +u end and the whole block is mirrored with it.
    """
    unit, _ = glyphs.layout(word, 1.0)
    cap = width / unit
    _, letters = glyphs.layout(word, cap)
    xs = [p[0] for (o, h) in letters for c in o for p in c]
    x0 = min(xs)
    u_hi = centre + width / 2.0
    place = lambda c: [(u_hi - (x - x0), v_base + y) for (x, y) in c]
    out = []
    for (outers, holes) in letters:
        for o in outers:
            out.append((place(o), [place(h) for h in holes if point_in(o, h[0])]))
    return cap, out


# ----------------------------------------------------------------- main build
def main():
    # the stage-1 file is a BUILD INTERMEDIATE -- sign_retext_apd.py reads it and the shipped model is
    # its output, so writing it into the mission folder only ever meant packing 3.9 MB of nothing into
    # a PBO every client downloads. It lives outside the mission now.
    out_path = os.path.join(REPO, "build", "HQMesh_mcso.p3d")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    if "--out" in sys.argv:
        out_path = sys.argv[sys.argv.index("--out") + 1]
    dry = "--dry-run" in sys.argv

    font, gs = glyphs._load()
    missing = sorted({ch for ch in WORD if ord(ch) not in font.getBestCmap()})
    if missing:
        raise SystemExit("%s has no glyph for %r" % (os.path.basename(glyphs.FONT), missing))

    ver, lods = mlod_rw.parse(SRC)
    L = lods[0]
    opts, onorms, ofaces = L["pts"], L["norms"], L["faces"]
    npt0, nface0 = len(opts), len(ofaces)

    # ---- everything about how a letter is built comes off the designer's own front sign
    gl = front_glyphs(L)
    assert len(gl) == len(FRONT_OLD), (len(gl), len(FRONT_OLD))
    old_u = (min(g["u"][0] for g in gl), max(g["u"][1] for g in gl))
    old_v = (min(g["v"][0] for g in gl), max(g["v"][1] for g in gl))
    w_back = min(g["w"][0] for g in gl)
    w_front = max(g["w"][1] for g in gl)
    style = collections.Counter((ofaces[fi]["tex"], ofaces[fi]["mat"], ofaces[fi]["flags"])
                                for g in gl for fi in g["fl"])
    tex, mat, flags = style.most_common(1)[0][0]
    pt_flag = opts[min(gl[0]["ps"])][3]
    print("the designer's front sign: %d glyphs, u %.4f..%.4f, cap %.4f, depth %.4f, %s"
          % (len(gl), old_u[0], old_u[1], old_v[1] - old_v[0], w_front - w_back,
             os.path.basename(tex.decode(errors="replace").replace("\\", "/"))))

    SIGNS = [
        # The front sign keeps the designer's own depth and stays optically where his sign was:
        # smaller letters centred on the same band, not dropped onto the same baseline.
        dict(name="front", frame=frame_front(), centre=FRONT_CENTRE, width=FRONT_WIDTH,
             v_mid=(old_v[0] + old_v[1]) / 2.0, w_back=w_back, w_front=w_front,
             limit_u=FRONT_PANEL_U, limit_v=None),
        dict(name="carport", frame=frame_carport(), centre=CARPORT_CENTRE, width=CARPORT_WIDTH,
             v_base=CARPORT_BASE,
             w_back=CARPORT_WALL_X + PROUD - (w_front - w_back), w_front=CARPORT_WALL_X + PROUD,
             limit_u=CARPORT_BAND_U, limit_v=CARPORT_BAND_V),
    ]

    # ---- drop the old lettering, keep everything else
    del_faces, del_pts = set(), set()
    for g in gl:
        del_faces |= set(g["fl"])
        del_pts |= set(g["ps"])

    keep_pts = [i for i in range(npt0) if i not in del_pts]
    pmap = {old: new for new, old in enumerate(keep_pts)}
    new_pts = [opts[i] for i in keep_pts]
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
        f = ofaces[fi]
        vs = []
        for k in range(4):
            pi, ni, tu, tv = f["vs"][k]
            if k < f["nv"]:
                vs.append((pmap[pi], nidx(("old", ni), onorms[ni]), tu, tv))
            else:
                vs.append((0, 0, tu, tv))
        new_faces.append(dict(nv=f["nv"], vs=vs, flags=f["flags"], tex=f["tex"], mat=f["mat"]))
        face_src.append(("old", fi))

    # ---- and letter both signs
    for S in SIGNS:
        to_uvw, to_xyz = S["frame"]
        f0 = len(new_faces)
        # the first pass only needs the cap height, which fixes where the baseline goes
        unit, _ = glyphs.layout(WORD, 1.0)
        cap = S["width"] / unit
        v_base = S["v_base"] if "v_base" in S else S["v_mid"] - cap / 2.0
        cap, letters = lay_out(WORD, S["width"], v_base, S["centre"])

        for (outer, holes) in letters:
            verts, fcs = build_prism(outer, holes, S["w_back"], S["w_front"])
            base = len(new_pts)
            for (U, V, W) in verts:
                new_pts.append(to_xyz(U, V, W) + (pt_flag,))
                pt_src.append(("synth", None))
            for (idxs, nrm, uv) in fcs:
                # to_xyz is a rotation, so it maps directions as well as points
                wx, wy, wz = to_xyz(*nrm)
                ln = math.sqrt(wx * wx + wy * wy + wz * wz) or 1.0
                nvec = (wx / ln, wy / ln, wz / ln)
                ni = nidx(("synth", round(nvec[0], 4), round(nvec[1], 4), round(nvec[2], 4)), nvec)
                vs = []
                for k in range(4):
                    if k < len(idxs):
                        vs.append((base + idxs[k], ni, uv[k][0], uv[k][1]))
                    else:
                        vs.append((0, 0, 0.0, 0.0))
                new_faces.append(dict(nv=len(idxs), vs=vs, flags=flags, tex=tex, mat=mat))
                face_src.append(("synth", None))

        us = [p[0] for (o, h) in letters for p in o]
        vs_ = [p[1] for (o, h) in letters for p in o]
        print("%-8s cap %.4f, %d letters in %d faces: u %8.4f..%8.4f  v %.4f..%.4f  w %.4f..%.4f"
              % (S["name"], cap, len(letters), len(new_faces) - f0, min(us), max(us),
                 min(vs_), max(vs_), S["w_back"], S["w_front"]))
        # the wall is only so big, and letters that run off it hang in the air
        lo, hi = S["limit_u"]
        assert lo <= min(us) and max(us) <= hi, \
            "%s: the word runs off the wall in u (%.4f..%.4f, wall %.4f..%.4f)" \
            % (S["name"], min(us), max(us), lo, hi)
        if S["limit_v"]:
            lo, hi = S["limit_v"]
            assert lo <= min(vs_) and max(vs_) <= hi, \
                "%s: the word runs off the wall in v (%.4f..%.4f, wall %.4f..%.4f)" \
                % (S["name"], min(vs_), max(vs_), lo, hi)

    npt1, nface1 = len(new_pts), len(new_faces)
    print("LOD0: pts %d -> %d, norms %d -> %d, faces %d -> %d"
          % (npt0, npt1, len(onorms), len(new_norms), nface0, nface1))

    # ---- taggs
    new_taggs = []
    for t in L["taggs"]:
        nm, d = t["name"], t["data"]
        if nm == b"#SharpEdges#":
            pairs = [struct.unpack_from("<II", d, i * 8) for i in range(len(d) // 8)]
            out = [(pmap[a], pmap[b]) for a, b in pairs if a not in del_pts and b not in del_pts]
            nd = b"".join(struct.pack("<II", a, b) for a, b in out)
            new_taggs.append(dict(b=t["b"], name=nm, data=nd))
        elif nm == b"#UVSet#":
            setid = struct.unpack_from("<I", d, 0)[0]
            offs, o = [], 4
            for f in ofaces:
                offs.append(o)
                o += 8 * f["nv"]
            buf = bytearray(struct.pack("<I", setid))
            for i, (kind, fi) in enumerate(face_src):
                if kind == "old":
                    buf += d[offs[fi]:offs[fi] + 8 * ofaces[fi]["nv"]]
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
            assert len(buf) == npt1 + nface1, (len(buf), npt1 + nface1)
            new_taggs.append(dict(b=t["b"], name=nm, data=bytes(buf)))
        else:
            raise SystemExit("unhandled tagg %r len %d" % (nm, len(d)))

    L["pts"], L["norms"], L["faces"], L["taggs"] = new_pts, new_norms, new_faces, new_taggs
    if dry:
        print("(dry run -- nothing written)")
        return
    n = mlod_rw.write(out_path, ver, lods)
    print("wrote %s  (%d bytes)" % (out_path, n))


if __name__ == "__main__":
    main()
