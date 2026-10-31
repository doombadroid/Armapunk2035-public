# tools/test_map_cell_key.py -- the SQL cell rule and the SQF cell rule share their constants.
import os
import re
import unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SQL = os.path.join(ROOT, "deploy", "postgis.sql")
CFG = os.path.join(ROOT, "mission", "Armapunk2035.Malden", "core", "functions", "fn_mapCfg.sqf")


def sqf_constants():
    s = open(CFG, encoding="utf-8").read()
    return {k: int(v) for k, v in re.findall(r'\["(cell|far)",\s*(\d+)\]', s)}


def sql_constants():
    s = open(SQL, encoding="utf-8").read()
    body = s[s.index("map_cell_key"):s.index("$$;", s.index("map_cell_key"))]
    far = int(re.search(r"> (\d+) THEN 'far'", body).group(1))
    cell = set(int(v) for v in re.findall(r"/ (\d+)\)", body))
    assert len(cell) == 1, cell
    return {"cell": cell.pop(), "far": far}


class TestCellKeyParity(unittest.TestCase):
    def test_constants_match(self):
        self.assertEqual(sqf_constants(), sql_constants())

    def test_rule_in_python_matches_both(self):
        c = sqf_constants()
        def key(x, y, r):
            if r is None: r = -1
            if r == 0 or r > c["far"]: return "far"
            return "%d_%d" % (x // c["cell"], y // c["cell"])
        self.assertEqual(key(7500, 10500, None), "7_10")
        self.assertEqual(key(7500, 10500, 0), "far")
        self.assertEqual(key(7500, 10500, 2500), "far")
        self.assertEqual(key(999.9, 1000.0, 1500), "0_1")


if __name__ == "__main__":
    unittest.main()
