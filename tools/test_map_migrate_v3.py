# tools/test_map_migrate_v3.py -- the pure parsers of the v3 migration (no database).
import textwrap
import unittest

import map_migrate_v3 as M

FIX = textwrap.dedent('''
    private _MALDEN = getMissionPath "custom_p3ds\\\\";
    // comment mentioning createSimpleObject must not count
    _o = createSimpleObject [_MALDEN + "Bank.p3d", [7051.480, 10254.300, 71.500], true]; _o setDir 90; _o setObjectScale 1;
    _o = createSimpleObject [_MALDEN + "BridgeMiddle.p3d",   [8912.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1; // The Middle Piece
    _o = createSimpleObject [_MALDEN + "FederalReserveSign.p3d", [7000.1, 7000.2, 100.3], true]; _o setDir 45.5; _o setObjectScale 1.5;
''')


class TestPlacements(unittest.TestCase):
    def test_counts_and_values(self):
        rows = M.parse_placements(FIX)
        self.assertEqual([r["model"] for r in rows],
                         ["custom_p3ds\\Bank.p3d", "custom_p3ds\\BridgeMiddle.p3d", "custom_p3ds\\FederalReserveSign.p3d"])
        self.assertEqual(rows[0]["x"], 7051.480)
        self.assertEqual(rows[0]["dir"], 90)
        self.assertEqual(rows[1]["z"], 0)
        self.assertEqual(rows[2]["scale"], 1.5)

    def test_partial_parse_aborts(self):
        bad = FIX + '\n_o = createSimpleObject [_MALDEN + "X.p3d", [1,2], true];\n'
        with self.assertRaises(SystemExit):
            M.parse_placements(bad)

    def test_dir_to_vectors(self):
        d, u = M.dir_to_vectors(90)
        self.assertAlmostEqual(d[0], 1.0)
        self.assertAlmostEqual(d[1], 0.0)
        self.assertEqual(d[2], 0.0)
        self.assertEqual(u, (0, 0, 1))
        d0, _ = M.dir_to_vectors(0)
        self.assertAlmostEqual(d0[1], 1.0)


class TestTiers(unittest.TestCase):
    def test_lists_and_updates(self):
        src = 'private _shitObjects = ["A", "B"];\nprivate _decorObjects = ["A", "C", "D"]; {\n'
        decor, shit = M.decor_lists(src)
        self.assertEqual(decor, ["A", "C", "D"])
        self.assertEqual(shit, ["A", "B"])
        self.assertEqual(M.tier_updates(decor, shit), {3: ["A"], 2: ["C", "D"]})

    def test_frozen_lists_match_the_asserted_counts(self):
        decor, shit = M.decor_lists()
        self.assertEqual((len(decor), len(shit)), (M.EXPECT_DECOR, M.EXPECT_SHIT))
        self.assertTrue(all(c in decor for c in shit))   # every never-spawned class is a decor class


class TestMarker(unittest.TestCase):
    def test_jail_marker_is_in_the_shipped_sqm(self):
        x, y = M.marker_pos(M.SQM, M.JAIL_MARKER)
        self.assertGreater(x, 9000); self.assertLess(x, 10500)
        self.assertGreater(y, 3000); self.assertLess(y, 4500)


if __name__ == "__main__":
    unittest.main()
