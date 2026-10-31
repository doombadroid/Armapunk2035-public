#!/usr/bin/env python3
"""
p3d_replay_edit.py -- replay a face-deletion edit onto a PRISTINE MLOD .p3d.

WHY THIS EXISTS. Round-tripping AsylumGrandPalaceBuilding.p3d through Blender (Arma Toolbox) to
delete some text preserved every texture path, every rvmat and every UV -- and still wrecked the
model's appearance, because the exporter SPLIT EVERY SHARED VERTEX:

    LOD0 points  14,403 -> 51,840   (one vertex per face-corner; 0.88 -> 3.28 points per face)
    LOD1 points     540 ->  2,280
    LOD2 points   1,677 ->  4,928
    LOD3 points     443 ->  1,127

LODs 1-3 were never edited, which is the tell: it is the exporter, not the edit. With nothing
welded, no face shares a normal with its neighbour, every edge renders hard, and the #SharpEdges#
data is meaningless -- so the whole model shades wrong even though the textures are byte-identical.

Rather than try to re-weld and re-derive smooth normals (which cannot recover which edges were
meant to be sharp), this takes the ORIGINAL file -- correct topology, normals, sharp edges, tags --
and removes exactly the faces the edit removed. Everything else stays bit-for-bit.

HOW THE EDIT IS IDENTIFIED. Faces are matched between the two files by a signature of
(vertex count, texture, sorted rounded corner POSITIONS). Positions survive the round-trip even
though vertex indices do not, so this is stable. Verified on the palace: 15,799 of 16,382 faces
matched, 583 unmatched, and ZERO faces present only in the edited file -- i.e. the edit was purely
deletions and is fully accounted for. The script refuses to run if that does not hold.

WHAT IS AND IS NOT REBUILT. Points and normals are copied verbatim and NOT compacted: an MLOD may
carry unused points harmlessly, and keeping them means every per-point structure -- #SharpEdges#
(28,397 edge pairs), selection weights, #Mass# -- stays valid with no remapping. Only per-FACE data
is filtered:
  * the 8 named selections (Text/Main/Glass/Silver/Gold/Light/RoofDetails/#Selected#), whose data is
    npoints bytes followed by nfaces bytes
  * #UVSet# (the SECOND uv set; the primary UVs live inside the face records), whose data is a
    uint32 set index followed by one (u,v) pair per face-corner
LODs other than the target are copied byte-for-byte.

Usage:
    p3d_replay_edit.py <pristine.p3d> <edited.p3d> <output.p3d> [--lod N]
"""
import struct
import sys
import collections


def parse(path):
    d = open(path, "rb").read()
    if d[:4] != b"MLOD":
        raise SystemExit("%s is not MLOD (got %r) -- ODOL/binarized input is not supported" % (path, d[:4]))
    off = 4
    version = struct.unpack_from("<I", d, off)[0]; off += 4
    nlod = struct.unpack_from("<I", d, off)[0]; off += 4
    lods = []
    for L in range(nlod):
        lod_start = off
        if d[off:off + 4] != b"P3DM":
            raise SystemExit("LOD %d: expected P3DM at %d, got %r" % (L, off, d[off:off + 4]))
        off += 4
        hdr = struct.unpack_from("<IIIII", d, off)
        hdrsz, vers, npts, nnorm, nfaces = hdr
        head_end = off + 20 + 4          # 5 uint32 + flags
        off = head_end
        pts_start = off
        pts = [struct.unpack_from("<fff", d, pts_start + i * 16) for i in range(npts)]
        off += npts * 16
        norm_start = off
        off += nnorm * 12
        faces_start = off
        faces = []
        for _ in range(nfaces):
            fo = off
            nv = struct.unpack_from("<I", d, off)[0]; off += 4
            vs = []
            for _k in range(4):
                pi, ni, u, v = struct.unpack_from("<IIff", d, off); off += 16
                vs.append((pi, ni, u, v))
            off += 4                     # face flags
            e = d.index(b"\0", off); tex = d[off:e].decode("latin1"); off = e + 1
            e = d.index(b"\0", off); mat = d[off:e].decode("latin1"); off = e + 1
            faces.append(dict(nv=nv, vs=vs, tex=tex, mat=mat, raw=d[fo:off]))
        faces_end = off
        if d[off:off + 4] != b"TAGG":
            raise SystemExit("LOD %d: expected TAGG at %d" % (L, off))
        off += 4
        tags = []
        while True:
            ts = off
            active = d[off]; off += 1
            e = d.index(b"\0", off); name = d[off:e].decode("latin1"); off = e + 1
            size = struct.unpack_from("<I", d, off)[0]; off += 4
            data = d[off:off + size]; off += size
            tags.append(dict(active=active, name=name, data=data, raw=d[ts:off]))
            if name == "#EndOfFile#":
                break
        res = struct.unpack_from("<f", d, off)[0]; off += 4
        lods.append(dict(npts=npts, nnorm=nnorm, nfaces=nfaces, pts=pts, faces=faces, tags=tags,
                         res=res, head_end=head_end, pts_start=pts_start, norm_start=norm_start,
                         faces_start=faces_start, faces_end=faces_end,
                         start=lod_start, end=off, hdrsz=hdrsz, vers=vers))
    return d, version, lods


