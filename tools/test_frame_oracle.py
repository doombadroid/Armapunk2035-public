#!/usr/bin/env python3
"""Frame oracle -- offline half.

The in-game editor's only real output is [pos_world, [vectorDir, vectorUp]]. Getting
that wrong is invisible until objects sit centimetres into the pavement, so the
conversion between Arma's vector pair and the .sqm's Euler angles has to be exact
BEFORE any gizmo is built on top of it.

This tests sqm_frame's angles<->vectors pair against every real row in the map
snapshot -- 9469 of them, including the 326 tilted entities that are the hard cases --
rather than against invented inputs. No game required; the runtime half of the
oracle (Eden's own engine as truth) is edenOracle.sqf.

Run: python3 tools/test_frame_oracle.py
"""
import math
import os
import re
import unittest

import sqm_frame

# The committed snapshot of map_objects (mapdb.md D7) -- the same rows the server serves,
# outside the mission so the PBO ships none of them.
MAPDATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "deploy",
                       "map_snapshot", "map_objects.sqf")

# ["Class",[x,y,z],[[dx,dy,dz],[ux,uy,uz]],...   (the class is EMPTY on a custom-model row)
ROW = re.compile(
    r'\["([^"]*)",\[(-?[\d.]+),(-?[\d.]+),(-?[\d.]+)\],'
    r'\[\[(-?[\d.eE+-]+),(-?[\d.eE+-]+),(-?[\d.eE+-]+)\],'
    r'\[(-?[\d.eE+-]+),(-?[\d.eE+-]+),(-?[\d.eE+-]+)\]\]')


def rows():
    with open(MAPDATA, encoding="utf-8", errors="replace") as fh:
        src = fh.read()
    for m in ROW.finditer(src):
        g = m.groups()
        yield (g[0],
               tuple(float(v) for v in g[1:4]),
               tuple(float(v) for v in g[4:7]),
               tuple(float(v) for v in g[7:10]))


def _norm(v):
    n = math.sqrt(sum(c * c for c in v))
    return tuple(c / n for c in v) if n else v


def orthonormalise(vdir, vup):
    """The rule the in-game editor must follow before writing a transform.

    Gram-Schmidt: normalise dir, project up off it, normalise. A pair written
    non-orthonormal is not merely imprecise -- it compounds, because every trip
    through angles and back re-rounds it.
    """
    d = _norm(vdir)
    dot = sum(a * b for a, b in zip(d, vup))
    return d, _norm(tuple(uc - dot * dc for uc, dc in zip(vup, d)))


def _maxdiff(a, b):
    return max(abs(x - y) for x, y in zip(a, b))


class TestFrameOracle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = list(rows())

    def test_the_corpus_is_the_real_map(self):
        # grows with every pack; pin the floor, not the value
        self.assertGreaterEqual(len(self.rows), 9384)

    def test_conversion_is_exact_on_orthonormal_input(self):
        """vectors -> angles -> vectors, with the storage quantum removed first.

        THIS is the test of sqm_frame itself. Measured: max error 1.3e-15 across all
        9384 rows -- the conversion is exact to double precision, tilted rows included.
        If this ever exceeds 1e-12 the math is wrong, not the data.
        """
        worst, worst_row = 0.0, None
        for (cls, _pos, vdir, vup) in self.rows:
            d, u = orthonormalise(vdir, vup)
            ang = sqm_frame.vectors_to_angles(d, u)
            d2, u2 = sqm_frame.angles_to_vectors(ang)
            e = max(_maxdiff(d, _norm(d2)), _maxdiff(u, _norm(u2)))
            if e > worst:
                worst, worst_row = e, cls
        self.assertLess(worst, 1e-12,
                        "worst error %.3e on %s -- sqm_frame's math is wrong" % (worst, worst_row))

    def test_round_trip_as_stored_stays_within_the_storage_quantum(self):
        """The same round trip on the raw 4-decimal values.

        Rows are written with %.4f, so a stored pair is not exactly orthonormal --
        the worst in this map has |vdir| = 1.0000191 and dir.up = 6.9e-05. The error
        that produces is the STORAGE quantum, not a conversion fault, and it is why
        the editor must orthonormalise before writing: a non-orthonormal row
        accumulates error on every round trip through the pipeline.
        """
        worst, worst_row = 0.0, None
        for (cls, _pos, vdir, vup) in self.rows:
            ang = sqm_frame.vectors_to_angles(vdir, vup)
            d2, u2 = sqm_frame.angles_to_vectors(ang)
            e = max(_maxdiff(_norm(vdir), _norm(d2)), _maxdiff(_norm(vup), _norm(u2)))
            if e > worst:
                worst, worst_row = e, cls
        self.assertLess(worst, 2e-4,
                        "worst error %.3e on %s exceeds the 1e-4 storage quantum -- that is "
                        "no longer explainable as rounding" % (worst, worst_row))

    def test_orthonormalise_fixes_the_worst_stored_row(self):
        """The rule the editor will follow, pinned."""
        worst = max(self.rows,
                    key=lambda r: abs(sum(a * b for a, b in zip(_norm(r[2]), _norm(r[3])))))
        d, u = orthonormalise(worst[2], worst[3])
        self.assertAlmostEqual(math.sqrt(sum(c * c for c in d)), 1.0, places=12)
        self.assertAlmostEqual(math.sqrt(sum(c * c for c in u)), 1.0, places=12)
        self.assertAlmostEqual(sum(a * b for a, b in zip(d, u)), 0.0, places=12)

    def test_tilted_entities_are_actually_present(self):
        """The hard cases must be IN the corpus, or the test above proves little."""
        tilted = [r for r in self.rows if abs(_norm(r[3])[2]) < 0.9999]
        self.assertGreater(len(tilted), 100,
                           "only %d tilted rows found -- the corpus is too flat to be a "
                           "meaningful oracle" % len(tilted))

    def test_vectors_are_unit_and_orthogonal(self):
        """A non-orthonormal pair means the map itself carries a bad transform, which
        the editor would faithfully preserve and no gizmo test would ever catch."""
        bad_len, bad_orth = [], []
        for (cls, _pos, vdir, vup) in self.rows:
            for v in (vdir, vup):
                if abs(math.sqrt(sum(c * c for c in v)) - 1.0) > 1e-3:
                    bad_len.append(cls)
            if abs(sum(a * b for a, b in zip(_norm(vdir), _norm(vup)))) > 1e-3:
                bad_orth.append(cls)
        self.assertEqual(bad_len, [], "%d rows carry a non-unit vector" % len(bad_len))
        self.assertEqual(bad_orth, [], "%d rows carry non-orthogonal dir/up" % len(bad_orth))


if __name__ == "__main__":
    unittest.main(verbosity=2)
