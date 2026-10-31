#!/usr/bin/env python3
"""Sample mission.sqm objects for the rotation-frame probe.

The height half of the frame question is already settled: debug/frame_probe.sqf measured
getPosWorld == the sqm's position[] elevation to 0.000 on 7/9 classes, so the sqm stores the
MODEL CENTRE and no terrain height is ever needed to place an object from it.

The open half is rotation. The sqm stores angles[]={rx,ry,rz} in radians; the spawn arrays store
[[dirX,dirY,dirZ],[upX,upY,upZ]]. Nothing in the repo has ever proven which Euler convention maps
one to the other, and the failure mode is silent (every object subtly -- or completely -- mis-aimed).

This picks a spread of objects biased towards TILT, because a flat object is satisfied by almost
any convention and proves nothing. Output is an SQF data file the in-game probe reads; the probe
finds each real object in the world and logs its true vectorDir/vectorUp so the convention can be
solved offline against ground truth.

    python3 tools/sqm_frame_sample.py [N]        # default 60 rows
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sqm_read

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQM = os.path.join(REPO, "mission", "Armapunk2035.Malden", "mission.sqm")
OUT = os.path.join(REPO, "mission", "Armapunk2035.Malden", "debug", "frame_angles_data.sqf")

TAU = 2.0 * math.pi


def norm(a):
    """Fold a radian angle into [-pi, pi] -- the sqm writes 6.2735 where it means -0.0096."""
    a = math.fmod(a, TAU)
    if a > math.pi:
        a -= TAU
    if a < -math.pi:
        a += TAU
    return a


def collect(path):
    rows = []
    for n in sqm_read.walk(sqm_read.parse(path)):
        p = n["props"]
        if p.get("dataType") != "Object":
            continue
        pi = n["subs"].get("PositionInfo")
        if not pi:
            continue
        pos = pi["props"].get("position")
        ang = pi["props"].get("angles")
        cls = p.get("type")
        oid = p.get("id")
        if not pos or not cls or oid is None:
            continue
        # sqm position[] is {x, elevation, y}
        x, z, y = float(pos[0]), float(pos[1]), float(pos[2])
        if ang:
            rx, ry, rz = (norm(float(v)) for v in ang)
        else:
            rx = ry = rz = 0.0
        # tilt = how far off upright, ignoring plain yaw (ry)
        tilt = math.hypot(rx, rz)
        rows.append({"id": oid, "cls": cls, "x": x, "y": y, "z": z,
                     "rx": rx, "ry": ry, "rz": rz, "tilt": tilt})
    return rows


def unique_by_xy(rows, tol=1.5):
    """Drop rows that share a class and near-identical x/y with another row.

    The probe resolves an sqm row to the real world object by class + planar position; a stacked
    pair (the prison bug's signature) is unresolvable, so it must never enter the sample.
    """
    out = []
    for r in rows:
        clash = False
        for o in rows:
            if o is r or o["cls"] != r["cls"]:
                continue
            if abs(o["x"] - r["x"]) < tol and abs(o["y"] - r["y"]) < tol:
                clash = True
                break
        if not clash:
            out.append(r)
    return out


def sample(rows, n):
    """Spread over tilt magnitude, then over elevation, and never repeat a class needlessly."""
    tilted = sorted([r for r in rows if r["tilt"] > 0.02], key=lambda r: -r["tilt"])
    flat = [r for r in rows if r["tilt"] <= 0.02]
    picked, seen_cls = [], {}

    def take(pool, want):
        for r in pool:
            if len(picked) >= n or want <= 0:
                return
            c = seen_cls.get(r["cls"], 0)
            if c >= 2:                       # at most two rows per class
                continue
            seen_cls[r["cls"]] = c + 1
            picked.append(r)
            want -= 1

    take(tilted, int(n * 0.55))              # steepest tilts -- where a wrong order shows up
    mid = tilted[len(tilted) // 3: 2 * len(tilted) // 3]
    take(mid, int(n * 0.20))                 # moderate tilts
    flat.sort(key=lambda r: r["z"])
    stride = max(1, len(flat) // max(1, (n - len(picked))))
    take(flat[::stride], n - len(picked))     # flat objects across the elevation range
    return picked


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 60
    rows = collect(SQM)
    print("objects with PositionInfo: %d" % len(rows))

    buckets = [(0.0, 0.02), (0.02, 0.05), (0.05, 0.15), (0.15, 0.4), (0.4, 99)]
    print("tilt distribution (hypot(rx,rz), radians):")
    for lo, hi in buckets:
        c = sum(1 for r in rows if lo <= r["tilt"] < hi)
        print("  %5.2f - %5.2f : %5d" % (lo, hi, c))

    clean = unique_by_xy(rows)
    print("resolvable (no same-class neighbour within 1.5 m): %d" % len(clean))

    picked = sample(clean, n)
    picked.sort(key=lambda r: -r["tilt"])
    print("sampled: %d  (max tilt %.4f rad = %.2f deg)"
          % (len(picked), picked[0]["tilt"], math.degrees(picked[0]["tilt"])))

    lines = [
        "// GENERATED by tools/sqm_frame_sample.py -- do not hand-edit.",
        "// [id, class, world pos [x,y,z] (model centre), sqm angles [rx,ry,rz] radians]",
        "AP_frameRows = [",
    ]
    for r in picked:
        lines.append('    [%d,"%s",[%.4f,%.4f,%.4f],[%.7f,%.7f,%.7f]],'
                     % (r["id"], r["cls"], r["x"], r["y"], r["z"], r["rx"], r["ry"], r["rz"]))
    lines[-1] = lines[-1].rstrip(",")
    lines.append("];")
    open(OUT, "w").write("\n".join(lines) + "\n")
    print("wrote %s" % OUT)


if __name__ == "__main__":
    main()
