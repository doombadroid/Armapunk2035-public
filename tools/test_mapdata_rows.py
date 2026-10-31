# tools/test_mapdata_rows.py
import os
import tempfile
import unittest

import mapdata_rows as mr

SNAPSHOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "deploy",
                        "map_snapshot", "map_objects.sqf")

SAMPLE = ('AP_mapBakedRev = 17;\n'
          'allLocalMapEntities=[["Land_A_F",[1.000,2.000,3.000],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"",false,[],1],\n'
          '// owner comment\n'
          '["Land_B_F",[4.000,5.000,6.000],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"say ""hi""",true,[],2]];\n')

# the v3 shape (mapdb.md D2): a class row with a lod/radius, and a model row with an EMPTY class
SAMPLE_V3 = ('AP_mapSnapshotRev = 11510;\n'
             'allLocalMapEntities=[["Land_A_F",[1.000,2.000,3.000],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"a, ""b""",false,[],1,"",1.000,2,300.0,false],\n'
             '["",[8512.527,3765.000,0.000],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"",false,[],9565,"custom_p3ds\\BridgeStraight.p3d",1.500,0,0.0,true],\n'
             '["Land_C_F",[7.000,8.000,9.000],[[1.0000,0.0000,0.0000],[0.0000,0.0000,1.0000]],"",true,["a,b",[1,2]],3,"",1.000,1,-1.0,false]];\n')


def _tmp(text):
    fd, p = tempfile.mkstemp(suffix=".sqf"); os.close(fd)
    open(p, "w").write(text)
    return p


class TestRead(unittest.TestCase):
    def test_header_rows_gaps_and_ids(self):
        p = _tmp(SAMPLE)
        d = mr.read(p); os.unlink(p)
        self.assertEqual(d.baked_rev, 17)
        self.assertEqual([r.id for r in d.rows], [1, 2])
        self.assertEqual(d.rows[0].gap, "")
        self.assertEqual(d.rows[1].gap, ",\n// owner comment\n")
        self.assertEqual(d.rows[1].init, 'say "hi"')
        self.assertTrue(d.rows[1].is_server)
        self.assertEqual(d.rows[1].vdir, (0.0, 1.0, 0.0))
        self.assertEqual(d.trailer, "];\n")
        # a v2 row reads with the v3 defaults so one consumer serves both shapes
        self.assertEqual([r.shape for r in d.rows], [7, 7])
        self.assertEqual((d.rows[0].model, d.rows[0].scale, d.rows[0].lod, d.rows[0].stream_r, d.rows[0].on_server),
                         ("", 1.0, 1, None, False))

    def test_v3_rows_parse_and_round_trip_byte_exact(self):
        p = _tmp(SAMPLE_V3)
        d = mr.read(p); os.unlink(p)
        self.assertEqual(d.baked_rev, 11510)               # AP_mapSnapshotRev is accepted
        self.assertEqual([r.id for r in d.rows], [1, 9565, 3])
        self.assertEqual([r.shape for r in d.rows], [12, 12, 12])
        a, b, c = d.rows
        self.assertEqual(a.init, 'a, "b"')                 # a comma inside the init does not split the tail
        self.assertEqual((a.lod, a.stream_r), (2, 300.0))
        self.assertEqual(b.cls, "")                         # model rows carry an empty class
        self.assertEqual(b.model, "custom_p3ds\\BridgeStraight.p3d")
        self.assertEqual((b.scale, b.lod, b.stream_r, b.on_server), (1.5, 0, 0.0, True))
        self.assertEqual(c.loadout, '["a,b",[1,2]]')       # a nested loadout is one element
        self.assertIsNone(c.stream_r)                       # -1.0 on the wire = NULL in the table
        # emit reproduces the source, and format_row reproduces every row from its fields
        out = mr.emit(d.header, [(r.gap, r.raw) for r in d.rows], d.trailer)
        self.assertEqual(out, SAMPLE_V3)
        for r in d.rows:
            self.assertEqual(mr.format_row(r.cls, r.pos, r.vdir, r.vup, r.init, r.is_server, r.loadout, r.id,
                                           r.model, r.scale, r.lod, r.stream_r, r.on_server), r.raw)

    def test_real_file_round_trips_byte_exact(self):
        src = open(SNAPSHOT, encoding="utf-8", errors="replace").read()
        d = mr.read(SNAPSHOT)
        # The corpus GROWS with every placement (each in-game placement is a new row). Pin the
        # floor, not the value -- the byte-identity below is the load-bearing assertion.
        self.assertGreaterEqual(len(d.rows), 9469)
        self.assertGreater(d.baked_rev, 0)        # the snapshot carries AP_mapSnapshotRev
        self.assertTrue(all(r.shape == 12 for r in d.rows))   # every row in the v3 shape
        out = mr.emit(d.header, [(r.gap, r.raw) for r in d.rows], d.trailer)
        self.assertEqual(out, src)

    def test_every_row_has_a_unique_positive_id(self):
        d = mr.read(SNAPSHOT)
        ids = [r.id for r in d.rows]
        self.assertTrue(all(isinstance(i, int) and i >= 1 for i in ids))
        self.assertEqual(len(set(ids)), len(ids))


class TestWrite(unittest.TestCase):
    def test_format_row_defaults_to_a_plain_class_row(self):
        self.assertEqual(
            mr.format_row("Land_C_F", (8100.0, 7700.0, 20.5), (0, 1, 0), (0, 0, 1), 'a "b"', False, "", 42),
            '["Land_C_F",[8100.000,7700.000,20.500],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"a ""b""",false,[],42,"",1.000,1,-1.0,false]')

    def test_format_row_model_row(self):
        self.assertEqual(
            mr.format_row("", (8512.527, 3765.0, 0.0), (0, 1, 0), (0, 0, 1), "", False, "", 9565,
                          "custom_p3ds\\BridgeStraight.p3d", 1.5, 0, 0.0, True),
            '["",[8512.527,3765.000,0.000],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"",false,[],9565,"custom_p3ds\\BridgeStraight.p3d",1.500,0,0.0,true]')

    def test_splice_id_into_five_element_row(self):
        raw = '["Land_A_F",[1.000,2.000,3.000],[[0,1,0],[0,0,1]],"",false]'
        self.assertEqual(mr.splice_id(raw, 7), '["Land_A_F",[1.000,2.000,3.000],[[0,1,0],[0,0,1]],"",false,[],7]')

    def test_splice_refuses_a_row_that_already_has_an_id(self):
        with self.assertRaises(ValueError):
            mr.splice_id('["Land_A_F",[1,2,3],[[0,1,0],[0,0,1]],"",false,[],7]', 8)


if __name__ == "__main__":
    unittest.main()
