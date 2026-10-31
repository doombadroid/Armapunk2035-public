#!/usr/bin/env python3
"""Conversion between mission.sqm's stored transform and Arma's runtime transform.

MEASURED, not assumed (debug/frame_angles.sqf + tools/frame_solve.py, 2026-07-31, 43 rows):

    position[] = {x, elevation, y}, holding the MODEL CENTRE -- the getPosWorld frame.
    M   = Rx(-angles[0]) . Ry(-angles[2]) . Rz(-angles[1])
    dir = M*(0,1,0)      up = M*(0,0,1)

angles[] is reordered exactly like position[]: angles[1] is yaw about the world UP axis, NOT
about the game's Y axis. Holding that assumption fixed fits zero yawed rows -- a silent
180-degree mis-aim of the whole map -- which is why this lives in one tested module and is
never re-derived at a call site.

Expanding M gives the columns used below:
    dir = (-cb*sg,  ca*cg - sa*sb*sg,  sa*cg + ca*sb*sg)
    up  = ( sb,    -sa*cb,             ca*cb          )
where a = -angles[0], b = -angles[2], g = -angles[1].
"""
import math


def _rx(t):
    c, s = math.cos(t), math.sin(t)
    return ((1, 0, 0), (0, c, -s), (0, s, c))


def _ry(t):
    c, s = math.cos(t), math.sin(t)
    return ((c, 0, s), (0, 1, 0), (-s, 0, c))


def _rz(t):
    c, s = math.cos(t), math.sin(t)
    return ((c, -s, 0), (s, c, 0), (0, 0, 1))


def _mul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3))
                 for i in range(3))


def _col(m, j):
    return (m[0][j], m[1][j], m[2][j])


def angles_to_vectors(angles):
    """sqm angles[] -> (vectorDir, vectorUp)."""
    a0, a1, a2 = (float(v) for v in angles)
    m = _mul(_mul(_rx(-a0), _ry(-a2)), _rz(-a1))
    return _col(m, 1), _col(m, 2)


def vectors_to_angles(vdir, vup):
    """(vectorDir, vectorUp) -> sqm angles[]. Closed form; stable at 90-degree tilt."""
    ux, uy, uz = (float(v) for v in vup)
    dx, dy, dz = (float(v) for v in vdir)

    b = math.asin(max(-1.0, min(1.0, ux)))          # up[0] = sin(b)
    a = math.atan2(-uy, uz)                          # up = (sb, -sa*cb, ca*cb)
    ca, sa = math.cos(a), math.sin(a)
    cb, sb = math.cos(b), math.sin(b)

    # cos(g) is rotation-invariant in a and needs no division:
    #   ca*dir[1] + sa*dir[2] = cg
    cg = ca * dy + sa * dz
    # sin(g) two ways; pick whichever denominator is furthest from zero, so the 90-degree
    # tilt case (cb -> 0, where dir[0] carries no yaw information) stays well conditioned.
    if abs(cb) >= abs(sb):
        sg = -dx / cb
    else:
        sg = (-sa * dy + ca * dz) / sb               # = sb*sg / sb
    g = math.atan2(sg, cg)

    return (-a, -g, -b)


def SQM_POS_TO_WORLD(position):
    """sqm position[] {x, elevation, y} -> world [x, y, z]."""
    x, elev, y = (float(v) for v in position)
    return (x, y, elev)


def WORLD_TO_SQM_POS(world):
    """world [x, y, z] -> sqm position[] {x, elevation, y}."""
    x, y, z = (float(v) for v in world)
    return (x, z, y)
