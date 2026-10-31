#!/usr/bin/env python3
r"""
p3d_set_roadway_surface.py -- give a model's Roadway LOD faces a surface, so walking on it makes a
sound.

STATUS: UNRESOLVED. This tool works -- it writes the material correctly -- but assigning BI's own
roadway material does NOT make the custom buildings sound like stock ones. See MALDEN.md "Custom
building footstep sound" for the full state. An earlier version of this docstring claimed the
roadway material is never consulted; that was WRONG and is corrected below.

Established, with evidence:
  * BI DOES use these materials on buildings: structures_f.pbo references
    penetration\concrete.rvmat 118 times, metal_plate 83, metal 76, granite 50. So the mechanism is
    real and this is the right slot to be writing.
  * soundEnviron is NOT the knob. All 81 .bisurf files A3 ships set soundEnviron=Empty, yet BI's
    buildings sound correct. Setting it to "metal" on ours changed nothing -- an inert test, which
    was mistakenly read as proof the material is ignored.
  * createSimpleObject is NOT the limitation: a stock house spawned that way has correct footsteps.
  * A material path inside a .p3d gets no getMissionPath prefix. A bare filename fails with
    "Cannot load material file"; a full mpmissions\__cur_mp.<WORLD>\ path loads.
  * MODEL CACHE: Arma serves a .p3d by path, and __cur_mp.<WORLD> is identical on every build, so an
    in-place model swap keeps rendering the cached copy. This masked three consecutive attempts.
    Rename the file or fully exit Arma -- every time.

Untested next steps: the roadway face TEXTURE (--texture, BI may key the surface off that rather
than the material), and reading a stock building's roadway directly out of structures_f.pbo, which
needs an ODOL parser since binarized models are not MLOD.

ORIGINAL PROBLEM STATEMENT. Every custom building on this map is silent underfoot. Their Roadway LODs exist and
are walkable, but every roadway face has an EMPTY material and texture:

    MADGrandPalace 284 faces, Bank 151, RebelRig 204, JewelryBuildingModel 185, HQMesh 70,
    PalaceShop 31, ShopBuildingTrini 31, mentalasylum13 49, BridgeStraight 2, BridgeMiddle 1
    -- all материал/texture = (none)

Arma resolves footstep sound from the roadway face's surface: face -> material -> surfaceInfo ->
a .bisurf -> soundEnviron/soundHit. With the slot empty there is nothing to resolve, so you get
silence. A3 ships the .bisurf set under a3\\data_f\\penetration\\ (concrete, building, wood, metal,
glass, tiles...) and its own rvmats point at them via surfaceInfo.

This is PRE-EXISTING in the designer's originals -- not caused by any edit or rebuild here.

WHAT THIS DOES. Rewrites the material string on every face of the Roadway LOD (resolution 3e15).
Nothing else is touched: points, normals, visual LODs, geometry, tags and every other byte are
copied verbatim, so it is safe to run on a model that is otherwise correct.

Face records are variable length (the texture and material are inline asciiz strings), so the LOD
is re-emitted rather than patched in place.

Usage:
    p3d_set_roadway_surface.py <model.p3d> <surface-path> [--out FILE] [--texture PATH]

    surface-path   what to write into the face MATERIAL slot, e.g.
                   a3\\data_f\\penetration\\concrete.bisurf
    --texture      optionally also set the face texture (some surface lookups key off texture name)
"""
import struct
import sys
import collections

ROADWAY = 3e15


