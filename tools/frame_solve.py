#!/usr/bin/env python3
"""Solve the sqm angles[] -> vectorDir/vectorUp convention from measured ground truth.

Input is the [FRAMEANG] ROW lines that debug/frame_angles.sqf writes: each carries the sqm's own
angles[] alongside the engine's vectorDir/vectorUp for the very object the engine built from that
row. So the convention is not guessed -- it is the one that reproduces the measurements.

Every plausible convention is tried -- which axis each angles[] component turns about (6), the order
they are applied in (6), and every sign combination (8) = 288 candidates. Searching the axis
ASSIGNMENT matters and is not obvious: the sqm reorders coordinates (position[] is {x, elevation, y},
Z-up), and angles[] is reordered the same way, so angles[1] is yaw about the world up axis. A first
version of this solver held the assignment fixed and could not fit a single yawed row.

Candidates rank by HOW MANY rows they reproduce exactly, not by their worst row: one mis-resolved
object pins every candidate's worst-row error at ~2.0 (the maximum possible for unit vectors) and
hides a convention that fits everything else.

    python3 tools/frame_solve.py [logfile]

Also checks the inverse (vectors -> angles), because option D writes the sqm as well as reads it.

RESULT (measured 2026-07-31, 43 rows, 14 tilted / 39 yawed, max tilt 34 deg):

    R = Rx(-angles[0]) . Ry(-angles[2]) . Rz(-angles[1])
    vectorDir = R * (0,1,0)        vectorUp = R * (0,0,1)

  * reproduces 43/43 rows to 8.5e-7; the next-best of the 288 candidates fits only 30/43
  * cross-checked against the engine's own getDir independently: worst bearing error 4.0e-5 deg
  * inverse (vectors -> angles) round-trips to 4.6e-7, so writing the sqm is exact too
  * position, over the same 43 rows: max |getPosWorld - sqm position[]| = 6.1e-5 m -- the sqm
    stores the MODEL CENTRE, so no terrain height is ever needed to place an object from it

Together those close the frame question: mission.sqm converts to and from the spawn arrays entirely
offline, with no engine round-trip.
"""
import itertools
import math
import re
import sys

LOG = sys.argv[1] if len(sys.argv) > 1 else "/home/timb/arma3server_dev/loonydev.log"

ROW = re.compile(
    r"\[FRAMEANG\] ROW id=(\d+) cls=(\S+) "
    r"sqmpos=([-\d.,]+) sqmang=([-\d.,]+) pos=([-\d.,]+) dir=([-\d.,]+) up=([-\d.,]+)")


def v(s):
    return [float(x) for x in s.split(",")]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def apply(m, x):
    return [sum(m[i][k] * x[k] for k in range(3)) for i in range(3)]


