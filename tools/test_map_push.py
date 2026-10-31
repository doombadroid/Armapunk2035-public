# tools/test_map_push.py
import unittest

import map_push

BANK = "custom_p3ds\\Bank.p3d"


def ent(ap_id, cls="Land_A_F", x=1.0, init="", desc="", lod=None, stream_r=None):
    return {"ap_id": ap_id, "cls": cls, "world": (x, 2.0, 3.0), "dir": (0.0, 1.0, 0.0), "up": (0.0, 0.0, 1.0),
            "init": init, "desc": desc, "lod": lod, "stream_r": stream_r}


def anchor(ap_id, model=BANK, scale=1.0, x=1.0, dir=(0.0, 1.0, 0.0), lod=None, stream_r=None):
    return {"ap_id": ap_id, "cls": "Land_HelipadEmpty_F", "world": (x, 2.0, 3.0), "dir": dir, "up": (0.0, 0.0, 1.0),
            "init": "", "desc": "", "model": model, "scale": scale, "lod": lod, "stream_r": stream_r}


def tbl(cls="Land_A_F", x=1.0, init="", model="", scale=1.0, lod=1, stream_r=None, deleted=False):
    return {"classname": cls, "x": x, "y": 2.0, "z": 3.0, "vdir": (0.0, 1.0, 0.0), "vup": (0.0, 0.0, 1.0),
            "init": init, "deleted": deleted, "model": model, "scale": scale, "lod": lod, "stream_r": stream_r}


def p3d_tbl(**kw):
    kw.setdefault("cls", ""); kw.setdefault("model", BANK); kw.setdefault("lod", 0); kw.setdefault("stream_r", 0.0)
    return tbl(**kw)


class TestDiff(unittest.TestCase):
    def test_unchanged_produces_nothing(self):
        ops = map_push.diff({1}, {1: tbl()}, [ent(1)])
        self.assertEqual(ops, {"update": [], "insert": [], "delete": []})

    def test_moved_entity_is_an_update_by_id(self):
        ops = map_push.diff({1}, {1: tbl()}, [ent(1, x=5.0)])
        self.assertEqual([i for i, _ in ops["update"]], [1])

    def test_changed_init_is_an_update(self):
        ops = map_push.diff({1}, {1: tbl()}, [ent(1, init="call X")])
        self.assertEqual(len(ops["update"]), 1)

    def test_new_entity_without_id_is_an_insert(self):
        ops = map_push.diff({1}, {1: tbl()}, [ent(1), ent(None, cls="Land_New_F")])
        self.assertEqual([r["cls"] for r in ops["insert"]], ["Land_New_F"])

    def test_staged_id_now_absent_is_a_delete(self):
        ops = map_push.diff({1, 2}, {1: tbl(), 2: tbl()}, [ent(1)])
        self.assertEqual(ops["delete"], [2])

    def test_unstaged_id_absent_is_NOT_a_delete(self):
        # id 2 exists in the table but was never staged into this edit mission
        ops = map_push.diff({1}, {1: tbl(), 2: tbl()}, [ent(1)])
        self.assertEqual(ops["delete"], [])

    def test_position_within_a_millimetre_is_not_a_change(self):
        ops = map_push.diff({1}, {1: tbl()}, [ent(1, x=1.0004)])
        self.assertEqual(ops["update"], [])


