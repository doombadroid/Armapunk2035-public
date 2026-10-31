#!/usr/bin/env python3
"""Measured door PARK ANGLES — shared by gen_lux_doors.py and gen_skyscraper_doors.py.

A leaf parked at the manifest's 100 deg sits AJAR: ten degrees past
perpendicular, jutting into the stairwell landing or the room (the owner has
now reported this on both towers). Flat against the wall (~165 deg) is what a
held-open door looks like — but a few doors sit next to a return wall that a
165 deg leaf would clip.

So the angle is MEASURED, not assumed: swing each door through candidate
angles against the tower's own Geometry LOD and keep the flattest one that
stays clear. Re-running the generator after a model re-drop re-measures, so a
moved wall can never silently leave a leaf buried in it.

The swing SIDE is the caller's business (the sign it passes in); this module
only answers "how far can it go that way".
"""
import glob
import json
import math
import os
import sys

sys.path.insert(0, '/home/timb/blender_work')
import mlod_rw

# Owner call (b0355): every door opens to 100 degrees, not flat to the wall.
# 165 parked the leaf against the wall but read as a door that had been torn
# open; 100 is a door someone walked through. The measured fallback stays for
# any opening whose surroundings cannot take the full swing.
CANDIDATES = (100.0, 80.0, 60.0)
BODY_LO, BODY_HI = 0.4, 1.6      # torso band above the door sill
TIP_EXTEND = 0.04                # leaf overhangs its opening slightly


def geometry_boxes(p3d):
    """AABB per Geometry component of the tower."""
    _ver, lods = mlod_rw.parse(p3d)
    geo = min(lods, key=lambda l: abs(l['res'] - 1e13))
    npt = len(geo['pts'])
    out = []
    for t in geo['taggs']:
        if t['name'].startswith(b'#'):
            continue
        d = t['data']
        ps = [i for i in range(npt) if d[i]]
        if not ps:
            continue
        xs = [geo['pts'][i][0] for i in ps]
        ys = [geo['pts'][i][1] for i in ps]
        zs = [geo['pts'][i][2] for i in ps]
        out.append((min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
    return out


def _blocked(door, angle, comps):
    """True if the leaf swung to `angle` (signed) intersects tower geometry."""
    b = door['box']
    ax, az = door['axis']['x'], door['axis']['z']
    along_x = (b[1] - b[0]) > (b[5] - b[4])
    span = ((b[1] - b[0]) if along_x else (b[5] - b[4])) + TIP_EXTEND
    if along_x:
        yaw = 0.0 if abs(b[0] - ax) < abs(b[1] - ax) else 180.0
    else:
        yaw = -90.0 if abs(b[5] - az) > abs(b[4] - az) else 90.0
    d = math.radians(yaw + angle)
    tip = (ax + span * math.cos(d), az - span * math.sin(d))
    wall_x, wall_z = (b[0] + b[1]) / 2, (b[4] + b[5]) / 2
    for k in range(1, 13):
        t = k / 12
        px, pz = ax + (tip[0] - ax) * t, az + (tip[1] - az) * t
        for (x0, x1, y0, y1, z0, z1) in comps:
            if not (x0 - 0.01 < px < x1 + 0.01 and z0 - 0.01 < pz < z1 + 0.01):
                continue
            if not (y0 < b[2] + BODY_HI and y1 > b[2] + BODY_LO):
                continue
            # the door's own wall plane is not an obstacle
            if along_x and (z1 - z0) < 0.6 and z0 - 0.15 < wall_z < z1 + 0.15:
                continue
            if (not along_x) and (x1 - x0) < 0.6 and x0 - 0.15 < wall_x < x1 + 0.15:
                continue
            return True
    return False


def park_angles(doors, p3d, sign):
    """{door id: signed park angle}. `sign` is +1 to keep the manifest's swing
    side, -1 to swing the other way."""
    comps = geometry_boxes(p3d)
    out = {}
    for d in doors:
        side = sign * (1 if d['angleDeg'] > 0 else -1)
        for mag in CANDIDATES:
            if not _blocked(d, side * mag, comps):
                out[d['id']] = side * mag
                break
        else:
            out[d['id']] = side * CANDIDATES[-1]
    return out


def newest(pattern):
    """Newest matching tower p3d in the shipped mission."""
    hits = sorted(glob.glob(pattern), key=os.path.getmtime)
    if not hits:
        sys.exit('no tower p3d matching ' + pattern)
    return hits[-1]
