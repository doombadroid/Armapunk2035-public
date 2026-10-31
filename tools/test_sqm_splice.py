#!/usr/bin/env python3
"""Tests for tools/sqm_splice.py.  Run: python3 tools/test_sqm_splice.py

Generation must never rewrite the designer's bytes. The sqm holds thousands of hand-placed
objects and the only serialiser in this repo writes the binarized form, so re-serialising the
text form would mean writing a new one whose failure mode is corrupting that file. Splicing
sidesteps it: copy verbatim, append, and prove the original bytes are still there.

The nested-Entities case is the trap. Layers contain their own `class Entities`, so a scan that
takes the first match, or counts braces without skipping string literals, lands inside a layer.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sqm_splice
import sqm_read

FAILS = []


def check(name, cond):
    print(("  ok   " if cond else "  FAIL ") + name)
    if not cond:
        FAILS.append(name)


SQM = '''version=54;
class Mission
{
\tclass Entities
\t{
\t\titems=2;
\t\tclass Item0
\t\t{
\t\t\tdataType="Object";
\t\t\tclass PositionInfo
\t\t\t{
\t\t\t\tposition[]={1,2,3};
\t\t\t};
\t\t\tid=11;
\t\t\ttype="Land_A_F";
\t\t};
\t\tclass Item1
\t\t{
\t\t\tdataType="Layer";
\t\t\tname="Designer";
\t\t\tclass Entities
\t\t\t{
\t\t\t\titems=1;
\t\t\t\tclass Item0
\t\t\t\t{
\t\t\t\t\tdataType="Object";
\t\t\t\t\tclass Attributes
\t\t\t\t\t{
\t\t\t\t\t\tinit="a=1; b={2}; s=""}"";";
\t\t\t\t\t};
\t\t\t\t\tid=12;
\t\t\t\t\ttype="Land_B_F";
\t\t\t\t};
\t\t\t};
\t\t\tid=13;
\t\t};
\t};
};
'''

LAYER = '''\t\tclass Item2
\t\t{
\t\t\tdataType="Layer";
\t\t\tname="AP_TEST";
\t\t\tclass Entities
\t\t\t{
\t\t\t\titems=1;
\t\t\t\tclass Item0
\t\t\t\t{
\t\t\t\t\tdataType="Object";
\t\t\t\t\tclass PositionInfo
\t\t\t\t\t{
\t\t\t\t\t\tposition[]={9,8,7};
\t\t\t\t\t};
\t\t\t\t\tid=900001;
\t\t\t\t\ttype="Land_C_F";
\t\t\t\t};
\t\t\t};
\t\t\tid=900000;
\t\t};
'''

n, span, off = sqm_splice.find_mission_entities(SQM)
check("finds root items count 2", n == 2)
check("items span points at the root declaration", SQM[span[0]:span[1]] == "items=2;")
check("insert offset is inside the root Entities block",
      SQM.count("class Item1", 0, off) == 1)

out = sqm_splice.splice_layers(SQM, [LAYER])
check("root items bumped to 3", "items=3;" in out)
check("designer layer's inner items untouched", out.count("items=1;") == 2)
check("original bytes preserved verbatim",
      SQM[:span[0]] in out and 'init="a=1; b={2}; s=""}"";";' in out)
check("new layer present", 'name="AP_TEST"' in out)
check("empty splice is a no-op", sqm_splice.splice_layers(SQM, []) == SQM)

# the spliced file must still parse, and gain exactly the generated entities
before = sqm_read._parse_text(SQM)
after = sqm_read._parse_text(out)


def ids(node):
    return sorted(n["props"]["id"] for n in sqm_read.walk(node)
                  if isinstance(n["props"].get("id"), int))


check("ids are a superset", set(ids(before)) < set(ids(after)))
check("exactly the generated ids added",
      set(ids(after)) - set(ids(before)) == {900000, 900001})

print("\n%d failure(s)" % len(FAILS))
sys.exit(1 if FAILS else 0)
