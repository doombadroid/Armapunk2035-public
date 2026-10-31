#!/usr/bin/env python3
"""Tests for tools/mapdata_migrate.py.  Run: python3 tools/test_mapdata_migrate.py

The migration rewrites ONE field of 8,717 rows. The risk is not that the arithmetic is wrong --
the engine supplies the numbers -- it is that a row gets paired with another row's reading.
So these tests are all about alignment: index, class, and everything the row carries besides
position must come through untouched.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mapdata_migrate

FAILS = []


def check(name, cond):
    print(("  ok   " if cond else "  FAIL ") + name)
    if not cond:
        FAILS.append(name)


# Row 3's init spans two LINES. Four real rows do this -- an NPC that calls two functions, e.g.
# the Malden DMV, which is both a DMV and a shop. A regex using `.` without DOTALL stops dead at
# that newline, which is how the first version of this tool failed on real data after passing
# every synthetic test. The init capture itself was never the problem: `[^"]` matches a newline
# quite happily. It is the surrounding `.*` that has to be told to.
SRC = ('allLocalMapEntities=['
       '["Land_A_F",[10.0,20.0,0.5],[[0.0,1.0,0.0],[0.0,0.0,1.0]],"",false],'
       '["Land_B_F",[30.0,40.0,1.5],[[1.0,0.0,0.0],[0.0,0.0,1.0]],"[_this] call X;",true],'
       '["C_man_1",[50.0,60.0,0.0],[[0.0,1.0,0.0],[0.0,0.0,1.0]],"",false,[["arifle"]]],'
       '["C_man_1_3_F",[70.0,80.0,0.3],[[0.766,-0.643,0.0],[0.0,0.0,1.0]],'
       '"[_this,\'STAND_U1\'] call NPC_fnc_civDMV;\n'
       '[_this,\'STAND_U1\',\'home\'] call NPC_fnc_shops;",false]'
       '];\n')

LOG = "\n".join([
    '2026/01/01 "[MAPMIG] ==== start rows=4 ===="',
    '2026/01/01 "[MAPMIG] i=0 cls=Land_A_F world=10.0000,20.0000,41.2000"',
    '2026/01/01 "[MAPMIG] i=1 cls=Land_B_F world=30.5000,40.0000,42.7000"',
    '2026/01/01 "[MAPMIG] i=2 cls=C_man_1 world=50.0000,60.0000,38.9000"',
    '2026/01/01 "[MAPMIG] i=3 cls=C_man_1_3_F world=70.0000,80.0000,39.4000"',
    '2026/01/01 "[MAPMIG] ==== end rows=4 ===="',
]) + "\n"

rows = mapdata_migrate.parse_rows(SRC)
check("parses 4 rows", len(rows) == 4)
check("multi-line init parsed whole",
      rows[3]["init"].count("call NPC_fnc_") == 2 and "\n" in rows[3]["init"])
check("keeps init text", rows[1]["init"] == "[_this] call X;")
check("keeps server flag", rows[1]["server"] == "true")
check("keeps loadout 6th field", rows[2]["tail"].strip().endswith("[[\"arifle\"]]"))

readings = mapdata_migrate.parse_log(LOG)
check("parses 4 readings", len(readings) == 4)
check("reading is world xyz", readings[1] == ("Land_B_F", (30.5, 40.0, 42.7)))

out = mapdata_migrate.rewrite(SRC, readings)
check("row 0 z replaced", '[10.000,20.000,41.200]' in out)
check("row 1 x replaced too", '[30.500,40.000,42.700]' in out)
check("init survives", '"[_this] call X;"' in out)
check("loadout survives", '[["arifle"]]' in out)
check("class order unchanged",
      out.index("Land_A_F") < out.index("Land_B_F") < out.index("C_man_1"))
check("multi-line init survives the rewrite",
      "call NPC_fnc_civDMV;\n[_this,'STAND_U1','home'] call NPC_fnc_shops;" in out)
check("multi-line row reparses identically",
      mapdata_migrate.parse_rows(out)[3]["init"] == rows[3]["init"])

# alignment failures must abort, never guess
try:
    mapdata_migrate.rewrite(SRC, readings[:3])
    check("aborts on count mismatch", False)
except SystemExit:
    check("aborts on count mismatch", True)

bad = list(readings)
bad[1] = ("Land_WRONG_F", (0.0, 0.0, 0.0))
try:
    mapdata_migrate.rewrite(SRC, bad)
    check("aborts on class mismatch", False)
except SystemExit:
    check("aborts on class mismatch", True)

print("\n%d failure(s)" % len(FAILS))
sys.exit(1 if FAILS else 0)
