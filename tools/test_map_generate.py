# tools/test_map_generate.py
import unittest

import map_generate as mg
import mapdata_rows as mr


def row(rid, cls="Land_A_F", gap=",\n", raw=None, shape=12):
    if raw is None:
        raw = mr.format_row(cls, (1.0, 2.0, 3.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), "", False, "", rid)
    return mr.Row(cls, (1.0, 2.0, 3.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), "", False, "", rid, raw, gap,
                  shape=shape)


def db(rid, rev, cls="Land_A_F", deleted=False, x=1.0, **v3):
    d = {"classname": cls, "x": x, "y": 2.0, "z": 3.0, "vdir": (0.0, 1.0, 0.0), "vup": (0.0, 0.0, 1.0),
         "init": "", "is_server": False, "loadout": "", "deleted": deleted, "rev": rev,
         "model": "", "scale": 1.0, "lod": 1, "stream_r": None, "on_server": False}
    d.update(v3)
    return d


class TestPlan(unittest.TestCase):
    def test_unchanged_rows_are_emitted_verbatim(self):
        doc = mr.Doc("AP_mapSnapshotRev = 5;\n", [row(1, gap=""), row(2)], "];\n", 5)
        pieces, st = mg.plan(doc, {1: db(1, 3), 2: db(2, 5)}, 9)
        self.assertEqual([p[1] for p in pieces], [doc.rows[0].raw, doc.rows[1].raw])
        self.assertEqual(st, {"kept": 2, "changed": 0, "dropped": 0, "added": 0})

    def test_changed_row_is_reformatted_from_the_table(self):
        doc = mr.Doc("AP_mapSnapshotRev = 5;\n", [row(1, gap="")], "];\n", 5)
        pieces, st = mg.plan(doc, {1: db(1, 7, x=9.0)}, 9)
        self.assertIn("[9.000,2.000,3.000]", pieces[0][1])
        self.assertEqual(st["changed"], 1)

    def test_v2_row_is_rewritten_in_the_v3_shape_even_when_untouched(self):
        # the one-time full diff: an old 7-element row is not kept verbatim
        v2raw = '["Land_A_F",[1.000,2.000,3.000],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"",false,[],1]'
        doc = mr.Doc("AP_mapBakedRev = 5;\n", [row(1, gap="", raw=v2raw, shape=7)], "];\n", 5)
        pieces, st = mg.plan(doc, {1: db(1, 3, lod=2, stream_r=300.0)}, 9)
        self.assertEqual(pieces[0][1], v2raw[:-1] + ',"",1.000,2,300.0,false]')
        self.assertEqual(st, {"kept": 0, "changed": 1, "dropped": 0, "added": 0})

    def test_model_row_carries_the_v3_columns(self):
        doc = mr.Doc("AP_mapSnapshotRev = 5;\n", [], "];\n", 5)
        pieces, st = mg.plan(doc, {9565: db(9565, 6, cls="", model="custom_p3ds\\Bank.p3d", scale=1.5,
                                            lod=0, stream_r=0.0, on_server=True)}, 9)
        self.assertEqual(pieces[0][1],
                         '["",[1.000,2.000,3.000],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"",false,[],9565,'
                         '"custom_p3ds\\Bank.p3d",1.500,0,0.0,true]')
        self.assertEqual(st["added"], 1)

    def test_deleted_and_purged_rows_are_dropped_with_their_gap(self):
        doc = mr.Doc("AP_mapSnapshotRev = 5;\n", [row(1, gap=""), row(2, gap=",\n// c\n"), row(3)], "];\n", 5)
        pieces, st = mg.plan(doc, {1: db(1, 5, deleted=True), 3: db(3, 5)}, 9)   # 2 purged, 1 deleted
        self.assertEqual(len(pieces), 1)
        self.assertEqual(pieces[0][1], doc.rows[2].raw)
        self.assertEqual(st["dropped"], 2)

    def test_first_survivor_loses_its_leading_comma(self):
        doc = mr.Doc("AP_mapSnapshotRev = 5;\n", [row(1, gap=""), row(2)], "];\n", 5)
        pieces, _ = mg.plan(doc, {2: db(2, 5)}, 9)
        out = mr.emit("H\n", pieces, "];\n")
        self.assertEqual(out, "H\nallLocalMapEntities=[" + doc.rows[1].raw + "];\n")

    def test_new_table_rows_are_appended(self):
        doc = mr.Doc("AP_mapSnapshotRev = 5;\n", [row(1, gap="")], "];\n", 5)
        pieces, st = mg.plan(doc, {1: db(1, 5), 2: db(2, 8, cls="Land_New_F")}, 9)
        self.assertEqual(len(pieces), 2)
        self.assertEqual(pieces[1][0], ",\n")
        self.assertIn('"Land_New_F"', pieces[1][1])
        self.assertEqual(st["added"], 1)

    def test_missing_snapshot_is_generated_from_scratch(self):
        pieces, st = mg.plan(mg.EMPTY, {1: db(1, 2), 2: db(2, 3)}, 9)
        out = mr.emit(mg.HEADER % 9, pieces, mg.EMPTY.trailer)
        self.assertTrue(out.startswith("AP_mapSnapshotRev = 9;\nallLocalMapEntities=[[\"Land_A_F\""))
        self.assertTrue(out.endswith("]];\n"))
        self.assertEqual(st, {"kept": 0, "changed": 0, "dropped": 0, "added": 2})


if __name__ == "__main__":
    unittest.main()
