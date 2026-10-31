#!/usr/bin/env python3
"""map_migrate_props: what qualifies as a plain prop, and that deleting entities by id from a
nested scenario leaves every Entities block renumbered and every other id untouched."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_migrate_props as mp   # noqa: E402
import sqm_read                  # noqa: E402


def obj(depth, n, eid, cls, extra_attrs="", name_line=""):
    t = "\t" * depth
    return (f"{t}class Item{n}\n{t}{{\n{t}\tdataType=\"Object\";\n{t}\tclass PositionInfo\n{t}\t{{\n"
            f"{t}\t\tposition[]={{100.5,{eid}.25,200.5}};\n{t}\t\tangles[]={{0,1.5,0}};\n{t}\t}};\n"
            f"{t}\tside=\"Empty\";\n{t}\tflags=4;\n{t}\tclass Attributes\n{t}\t{{\n{extra_attrs}{t}\t}};\n"
            f"{name_line}{t}\tid={eid};\n{t}\ttype=\"{cls}\";\n{t}}};\n")


def scenario():
    """Root: 3 objects + 1 layer (2 objects) + 1 group with a unit; ids 10..16."""
    root_items = [
        obj(2, 0, 10, "Land_ChairWood_F"),
        obj(2, 1, 11, "Land_Cargo20_blue_F", extra_attrs="\t\t\tinit=\"this allowDamage false;\";\n"),
        obj(2, 2, 12, "Box_Syndicate_Ammo_F"),
    ]
    layer = ("\t\tclass Item3\n\t\t{\n\t\t\tdataType=\"Layer\";\n\t\t\tname=\"FED\";\n\t\t\tclass Entities\n\t\t\t{\n"
             "\t\t\t\titems=2;\n" + obj(4, 0, 13, "Land_CampingTable_F") + obj(4, 1, 14, "Land_Metal_wooden_rack_F") +
             "\t\t\t};\n\t\t\tid=15;\n\t\t};\n")
    group = ("\t\tclass Item4\n\t\t{\n\t\t\tdataType=\"Group\";\n\t\t\tside=\"Civilian\";\n\t\t\tclass Entities\n\t\t\t{\n"
             "\t\t\t\titems=1;\n" + obj(4, 0, 16, "C_man_1") + "\t\t\t};\n\t\t\tid=17;\n\t\t};\n")
    return ("version=54;\nclass EditorData\n{\n\tclass ItemIDProvider\n\t{\n\t\tnextID=18;\n\t};\n};\n"
            "class Mission\n{\n\tclass Entities\n\t{\n\t\titems=5;\n" + "".join(root_items) + layer + group + "\t};\n};\n")


class Selection(unittest.TestCase):
    def test_rules(self):
        with tempfile.NamedTemporaryFile("w", suffix=".sqm", delete=False) as f:
            f.write(scenario()); path = f.name
        chosen, skipped = mp.select(path)
        os.unlink(path)
        self.assertEqual(sorted(e["id"] for e in chosen), [10, 13, 14])          # plain props, root and in the layer
        self.assertEqual(skipped["has init"], 1)                                 # 11 runs code where the engine places it
        self.assertEqual(skipped["class kept: Box_Syndicate_Ammo_F"], 1)         # 12 carries cargo
        self.assertEqual(skipped["in a group"], 1)                               # 16 is a unit
        self.assertEqual([e["layer"] for e in chosen if e["id"] == 13], ["FED"])
        w = next(e for e in chosen if e["id"] == 10)["world"]
        self.assertAlmostEqual(w[0], 100.5); self.assertAlmostEqual(w[1], 200.5); self.assertAlmostEqual(w[2], 10.25)

    def test_authors_fit_the_column(self):
        self.assertLessEqual(len(mp.AUTHOR), 20)
        self.assertLessEqual(len(mp.UNDO_AUTHOR), 20)

    def test_class_filter(self):
        self.assertTrue(mp.is_static_class("Land_PaperBox_01_small_closed_brown_food_F"))   # Box_ inside a Land_ name
        self.assertTrue(mp.is_static_class("Oil_Spill_F"))
        self.assertFalse(mp.is_static_class("Box_IND_AmmoVeh_F"))
        self.assertFalse(mp.is_static_class("I_CargoNet_01_ammo_F"))
        self.assertFalse(mp.is_static_class("C_Boat_Civil_04_F"))
        self.assertFalse(mp.is_static_class("C_Offroad_01_F"))                              # not on the allow list


class Pass2(unittest.TestCase):
    P = "a3\\plants_f\\tree\\t_ficusb1s_f.p3d"

    def test_tree_init_shapes(self):
        A = '_serverObject =true; _tree = createSimpleObject ["%s", [getPosASL this select 0, getPosASL this select 1, (getPosASL this select 2) + 6]]; _tree setDir getDir this; _tree setObjectScale 0.4;' % self.P
        self.assertEqual(mp.parse_tree_init(A), (self.P, (0.0, 0.0, 6.0), "anchor", 0.0, 0.4))
        B = '_tree1 = createSimpleObject ["%s", [getPosASL this select 0, getPosASL this select 1, (getPosASL this select 2) + 4.5]];_tree1 setDir 90; _tree1 setObjectScale 0.6;' % self.P
        self.assertEqual(mp.parse_tree_init(B), (self.P, (0.0, 0.0, 4.5), "abs", 90.0, 0.6))
        C = '_tree = createSimpleObject ["%s", [getPosASL this select 0, getPosASL this select 1, (getPosASL this select 2) + 2.15]];_tree1 setDir 90; _tree setObjectScale 0.8;' % self.P
        self.assertEqual(mp.parse_tree_init(C), (self.P, (0.0, 0.0, 2.15), "abs", 0.0, 0.8))   # setDir named the wrong variable: no-op
        D = '_serverObject = true; _tree = createSimpleObject ["%s", [0, 0, 0]]; _tree attachTo [this, [0, 0, 2.15]]; _tree setDir 180; _tree setObjectScale 0.8;' % self.P
        self.assertEqual(mp.parse_tree_init(D), (self.P, (0.0, 0.0, 2.15), "rel", 180.0, 0.8))
        for s in (A, B, C, D):
            self.assertEqual(mp._rest_of_init(s), "", "nothing else in the init may be dropped silently")
        self.assertIsNone(mp.parse_tree_init('_x = createSimpleObject ["a.p3d", [1,2,3]];'))
        self.assertNotEqual(mp._rest_of_init('_serverObject = true; hint "hi";'), "")

    def test_select_pass2(self):
        def o(depth, n, eid, cls, attrs):
            return obj(depth, n, eid, cls, extra_attrs=attrs)
        t = "\t" * 3
        items = [
            o(2, 0, 20, "Land_Cargo_House_V3_F", f'{t}init="_serverObject =true;";\n'),                       # -> is_server row
            o(2, 1, 21, "Land_TreeGrate_01_F", f'{t}init="_tree = createSimpleObject [""{self.P}"", [getPosASL this select 0, getPosASL this select 1, (getPosASL this select 2) + 6]]; _tree setDir getDir this; _tree setObjectScale 0.4;";\n'),
            o(2, 2, 22, "Land_HelipadEmpty_F", f'{t}name="tree1";\n{t}init="_tree = createSimpleObject [""{self.P}"", [0, 0, 0]]; _tree attachTo [this, [0, 0, 2.15]]; _tree setDir 90;";\n'),
            o(2, 3, 23, "O_T_Boat_Armed_01_hmg_F", f'{t}name="boat";\n'),                                 # stays
            o(2, 4, 24, "Land_ChairWood_F", ""),                                                             # pass 1's business
        ]
        text = ("version=54;\nclass EditorData\n{\n\tclass ItemIDProvider\n\t{\n\t\tnextID=30;\n\t};\n};\n"
                "class Mission\n{\n\tclass Entities\n\t{\n\t\titems=5;\n" + "".join(items) + "\t};\n};\n")
        with tempfile.NamedTemporaryFile("w", suffix=".sqm", delete=False) as f:
            f.write(text); path = f.name
        rows, skipped, dropped = mp.select_pass2(path)
        os.unlink(path)
        self.assertEqual(dropped, [])
        kinds = sorted((r["kind"], r.get("cls") or r.get("model"), r.get("is_server", False)) for r in rows)
        self.assertEqual(kinds, sorted([("class", "Land_Cargo_House_V3_F", True), ("class", "Land_TreeGrate_01_F", False),
                                        ("model", self.P, False), ("model", self.P, False)]))
        self.assertEqual(skipped["class kept: O_T_Boat_Armed_01_hmg_F"], 1)
        self.assertEqual(skipped["plain (pass 1)"], 1)
        grate_tree = next(r for r in rows if r["kind"] == "model" and r["src_cls"] == "Land_TreeGrate_01_F")
        self.assertAlmostEqual(grate_tree["world"][2], 21.25 + 6)            # anchor z (from the id-based fixture) + dz
        self.assertAlmostEqual(grate_tree["scale"], 0.4)
        pad_tree = next(r for r in rows if r["kind"] == "model" and r["src_cls"] == "Land_HelipadEmpty_F")
        self.assertAlmostEqual(pad_tree["world"][2], 22.25 + 2.15)
        # ids to delete: every source entity, once
        ids = sorted({r["id"] for r in rows if r["id"] is not None} | {r["src_id"] for r in rows if r.get("src_id")})
        self.assertEqual(ids, [20, 21, 22])


class Strip(unittest.TestCase):
    def test_delete_across_nesting(self):
        text = scenario()
        before = {n["props"]["id"] for n in sqm_read.walk(sqm_read._parse_text(text)) if isinstance(n["props"].get("id"), int)}
        out, report = mp.strip_entities(text, [10, 12, 14])        # two root objects and one inside the layer
        after = {n["props"]["id"] for n in sqm_read.walk(sqm_read._parse_text(out)) if isinstance(n["props"].get("id"), int)}
        self.assertEqual(after, before - {10, 12, 14})
        # root: 5 items -> 3, renumbered 0..2; layer: 2 -> 1; the group untouched
        self.assertIn("\t\titems=3;", out)
        self.assertIn("\t\t\t\titems=1;", out)
        self.assertEqual([m for m in __import__("re").findall(r"\n\t\tclass Item(\d+)\n", out)], ["0", "1", "2"])
        self.assertIn("nextID=18;", out)                             # the id allocator is not touched
        self.assertEqual(report[0][1], 3)

    def test_missing_id_refused(self):
        with self.assertRaises(KeyError):
            mp.strip_entities(scenario(), [999])


if __name__ == "__main__":
    unittest.main()