def rx(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


AX = {"X": rx, "Y": ry, "Z": rz}
IDX = {"X": 0, "Y": 1, "Z": 2}


def predict(assign, order, signs, ang):
    """dir/up for one candidate convention. Arma: forward=+Y, up=+Z.

    `assign[i]` is the axis that angles[i] rotates about, and `order` is the sequence of angle
    INDICES to apply. Both are searched, because the sqm reorders coordinates -- position[] is
    {x, elevation, y}, i.e. Z-up -- so there is no reason to assume angles[] is not reordered the
    same way. Fixing angle-index-to-axis and permuting only the application order was the first
    version of this solver, and it could not fit a single yawed row.
    """
    m = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    for i in order:
        m = mul(m, AX[assign[i]](signs[i] * ang[i]))
    return apply(m, [0, 1, 0]), apply(m, [0, 0, 1])


def err(a, b):
    return max(abs(a[i] - b[i]) for i in range(3))


def main():
    rows = []
    for line in open(LOG, errors="replace"):
        m = ROW.search(line)
        if m:
            rows.append({"id": int(m.group(1)), "cls": m.group(2), "sqmpos": v(m.group(3)),
                         "ang": v(m.group(4)), "pos": v(m.group(5)),
                         "dir": v(m.group(6)), "up": v(m.group(7))})
    # the probe re-runs on every server boot; keep only the newest block
    seen, uniq = set(), []
    for r in reversed(rows):
        if r["id"] not in seen:
            seen.add(r["id"])
            uniq.append(r)
    rows = uniq
    if not rows:
        sys.exit("no [FRAMEANG] ROW lines in %s" % LOG)

    tilted = [r for r in rows if math.hypot(r["ang"][0], r["ang"][2]) > 0.02]
    yawed = [r for r in rows if abs(r["ang"][1]) > 0.02]
    print("rows=%d  tilted=%d  yawed=%d" % (len(rows), len(tilted), len(yawed)))
    if len(tilted) < 3 or len(yawed) < 3:
        print("WARNING: thin sample -- a convention can fit by luck. Want >=3 of each.")

    # position datum, re-checked at sample scale
    pe = max(max(abs(r["pos"][i] - r["sqmpos"][i]) for i in range(3)) for r in rows)
    print("position: max |getPosWorld - sqm position[]| = %.6f m across %d rows" % (pe, len(rows)))

    # Rank by HOW MANY rows a convention reproduces exactly, not by its worst row. A single
    # mis-resolved object (the probe matches by class + position, so a near neighbour can be picked
    # up) pins every candidate's worst-row error at ~2.0 -- the maximum possible for unit vectors --
    # and hides a convention that fits everything else perfectly. Fit count separates "the
    # convention is wrong" from "one row is bad data"; the outliers are then reported, not averaged
    # away, because a real systematic error would show up as many outliers, not one.
    TOL = 1e-4
    results = []
    for assign in itertools.permutations("XYZ"):
        for order in itertools.permutations((0, 1, 2)):
            for signs in itertools.product((1, -1), repeat=3):
                errs = []
                for r in rows:
                    pd, pu = predict(assign, order, signs, r["ang"])
                    errs.append((max(err(pd, r["dir"]), err(pu, r["up"])), r["id"]))
                fits = [e for e in errs if e[0] < TOL]
                worst_fit = max((e[0] for e in fits), default=9.9)
                results.append((len(fits), -worst_fit, assign, order, signs, errs))
    results.sort(key=lambda t: (-t[0], -t[1]))

    def label(assign, order, signs):
        return "angles[%s] about %s, applied %s, signs(%+d,%+d,%+d)" % (
            "".join(str(i) for i in range(3)), "".join(assign),
            "".join(str(i) for i in order), signs[0], signs[1], signs[2])

    print("\ntop candidates (rows reproduced exactly, out of %d):" % len(rows))
    for fits, nw, assign, order, signs, _ in results[:5]:
        print("  fits=%2d/%d  worst-fit=%.8f  %s" % (fits, len(rows), -nw, label(assign, order, signs)))

    fits, nw, assign, order, signs, errs = results[0]
    runner = results[1][0] if len(results) > 1 else 0
    outliers = sorted([e for e in errs if e[0] >= TOL], reverse=True)
    print("\nWINNER: %s" % label(assign, order, signs))
    print("  reproduces %d/%d rows to <%g   (next-best convention: %d/%d)"
          % (fits, len(rows), TOL, runner, len(rows)))
    print("  worst error among the rows it fits: %.8f" % -nw)
    if outliers:
        print("  outliers (%d): %s" % (len(outliers),
              ", ".join("id %d err %.3f" % (i, e) for e, i in outliers[:6])))
    byid = {r["id"]: r for r in rows}
    for e, i in outliers[:3]:
        r = byid[i]
        print("     id %d %s  ang=%s" % (i, r["cls"], ["%.4f" % a for a in r["ang"]]))

    if fits == len(rows):
        print("  VERDICT: exact on every row -- sqm angles[] convert offline, no engine needed.")
    elif fits >= len(rows) - 3 and runner < fits - 5:
        print("  VERDICT: exact on all but %d row(s), and no rival convention comes close."
              % len(outliers))
        print("           Convention is proven; the outliers are resolution failures, not frame")
        print("           errors -- confirm each is a mis-resolved object before relying on this.")
    else:
        print("  VERDICT: NOT established. Do not build the offline path on this.")

    # inverse: vectors -> angles, needed because option D writes the sqm too
    print("\ninverse check (dir/up -> angles -> dir/up):")
    bad = 0.0
    for r in rows:
        a = solve_angles(assign, order, signs, r["dir"], r["up"])
        pd, pu = predict(assign, order, signs, a)
        bad = max(bad, err(pd, r["dir"]), err(pu, r["up"]))
    print("  worst round-trip component error: %.8f" % bad)
    print("  %s" % ("exact -- writing the sqm is safe too."
                    if bad < 1e-4 else "NOT exact -- the write direction needs the engine."))


def solve_angles(assign, order, signs, d, u):
    """Recover angles[] numerically. Cheap and exact enough: the forward map is smooth and we only
    need it to prove the round-trip, so a coarse-to-fine search beats hand-deriving six inverses."""
    best = [0.0, 0.0, 0.0]
    step = math.pi
    while step > 1e-9:
        improved = True
        while improved:
            improved = False
            for i in range(3):
                for delta in (step, -step):
                    trial = list(best)
                    trial[i] += delta
                    pd, pu = predict(assign, order, signs, trial)
                    cd, cu = predict(assign, order, signs, best)
                    if max(err(pd, d), err(pu, u)) < max(err(cd, d), err(cu, u)) - 1e-12:
                        best = trial
                        improved = True
        step *= 0.5
    return best


if __name__ == "__main__":
    main()
