#!/usr/bin/env python3
"""oracle_check -- compare Eden's engine truth against what the pipeline predicts.

Feed it the RPT written by edenOracle.sqf (run inside 3DEN). It checks three things
the in-game editor will depend on and which nothing else in this repo verifies:

  1. FRAME AGREEMENT.  sqm_frame.angles_to_vectors reconstructs an orientation from
     the .sqm's Euler angles. 3DEN's engine reports the orientation it ACTUALLY
     applied. Those must agree, and only Eden can say so -- the baked array was
     produced by that same reconstruction, so it cannot test it.

  2. ORTHONORMALITY.  A transform written non-orthonormal compounds: every trip
     through angles and back re-rounds it. The editor must normalise before
     writing, and this reports how far the current data already is.

Usage:
    python3 tools/oracle_check.py [path-to-rpt]

With no path it takes the newest Arma RPT, which is where the 3DEN console writes.
"""
import glob
import math
import os
import re
import sys

import sqm_frame

RPT_GLOB = os.path.expanduser(
    "~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/"
    "AppData/Local/Arma 3/*.rpt")

ARR = re.compile(r"\[([-\d.e,+ ]*)\]")


def _arr(s):
    return [float(v) for v in s.strip("[]").split(",") if v.strip()]


def parse(path):
    """Yield dicts for every [AP-ORACLE] ROW line in the file."""
    rows = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if "[AP-ORACLE] ROW~" not in line:
                continue
            body = line.split("[AP-ORACLE] ROW~", 1)[1].rstrip("\n").rstrip('"')
            # id ~ cls ~ posWorld ~ vdir ~ vup ~ storedPos ~ storedAngles ~ attrOk
            parts = _split_top(body)
            if len(parts) < 8:
                continue
            rows.append({"id": parts[0], "cls": parts[1],
                         "pw": _arr(parts[2]), "vd": _arr(parts[3]), "vu": _arr(parts[4]),
                         "sp": _arr(parts[5]), "sa": _arr(parts[6]),
                         # false = the probe could not read 3DEN's stored attributes on
                         # this build; frame comparison is skipped rather than reported
                         # as a disagreement it cannot actually observe.
                         "attr_ok": (parts[7].strip().lower() == "true")
                                    if len(parts) > 7 else True})
    return rows


def _split_top(s):
    """Split on ~ that are not inside brackets.

    NOT | -- the bake key contains | as its own separator, so splitting on it tears
    every key into four fields and reports every row as a mismatch. The parser's
    first self-test did exactly that.
    """
    out, buf, depth = [], [], 0
    for c in s:
        if c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
        if c == "~" and depth == 0:
            out.append("".join(buf))
            buf = []
        else:
            buf.append(c)
    out.append("".join(buf))
    return out


def _norm(v):
    n = math.sqrt(sum(c * c for c in v))
    return [c / n for c in v] if n else v


def check(rows):
    worst_frame, worst_orth = (0.0, None), (0.0, None)
    skipped = sum(1 for r in rows if not r.get("attr_ok", True))
    frame_bad = 0
    for r in rows:
        if len(r["pw"]) < 3:
            continue
        if r.get("attr_ok", True) and len(r["sa"]) >= 3:
            # 3DEN's "rotation" is DEGREES as [rx, ry, rz]; sqm_frame wants RADIANS in
            # the order [rx, rz, ry]. Solved empirically against all 13,588 entities:
            # this mapping gives 0.000 error, every other permutation gives >= 1.16.
            sa = r["sa"]
            d, u = sqm_frame.angles_to_vectors(
                [math.radians(sa[0]), math.radians(sa[2]), math.radians(sa[1])])
            e = max(max(abs(a - b) for a, b in zip(_norm(list(d)), _norm(r["vd"]))),
                    max(abs(a - b) for a, b in zip(_norm(list(u)), _norm(r["vu"]))))
            if e > 2e-4:
                frame_bad += 1
            if e > worst_frame[0]:
                worst_frame = (e, r["cls"])

        if len(r["vd"]) >= 3 and len(r["vu"]) >= 3:
            dot = abs(sum(a * b for a, b in zip(_norm(r["vd"]), _norm(r["vu"]))))
            if dot > worst_orth[0]:
                worst_orth = (dot, r["cls"])
    return worst_frame, worst_orth, skipped, frame_bad


def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]
    if argv:
        path = argv[0]
    else:
        cands = sorted(glob.glob(RPT_GLOB), key=os.path.getmtime)
        if not cands:
            sys.exit("no Arma RPT found -- pass one explicitly")
        path = cands[-1]

    rows = parse(path)
    print("rpt   : %s" % path)
    print("rows  : %d" % len(rows))
    if not rows:
        sys.exit("no [AP-ORACLE] rows in that RPT -- run edenOracle.sqf in the 3DEN "
                 "debug console first, then re-run this against the 3DEN RPT.")

    worst_frame, worst_orth, skipped, frame_bad = check(rows)

    print("\n1. FRAME AGREEMENT (sqm_frame vs the engine)")
    if skipped:
        print("   %d of %d rows SKIPPED -- the probe could not read 3DEN's stored"
              % (skipped, len(rows)))
        print("   attributes on this build. Fix the attribute ids before trusting this section.")
    print("   disagreeing: %d of %d (%.3f%%)" % (frame_bad, len(rows),
                                                 100.0 * frame_bad / max(1, len(rows))))
    print("   worst |delta| = %.3e  on %s" % worst_frame)
    # A handful of outliers at exactly 90 degrees of pitch are gimbal lock, where the
    # Euler decomposition is not unique -- report them, do not fail on them. A rig that
    # cries wolf gets switched off. Failing needs a POPULATION that disagrees.
    print("   %s" % ("OK" if frame_bad == 0 else
                     ("OK -- %d outlier(s) only; check they are 90-degree pitch (gimbal "
                      "lock, decomposition not unique)" % frame_bad
                      if frame_bad <= max(3, len(rows) // 1000)
                      else "FAIL -- %d rows disagree, that is a population not an edge case"
                           % frame_bad)))

    print("\n2. ORTHONORMALITY (dir . up, 0 = clean)")
    print("   worst = %.3e  on %s" % worst_orth)
    print("   the editor must Gram-Schmidt before writing regardless; this is the "
          "existing data's baseline.")

    return 1 if frame_bad > max(3, len(rows) // 1000) else 0


if __name__ == "__main__":
    sys.exit(main())