class TestCustomModelAnchors(unittest.TestCase):
    """The AP_CUSTOM_P3D layer diffs by id like the class rows (mapdb.md D7)."""

    def test_unchanged_anchor_produces_nothing(self):
        ops = map_push.diff({9565}, {9565: p3d_tbl()}, [anchor(9565)])
        self.assertEqual(ops, {"update": [], "insert": [], "delete": []})

    def test_moved_anchor_is_an_update(self):
        ops = map_push.diff({9565}, {9565: p3d_tbl()}, [anchor(9565, x=3.0)])
        self.assertEqual([i for i, _ in ops["update"]], [9565])

    def test_rotated_anchor_is_an_update(self):
        ops = map_push.diff({9565}, {9565: p3d_tbl()}, [anchor(9565, dir=(1.0, 0.0, 0.0))])
        self.assertEqual([i for i, _ in ops["update"]], [9565])

    def test_rescaled_anchor_is_an_update(self):
        ops = map_push.diff({9565}, {9565: p3d_tbl()}, [anchor(9565, scale=1.5)])
        self.assertEqual([i for i, _ in ops["update"]], [9565])
        sql, params = map_push.sql_ops("Malden", ops, "t")[0]
        self.assertTrue(sql.startswith("UPDATE map_objects SET x=%s, y=%s, z=%s, vdir_x=%s"))
        self.assertIn("scale=%s", sql)
        self.assertNotIn("classname", sql)      # a model row's class stays ''
        self.assertNotIn("init", sql)
        self.assertEqual(params[-2:], (9565, "Malden"))

    def test_new_anchor_without_id_is_a_model_row_insert(self):
        ops = map_push.diff({9565}, {9565: p3d_tbl()}, [anchor(9565), anchor(None, model="custom_p3ds\\HQMesh.p3d", scale=2.0)])
        self.assertEqual([e["model"] for e in ops["insert"]], ["custom_p3ds\\HQMesh.p3d"])
        (sql, params), = map_push.sql_ops("Malden", ops, "t")
        self.assertTrue(sql.startswith("INSERT INTO map_objects (world, classname, model, scale, x, y, z,"))
        cols = sql[sql.index("(") + 1:sql.index(")")].split(", ")
        row = dict(zip(cols, params))
        self.assertEqual(row["classname"], "")
        self.assertEqual(row["model"], "custom_p3ds\\HQMesh.p3d")
        self.assertEqual(row["scale"], 2.0)
        self.assertEqual((row["on_server"], row["stream_r"], row["lod"], row["layer"]), (True, 0.0, 0, "AP_CUSTOM_P3D"))

    def test_staged_anchor_now_absent_is_a_soft_delete(self):
        ops = map_push.diff({9565, 9566}, {9565: p3d_tbl(), 9566: p3d_tbl()}, [anchor(9565)])
        self.assertEqual(ops["delete"], [9566])
        (sql, params), = map_push.sql_ops("Malden", ops, "t")
        self.assertTrue(sql.startswith("UPDATE map_objects SET deleted=true"))
        self.assertEqual(params, ("t", 9566, "Malden"))


