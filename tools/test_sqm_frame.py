#!/usr/bin/env python3
"""Tests for tools/sqm_frame.py.  Run: python3 tools/test_sqm_frame.py

The two MEASURED cases are real rows read off the running engine (debug/frame_angles.sqf,
2026-07-31). They are the whole point of this file: a round-trip test alone would happily
confirm a convention that is internally consistent and wrong, which is exactly the failure
mode here -- a 180-degree map-wide mis-aim that no self-consistency check can see.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sqm_frame

FAILS = []


def close(a, b, tol=1e-5):
    return all(abs(x - y) <= tol for x, y in zip(a, b))


def check(name, got, want, tol=1e-5):
    if close(got, want, tol):
        print("  ok   %s" % name)
    else:
        FAILS.append(name)
        print("  FAIL %s\n         got  %s\n         want %s" % (name, list(got), list(want)))


# --- measured ground truth: sqm angles[] -> engine vectorDir / vectorUp ---------------
MEASURED = [
    # (id, angles,                              dir,                              up)
    (33817, (-0.111282, 0.000000, 0.094981),
            (0.000000, 0.993815, 0.111053), (-0.094838, -0.110552, 0.989335)),
    (33818, (-0.111282, -1.570796, 0.094981),
            (-0.995493, 0.010532, -0.094251), (-0.094838, -0.110552, 0.989335)),
]

print("measured cases (engine ground truth):")
for oid, ang, want_dir, want_up in MEASURED:
    d, u = sqm_frame.angles_to_vectors(ang)
    check("id %d dir" % oid, d, want_dir)
    check("id %d up" % oid, u, want_up)

print("inverse of the measured cases:")
for oid, ang, want_dir, want_up in MEASURED:
    got = sqm_frame.vectors_to_angles(want_dir, want_up)
    d, u = sqm_frame.angles_to_vectors(got)
    check("id %d inverse->dir" % oid, d, want_dir)
    check("id %d inverse->up" % oid, u, want_up)

# --- gimbal case: the map's steepest object is tilted 90 degrees, where angles[2] = +-pi/2
# and angles[1] stops being recoverable from dir[0]. A naive inverse divides by cos(beta) = 0.
print("gimbal (90-degree tilt):")
for yaw in (0.0, 0.7, -2.5, 3.0):
    ang = (0.0, yaw, -math.pi / 2)
    d, u = sqm_frame.angles_to_vectors(ang)
    got = sqm_frame.vectors_to_angles(d, u)
    d2, u2 = sqm_frame.angles_to_vectors(got)
    check("yaw %.2f dir" % yaw, d2, d)
    check("yaw %.2f up" % yaw, u2, u)

# --- round-trip across the whole range -----------------------------------------------
print("round-trip sweep:")
worst = 0.0
for a0 in (-1.2, -0.3, 0.0, 0.4, 1.1):
    for a1 in (-3.0, -1.5, 0.0, 1.5, 3.0):
        for a2 in (-1.0, 0.0, 0.6):
            d, u = sqm_frame.angles_to_vectors((a0, a1, a2))
            d2, u2 = sqm_frame.angles_to_vectors(sqm_frame.vectors_to_angles(d, u))
            worst = max(worst, max(abs(x - y) for x, y in zip(d, d2)),
                        max(abs(x - y) for x, y in zip(u, u2)))
if worst < 1e-9:
    print("  ok   75 combinations, worst %.2e" % worst)
else:
    FAILS.append("round-trip sweep")
    print("  FAIL round-trip sweep, worst %.2e" % worst)

# --- coordinate reorder --------------------------------------------------------------
print("position reorder:")
check("sqm->world", sqm_frame.SQM_POS_TO_WORLD((4201.9951, 26.866976, 3931.731)),
      (4201.9951, 3931.731, 26.866976))
check("world->sqm", sqm_frame.WORLD_TO_SQM_POS((4201.9951, 3931.731, 26.866976)),
      (4201.9951, 26.866976, 3931.731))

print("\n%d failure(s)" % len(FAILS))
sys.exit(1 if FAILS else 0)
