# tools/test_map_import.py
import unittest

import map_import
import mapdata_rows as mr


class TestParams(unittest.TestCase):
    def test_row_becomes_insert_params_in_order(self):
        r = mr.Row("Land_A_F", (1.0, 2.0, 3.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0),
                   'say "hi"', True, "", None, "", "")
        p = map_import.rows_to_params([r], "Malden")
        self.assertEqual(p, [("Malden", "Land_A_F", 1.0, 2.0, 3.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0,
                              'say "hi"', True, None, "AP_MAPDATA", "migration")])

    def test_refuses_rows_that_already_have_ids(self):
        r = mr.Row("Land_A_F", (1, 2, 3), (0, 1, 0), (0, 0, 1), "", False, "", 5, "", "")
        with self.assertRaises(ValueError):
            map_import.rows_to_params([r], "Malden")


if __name__ == "__main__":
    unittest.main()