def parse(path):
    d = open(path, "rb").read()
    if d[:4] != b"MLOD":
        raise SystemExit("%s is not MLOD (%r)" % (path, d[:4]))
    off = 4
    version = struct.unpack_from("<I", d, off)[0]; off += 4
    nlod = struct.unpack_from("<I", d, off)[0]; off += 4
    lods = []
    for L in range(nlod):
        start = off
        assert d[off:off + 4] == b"P3DM"; off += 4
        hdrsz, vers, npts, nnorm, nfaces = struct.unpack_from("<IIIII", d, off); off += 20
        flags = d[off:off + 4]; off += 4
        pts_start = off; off += npts * 16
        norm_start = off; off += nnorm * 12
        faces_start = off
        faces = []
        for _ in range(nfaces):
            fo = off
            nv = struct.unpack_from("<I", d, off)[0]; off += 4
            verts = d[off:off + 64]; off += 64
            fflags = d[off:off + 4]; off += 4
            e = d.index(b"\0", off); tex = d[off:e].decode("latin1"); off = e + 1
            e = d.index(b"\0", off); mat = d[off:e].decode("latin1"); off = e + 1
            faces.append(dict(nv=nv, verts=verts, fflags=fflags, tex=tex, mat=mat))
        assert d[off:off + 4] == b"TAGG"; off += 4
        tags_start = off
        while True:
            off += 1
            e = d.index(b"\0", off); name = d[off:e].decode("latin1"); off = e + 1
            size = struct.unpack_from("<I", d, off)[0]; off += 4 + size
            if name == "#EndOfFile#":
                break
        tags_end = off
        res = struct.unpack_from("<f", d, off)[0]; off += 4
        lods.append(dict(npts=npts, nnorm=nnorm, nfaces=nfaces, faces=faces, res=res, start=start,
                         end=off, hdrsz=hdrsz, vers=vers, flags=flags, pts_start=pts_start,
                         norm_start=norm_start, faces_start=faces_start,
                         tags_start=tags_start, tags_end=tags_end))
    return d, version, lods


def is_roadway(res):
    return abs(res - ROADWAY) / ROADWAY < 1e-3


def rebuild(raw, lod, surface, texture):
    out = bytearray()
    out += b"P3DM"
    out += struct.pack("<IIIII", lod["hdrsz"], lod["vers"], lod["npts"], lod["nnorm"], lod["nfaces"])
    out += lod["flags"]
    out += raw[lod["pts_start"]:lod["norm_start"]]
    out += raw[lod["norm_start"]:lod["faces_start"]]
    for f in lod["faces"]:
        out += struct.pack("<I", f["nv"])
        out += f["verts"]
        out += f["fflags"]
        tex = texture if texture is not None else f["tex"]
        out += tex.encode("latin1") + b"\0"
        out += surface.encode("latin1") + b"\0"
    out += b"TAGG"
    out += raw[lod["tags_start"]:lod["tags_end"]]
    out += struct.pack("<f", lod["res"])
    return bytes(out)


if __name__ == "__main__":
    argv = sys.argv[1:]
    out_path = None
    texture = None
    if "--out" in argv:
        i = argv.index("--out"); out_path = argv[i + 1]; del argv[i:i + 2]
    if "--texture" in argv:
        i = argv.index("--texture"); texture = argv[i + 1]; del argv[i:i + 2]
    if len(argv) != 2:
        raise SystemExit(__doc__)
    model, surface = argv
    out_path = out_path or model

    raw, version, lods = parse(model)
    idx = [i for i, l in enumerate(lods) if is_roadway(l["res"])]
    if not idx:
        raise SystemExit("%s has NO Roadway LOD (resolution 3e15) -- nothing to walk on, so nothing "
                         "to give a surface to. LODs present: %s"
                         % (model, ", ".join("%g" % l["res"] for l in lods)))

    out = bytearray()
    out += b"MLOD" + struct.pack("<II", version, len(lods))
    for i, lod in enumerate(lods):
        if i in idx:
            before = collections.Counter(f["mat"] for f in lod["faces"])
            out += rebuild(raw, lod, surface, texture)
            print("  %s LOD%d (Roadway): %d faces, material %s -> %s"
                  % (model.split("/")[-1], i, lod["nfaces"],
                     list(before)[0] and repr(list(before)[0]) or "(none)", surface))
            if texture is not None:
                print("      texture also set to %s" % texture)
        else:
            out += raw[lod["start"]:lod["end"]]
    open(out_path, "wb").write(bytes(out))
    print("  wrote %s (%d bytes, was %d)" % (out_path, len(out), len(raw)))