def signature(face, pts):
    """(vcount, texture, sorted rounded corner positions) -- survives an exporter that re-indexes
    or splits vertices, because it keys on geometry rather than on indices."""
    corners = tuple(sorted(tuple(round(c, 2) for c in pts[v[0]]) for v in face["vs"][:face["nv"]]))
    return (face["nv"], face["tex"], corners)


def build_lod(lod, keep):
    """Re-emit one LOD with only `keep` (indices into lod['faces'])."""
    out = bytearray()
    out += b"P3DM"
    out += struct.pack("<IIIII", lod["hdrsz"], lod["vers"], lod["npts"], lod["nnorm"], len(keep))
    out += RAW[lod["head_end"] - 4:lod["head_end"]]                 # flags word, verbatim
    out += RAW[lod["pts_start"]:lod["norm_start"]]                  # points, verbatim
    out += RAW[lod["norm_start"]:lod["faces_start"]]                # normals, verbatim
    for i in keep:
        out += lod["faces"][i]["raw"]

    out += b"TAGG"
    npts, nfaces = lod["npts"], lod["nfaces"]
    # per-face corner counts, needed to slice #UVSet#
    nv = [f["nv"] for f in lod["faces"]]
    uv_off = [0]
    for n in nv:
        uv_off.append(uv_off[-1] + n)

    for tag in lod["tags"]:
        name, data = tag["name"], tag["data"]
        new = data
        if len(data) == npts + nfaces:
            # named selection: point weights then face flags. Points are untouched, faces filtered.
            new = data[:npts] + bytes(data[npts + i] for i in keep)
        elif name == "#UVSet#" and len(data) == 4 + sum(nv) * 8:
            chunks = [data[:4]]
            for i in keep:
                s = 4 + uv_off[i] * 8
                chunks.append(data[s:s + nv[i] * 8])
            new = b"".join(chunks)
        elif len(data) == nfaces:
            new = bytes(data[i] for i in keep)
        # everything else (#SharpEdges#, #Property#, #Mass#, #EndOfFile#) is per-point or global
        # and stays as-is, which is only safe because points are never removed.
        out += bytes([tag["active"]])
        out += name.encode("latin1") + b"\0"
        out += struct.pack("<I", len(new))
        out += new
    out += struct.pack("<f", lod["res"])
    return bytes(out)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 3:
        raise SystemExit(__doc__)
    target_lod = 0
    if "--lod" in sys.argv:
        target_lod = int(sys.argv[sys.argv.index("--lod") + 1])
    pristine, edited, outpath = args

    RAW, version, LO = parse(pristine)
    _, _, LE = parse(edited)
    if len(LO) != len(LE):
        raise SystemExit("LOD count differs: %d vs %d" % (len(LO), len(LE)))

    for i, (a, b) in enumerate(zip(LO, LE)):
        if i != target_lod and a["nfaces"] != b["nfaces"]:
            raise SystemExit("LOD %d face count differs (%d vs %d) -- the edit touched more than "
                             "LOD %d, which this tool does not handle" % (i, a["nfaces"], b["nfaces"], target_lod))

    O, E = LO[target_lod], LE[target_lod]
    want = collections.Counter(signature(f, E["pts"]) for f in E["faces"])
    keep, dropped = [], []
    for i, f in enumerate(O["faces"]):
        s = signature(f, O["pts"])
        if want[s] > 0:
            want[s] -= 1
            keep.append(i)
        else:
            dropped.append(i)
    unmatched = sum(v for v in want.values() if v > 0)
    print("pristine LOD%d faces : %d" % (target_lod, O["nfaces"]))
    print("edited   LOD%d faces : %d" % (target_lod, E["nfaces"]))
    print("kept                 : %d" % len(keep))
    print("dropped (the edit)   : %d" % len(dropped))
    print("in edited only       : %d" % unmatched)
    if unmatched:
        raise SystemExit("ABORT: %d faces exist only in the edited file. The edit ADDED or MOVED "
                         "geometry, so it cannot be replayed as a pure deletion." % unmatched)
    if len(keep) != E["nfaces"]:
        raise SystemExit("ABORT: kept %d but edited has %d" % (len(keep), E["nfaces"]))

    tc = collections.Counter(O["faces"][i]["tex"] for i in dropped)
    print("\ndropped faces by texture:")
    for t, n in tc.most_common():
        print("  %5d  %s" % (n, (t or "(none)")[-64:]))

    out = bytearray()
    out += b"MLOD" + struct.pack("<II", version, len(LO))
    for i, lod in enumerate(LO):
        if i == target_lod:
            out += build_lod(lod, keep)
        else:
            out += RAW[lod["start"]:lod["end"]]          # untouched LODs, byte-for-byte
    open(outpath, "wb").write(bytes(out))
    print("\nwrote %s (%d bytes, pristine was %d)" % (outpath, len(out), len(RAW)))
