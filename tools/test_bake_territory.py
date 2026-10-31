#!/usr/bin/env python3
"""Tests for bake_territory.py. Script-style: asserts on run, reports via exit code.

The interesting failures here are not "does it parse an sqm" -- sqm_read has its own
tests -- but the two ways this tool could silently produce a WRONG polygon:

  * reading the elevation axis instead of the northing (Eden stores [x, z, y], and
    [x, z] is a perfectly well-formed array of numbers that contains nobody), and
  * baking an incomplete ring, which yields a polygon smaller than the town and a
    territory with a hole in it that nothing would report.

Both are asserted below against a hand-built sqm fragment, so a regression in either
fails here rather than in play.
"""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bake_territory as bt                                        # noqa: E402


def sqm_with(markers):
    """Minimal text-form mission.sqm carrying just the named markers."""
    items = []
    for i, (name, x, elev, y) in enumerate(markers):
        items.append(
            'class Item%d\n'
            '{\n'
            ' dataType="Marker";\n'
            ' position[]={%r,%r,%r};\n'
            ' name="%s";\n'
            ' type="mil_dot";\n'
            ' id=%d;\n'
            '};\n' % (i, x, elev, y, name, 900 + i))
    return ('version=54;\nclass Mission\n{\n class Markers\n {\n  items=%d;\n%s };\n};\n'
            % (len(markers), "".join(items)))


def write_tmp(text, suffix):
    fh = tempfile.NamedTemporaryFile("w", suffix=suffix, delete=False, encoding="utf-8")
    fh.write(text)
    fh.close()
    return fh.name


# Deliberately carries a header comment that CONTAINS the anchor text and a bare
# "[]" -- the exact shape that made the first cut of this tool rewrite a comment
# instead of the data.
CFG = '''/*
    Usage:
        ["byId", "f_neon"]  call AP_fnc_factionCfg  -> the row, or []
        ["f_neon", ...]     is not a real call; it is here to be a decoy.
*/
params [["_mode", "", [""]]];
private _factions = [
    ["f_neon",   "Lightrunners", "aq_terr_neon", "fixer_1",
     "blurb",
     [[1,2],[3,4],[5,6]],
     "Larche"],
    ["f_dock",   "Crusaders",    "aq_terr_dock", "fixer_2",
     "blurb",
     [[7,8],[9,10],[11,12]],
     "Chapoi"],
    ["f_maxsec", "Unaffiliated", "aq_terr_maxsec", "fixer_3",
     "blurb",
     [],
     ""]
];
'''