class TestDescriptionTokens(unittest.TestCase):
    """AP_LOD= / AP_R= on any entity set lod / stream_r; invalid tokens are ignored with a warning."""

    def test_valid_tokens_parse(self):
        self.assertEqual(map_push.desc_flags("AP_ID=1|AP_LOD=2|AP_R=300"), (2, 300.0, []))
        self.assertEqual(map_push.desc_flags("AP_R=0"), (None, 0.0, []))
        self.assertEqual(map_push.desc_flags(""), (None, None, []))

    def test_invalid_lod_is_ignored_with_a_warning(self):
        for bad in ("AP_LOD=4", "AP_LOD=-1", "AP_LOD=x", "AP_LOD=1.5", "AP_LOD="):
            lod, sr, warns = map_push.desc_flags(bad)
            self.assertIsNone(lod, bad)
            self.assertEqual(len(warns), 1, bad)

    def test_invalid_radius_is_ignored_with_a_warning(self):
        for bad in ("AP_R=-5", "AP_R=far", "AP_R=nan", "AP_R=inf", "AP_R="):
            lod, sr, warns = map_push.desc_flags(bad)
            self.assertIsNone(sr, bad)
            self.assertEqual(len(warns), 1, bad)

    def test_changed_lod_alone_is_an_update_that_sets_lod(self):
        ops = map_push.diff({1}, {1: tbl(lod=1)}, [ent(1, lod=2)])
        self.assertEqual([i for i, _ in ops["update"]], [1])
        sql, params = map_push.sql_ops("Malden", ops, "t")[0]
        self.assertIn("lod=%s", sql)
        self.assertNotIn("stream_r", sql)                    # absent token leaves the column alone

    def test_changed_radius_alone_is_an_update_that_sets_stream_r(self):
        ops = map_push.diff({1}, {1: tbl(stream_r=None)}, [ent(1, stream_r=300.0)])
        self.assertEqual([i for i, _ in ops["update"]], [1])
        sql, params = map_push.sql_ops("Malden", ops, "t")[0]
        self.assertIn("stream_r=%s", sql)
        self.assertIn(300.0, params)

    def test_tokens_matching_the_table_are_not_a_change(self):
        ops = map_push.diff({1}, {1: tbl(lod=2, stream_r=300.0)}, [ent(1, lod=2, stream_r=300.0)])
        self.assertEqual(ops["update"], [])

    def test_absent_token_never_resets_the_column(self):
        ops = map_push.diff({1}, {1: tbl(lod=3, stream_r=50.0)}, [ent(1)])
        self.assertEqual(ops["update"], [])

    def test_token_on_a_new_anchor_overrides_the_p3d_defaults(self):
        ops = map_push.diff(set(), {}, [anchor(None, lod=2, stream_r=800.0)])
        (sql, params), = map_push.sql_ops("Malden", ops, "t")
        cols = sql[sql.index("(") + 1:sql.index(")")].split(", ")
        row = dict(zip(cols, params))
        self.assertEqual((row["lod"], row["stream_r"], row["on_server"]), (2, 800.0, True))

    def test_token_on_a_new_class_row_is_inserted(self):
        ops = map_push.diff(set(), {}, [ent(None, cls="Land_New_F", lod=0)])
        (sql, params), = map_push.sql_ops("Malden", ops, "t")
        cols = sql[sql.index("(") + 1:sql.index(")")].split(", ")
        row = dict(zip(cols, params))
        self.assertEqual(row["lod"], 0)
        self.assertNotIn("stream_r", row)                   # absent -> column default (NULL)
        self.assertNotIn("on_server", row)                  # class rows keep the table default


class TestPrepare(unittest.TestCase):
    """Anchors are recognised by their AP_P3D= token and carry model + scale into the diff."""

    def _raw_anchor(self, desc):
        return {"ap_id": None, "cls": "Land_HelipadEmpty_F", "world": (1.0, 2.0, 3.0), "dir": (0.0, 1.0, 0.0),
                "up": (0.0, 0.0, 1.0), "init": "", "desc": desc}

    def test_anchor_gains_model_path_and_scale(self):
        ents, warns = map_push.prepare([], [self._raw_anchor("AP_ID=9565|AP_P3D=Bank|AP_SCALE=1.5")])
        self.assertEqual(warns, [])
        self.assertEqual((ents[0]["model"], ents[0]["scale"]), (BANK, 1.5))

    def test_scale_defaults_to_one(self):
        ents, _ = map_push.prepare([], [self._raw_anchor("AP_P3D=Bank")])
        self.assertEqual(ents[0]["scale"], 1.0)

    def test_bad_scale_skips_the_anchor_with_a_warning(self):
        ents, warns = map_push.prepare([], [self._raw_anchor("AP_P3D=Bank|AP_SCALE=big")])
        self.assertEqual(ents, [])
        self.assertEqual(len(warns), 1)

    def test_class_entities_get_their_tokens_and_keep_no_model(self):
        ents, warns = map_push.prepare([dict(ent(1, desc="AP_ID=1|AP_LOD=9|AP_R=250"))], [])
        self.assertEqual(len(warns), 1)                       # AP_LOD=9 is out of range
        self.assertEqual((ents[0]["lod"], ents[0]["stream_r"]), (None, 250.0))
        self.assertNotIn("model", ents[0])


if __name__ == "__main__":
    unittest.main()