class TestBakeTerritory(unittest.TestCase):

    def test_reads_northing_not_elevation(self):
        """position[]={x, elevation, y} -- the pair taken must be (x, y)."""
        sqm = write_tmp(sqm_with([
            ("aq_terr_neon_p1", 100.0, 42.5, 200.0),
            ("aq_terr_neon_p2", 300.0, 17.25, 400.0),
            ("aq_terr_neon_p3", 500.0, 99.0, 600.0),
        ]), ".sqm")
        try:
            got = bt.collect(sqm)
        finally:
            os.unlink(sqm)
        self.assertEqual(got["neon"],
                         {1: (100.0, 200.0), 2: (300.0, 400.0), 3: (500.0, 600.0)})

    def test_faction_id_with_underscores_survives(self):
        """f_neon must not be truncated at its own underscore by the name regex."""
        sqm = write_tmp(sqm_with([
            ("aq_terr_f_neon_p1", 1.0, 0.0, 2.0),
            ("aq_terr_f_neon_p2", 3.0, 0.0, 4.0),
            ("aq_terr_f_neon_p3", 5.0, 0.0, 6.0),
        ]), ".sqm")
        try:
            got = bt.collect(sqm)
        finally:
            os.unlink(sqm)
        self.assertIn("f_neon", got)
        self.assertEqual(len(got["f_neon"]), 3)

    def test_incomplete_ring_is_refused(self):
        self.assertIsNone(bt.ordered({1: (0, 0), 2: (1, 1)})[0])
        self.assertIn("at least 3", bt.ordered({1: (0, 0), 2: (1, 1)})[1])

    def test_gap_in_numbering_is_refused(self):
        pts, complaint = bt.ordered({1: (0, 0), 2: (1, 1), 4: (2, 2)})
        self.assertIsNone(pts)
        self.assertIn("contiguous", complaint)
        self.assertIn("p3", complaint)

    def test_rewrites_only_the_named_faction(self):
        cfg = write_tmp(CFG, ".sqf")
        try:
            changes = bt.rewrite(cfg, {"f_dock": [(70.5, 80.5), (90, 100), (110, 120)]})
            out = open(cfg, encoding="utf-8").read()
        finally:
            os.unlink(cfg)
        self.assertEqual(changes, [("f_dock", 3)])
        self.assertIn("[[70.5,80.5],[90,100],[110,120]]", out)
        self.assertIn("[[1,2],[3,4],[5,6]]", out)          # f_neon untouched
        self.assertIn("[],", out)                          # f_maxsec still empty

    def test_rewrite_is_idempotent(self):
        cfg = write_tmp(CFG, ".sqf")
        try:
            pts = [(70.5, 80.5), (90, 100), (110, 120)]
            bt.rewrite(cfg, {"f_dock": pts})
            second = bt.rewrite(cfg, {"f_dock": pts})
        finally:
            os.unlink(cfg)
        self.assertEqual(second, [], "a second bake of the same points must be a no-op")

    def test_empty_polygon_faction_can_be_filled(self):
        """f_maxsec ships with [] -- baking it must replace the empty literal."""
        cfg = write_tmp(CFG, ".sqf")
        try:
            bt.rewrite(cfg, {"f_maxsec": [(1, 1), (2, 2), (3, 3)]})
            out = open(cfg, encoding="utf-8").read()
        finally:
            os.unlink(cfg)
        self.assertIn("[[1,1],[2,2],[3,3]]", out)

    def test_anchor_in_a_comment_is_not_rewritten(self):
        """The header comment above contains both ["f_neon", and a bare []."""
        cfg = write_tmp(CFG, ".sqf")
        try:
            bt.rewrite(cfg, {"f_neon": [(11, 22), (33, 44), (55, 66)]})
            out = open(cfg, encoding="utf-8").read()
        finally:
            os.unlink(cfg)
        head = out[:out.index("params [")]
        self.assertIn("the row, or []", head, "the comment's [] was overwritten")
        self.assertNotIn("[[11,22]", head, "the polygon was written into the comment")
        self.assertIn("[[11,22],[33,44],[55,66]]", out[out.index("private _factions"):])

    def test_unknown_faction_is_skipped_not_crashed(self):
        cfg = write_tmp(CFG, ".sqf")
        try:
            changes = bt.rewrite(cfg, {"f_nonesuch": [(1, 1), (2, 2), (3, 3)]})
            out = open(cfg, encoding="utf-8").read()
        finally:
            os.unlink(cfg)
        self.assertEqual(changes, [])
        self.assertEqual(out, CFG)

    def test_blurb_containing_brackets_does_not_shift_elements(self):
        """A comma or bracket inside a quoted blurb must not split the row."""
        cfg = write_tmp(CFG.replace('"blurb"', '"a blurb, with [brackets] and a comma"'), ".sqf")
        try:
            bt.rewrite(cfg, {"f_dock": [(1, 1), (2, 2), (3, 3)]})
            out = open(cfg, encoding="utf-8").read()
        finally:
            os.unlink(cfg)
        self.assertIn("[[1,1],[2,2],[3,3]]", out)
        self.assertIn("a blurb, with [brackets] and a comma", out)


if __name__ == "__main__":
    unittest.main(verbosity=2)
