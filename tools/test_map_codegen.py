#!/usr/bin/env python3
"""Tests for tools/map_codegen.py.  Run: python3 tools/test_map_codegen.py"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_codegen
import sqm_read
import sqm_splice

FAILS = []


def check(name, cond):
    print(("  ok   " if cond else "  FAIL ") + name)
    if not cond:
        FAILS.append(name)


ents = [
    {"cls": "Land_A_F", "world": (10.0, 20.0, 41.2),
     "dir": (0.0, 1.0, 0.0), "up": (0.0, 0.0, 1.0), "init": "", "desc": ""},
    {"cls": "C_man_1", "world": (30.0, 40.0, 42.7),
     "dir": (1.0, 0.0, 0.0), "up": (0.0, 0.0, 1.0),
     "init": '[_this,"STAND_U1"] call NPC_fnc_shops;', "desc": "AP_SERVERSIDE"},
]

block = map_codegen.build_layer("AP_MAPDATA", ents, 900000, 1)
node = sqm_read._parse_text("class Mission{class Entities{items=2;\n" + block + "};};")

objs = [n for n in sqm_read.walk(node) if n["props"].get("dataType") == "Object"]
check("two objects emitted", len(objs) == 2)
check("class carried", {o["props"]["type"] for o in objs} == {"Land_A_F", "C_man_1"})

pos = objs[0]["subs"]["PositionInfo"]["props"]["position"]
check("position reordered to {x, elevation, y}",
      [round(float(v), 3) for v in pos] == [10.0, 41.2, 20.0])

init = objs[1]["subs"]["Attributes"]["props"]["init"]
check("init text survives the quoting round-trip",
      init == '[_this,"STAND_U1"] call NPC_fnc_shops;')

ids = sorted(o["props"]["id"] for o in objs)
check("ids from the reserved band", ids[0] >= 900000)
check("ids unique", len(set(ids)) == len(ids))

layers = [n for n in sqm_read.walk(node) if n["props"].get("dataType") == "Layer"]
check("one layer, correctly named",
      len(layers) == 1 and layers[0]["props"]["name"] == "AP_MAPDATA")

# angles must round-trip back to the vectors we asked for
import sqm_frame
ang = objs[0]["subs"]["PositionInfo"]["props"]["angles"]
d, u = sqm_frame.angles_to_vectors([float(v) for v in ang])
check("dir round-trips", all(abs(a - b) < 1e-5 for a, b in zip(d, ents[0]["dir"])))
check("up round-trips", all(abs(a - b) < 1e-5 for a, b in zip(u, ents[0]["up"])))

# an init containing a format specifier must not be treated as a format string. The first
# version of build_layer left a %d in its output for the caller to fill in later, which the
# very first NPC row carrying format ["%1 ..."] would have broken.
pct = [{"cls": "C_man_1", "world": (1.0, 2.0, 3.0), "dir": (0.0, 1.0, 0.0),
        "up": (0.0, 0.0, 1.0), "init": 'hint format ["%1 %2", _this, 100];', "desc": ""}]
pblock = map_codegen.build_layer("AP_MAPDATA", pct, 900000, 7)
pnode = sqm_read._parse_text("class Mission{class Entities{items=1;\n" + pblock + "};};")
pobj = [n for n in sqm_read.walk(pnode) if n["props"].get("dataType") == "Object"][0]
check("percent signs in an init survive verbatim",
      pobj["subs"]["Attributes"]["props"]["init"] == 'hint format ["%1 %2", _this, 100];')
check("item index is substituted, not deferred", "class Item7" in pblock and "%d" not in pblock)

# --- round-trip: entities -> layer text -> entities ----------------------------------
import tempfile

rt_block = map_codegen.build_layer("AP_MAPDATA", ents, 900000, 1)
doc = "class Mission{class Entities{items=2;\n" + rt_block + "};};"
fd, tmp = tempfile.mkstemp(suffix=".sqm")
os.write(fd, doc.encode())
os.close(fd)

back = map_codegen.read_layer(tmp, "AP_MAPDATA")
check("round-trip row count", len(back) == len(ents))
check("round-trip class", [b["cls"] for b in back] == [e["cls"] for e in ents])
check("round-trip world position",
      all(all(abs(x - y) < 1e-3 for x, y in zip(b["world"], e["world"]))
          for b, e in zip(back, ents)))
check("round-trip dir",
      all(all(abs(x - y) < 1e-5 for x, y in zip(b["dir"], e["dir"]))
          for b, e in zip(back, ents)))
check("round-trip init", [b["init"] for b in back] == [e["init"] for e in ents])
check("round-trip server flag",
      [b["desc"] for b in back] == [e["desc"] for e in ents])
check("missing layer reads as empty, never as a partial",
      map_codegen.read_layer(tmp, "AP_NOT_THERE") == [])
os.unlink(tmp)

# --- MULTI-LINE init strings ---------------------------------------------------------
# A .sqm config string cannot contain a literal newline. Arma writes a multi-line value as
# quoted segments joined by an unquoted ` \n `:  init="a;" \n "b;";
# Writing the raw newline instead kills the config parser mid-file -- and because the parser
# then discards everything after it, the editor silently opens a TRUNCATED mission. That is
# what happened on the first real staging: 4 rows carry a two-line init (an NPC that is both a
# DMV and a shop) and the whole AP_MAPDATA layer was cut off at the first one.
ml = [{"cls": "C_man_1", "world": (1.0, 2.0, 3.0), "dir": (0.0, 1.0, 0.0), "up": (0.0, 0.0, 1.0),
       "init": "[_this,'STAND_U1'] call NPC_fnc_civDMV;\n[_this,'STAND_U1','home'] call NPC_fnc_shops;",
       "desc": ""}]
mblock = map_codegen.build_layer("AP_MAPDATA", ml, 900000, 3)
check("multi-line init is emitted as segments, not a raw newline",
      '" \\n "' in mblock and "\n[_this" not in mblock)

fd, mtmp = tempfile.mkstemp(suffix=".sqm")
os.write(fd, ("class Mission{class Entities{items=1;\n" + mblock + "};};").encode())
os.close(fd)
mback = map_codegen.read_layer(mtmp, "AP_MAPDATA")
check("multi-line init survives the sqm round-trip whole",
      len(mback) == 1 and mback[0]["init"] == ml[0]["init"])
os.unlink(mtmp)

# and the parser itself, directly -- this is the shared module 11 tools depend on
doc = ('class Mission{class Entities{items=1;class Item0{dataType="Object";'
       'class Attributes{init="aaa;" \\n "bbb;" \\n "ccc;";name="keep";};id=5;type="T";};};};')
node2 = sqm_read._parse_text(doc)
got = [x["subs"]["Attributes"]["props"] for x in sqm_read.walk(node2)
       if x["subs"].get("Attributes")][0]
check("sqm_read joins continuation segments with newlines",
      got.get("init") == "aaa;\nbbb;\nccc;")
check("sqm_read still reads the property after a segmented one", got.get("name") == "keep")

# --- people must be staged as ANCHORS -------------------------------------------------
# A character cannot be a standalone dataType="Object" with side="Empty"; 3DEN refuses the whole
# scenario. 61 of the 8,717 rows are people and the FIRST row in the layer is one, so getting
# this wrong stops the mission opening at all rather than degrading quietly.
check("people are detected", map_codegen.is_person("C_man_1")
      and map_codegen.is_person("B_Captain_Jay_F")
      and map_codegen.is_person("O_Soldier_unarmed_F"))
check("props are not mistaken for people",
      not map_codegen.is_person("Land_HBarrier_Big_F")
      and not map_codegen.is_person("Target_PopUp_Alien1_Moving_Acc1_F")
      and not map_codegen.is_person("Item_U_I_C_Soldier_Bandit_2_F")
      and not map_codegen.is_person("B_Slingload_01_Cargo_F"))

npc = [{"cls": "C_man_polo_1_F", "world": (5.0, 6.0, 7.0), "dir": (0.0, 1.0, 0.0),
        "up": (0.0, 0.0, 1.0), "init": "[_this,'STAND_U1'] call NPC_fnc_shops;",
        "desc": "AP_NPC=C_man_polo_1_F"}]
nblock = map_codegen.build_layer("AP_MAPDATA", npc, 900000, 4)
check("a person is emitted as the anchor class, not as itself",
      'type="Land_HelipadEmpty_F"' in nblock and 'type="C_man_polo_1_F"' not in nblock)
check("the real class rides in the description",
      'description="AP_NPC=C_man_polo_1_F"' in nblock)

fd, ntmp = tempfile.mkstemp(suffix=".sqm")
os.write(fd, ("class Mission{class Entities{items=1;\n" + nblock + "};};").encode())
os.close(fd)
nback = map_codegen.read_layer(ntmp, "AP_MAPDATA")
check("the anchor reads back as the real class", nback[0]["cls"] == "C_man_polo_1_F")
check("the NPC's init survives", nback[0]["init"] == npc[0]["init"])
os.unlink(ntmp)

# server flag and NPC class must coexist in the description
both = [{"cls": "C_man_1", "world": (0.0, 0.0, 0.0), "dir": (0.0, 1.0, 0.0), "up": (0.0, 0.0, 1.0),
         "init": "", "desc": "AP_NPC=C_man_1|AP_SERVERSIDE"}]
bblock = map_codegen.build_layer("AP_MAPDATA", both, 900000, 5)
fd, btmp = tempfile.mkstemp(suffix=".sqm")
os.write(fd, ("class Mission{class Entities{items=1;\n" + bblock + "};};").encode())
os.close(fd)
bback = map_codegen.read_layer(btmp, "AP_MAPDATA")
check("class and server flag coexist",
      bback[0]["cls"] == "C_man_1" and "AP_SERVERSIDE" in map_codegen._tokens(bback[0]["desc"]))
os.unlink(btmp)

# --- entity ids must come from the sqm's own allocator ---------------------------------
# 3DEN refuses a scenario whose entities are numbered past EditorData >> ItemIDProvider >> nextID.
# It fails as a bare "error when loading the scenario" with nothing in the RPT, so the only
# defence is generating ids the way 3DEN itself would.
IDSQM = ('version=54;\nclass EditorData{class ItemIDProvider{nextID=500;};'
         'class MarkerIDProvider{nextID=9;};};\n'
         'class Mission{class Entities{items=1;class Item0{dataType="Object";'
         'class PositionInfo{position[]={1,2,3};};id=499;type="Land_A_F";};};};')
nid, nspan = sqm_splice.item_id_provider(IDSQM)
check("finds the ENTITY id provider, not the marker one", nid == 500)
check("span points at its own declaration", IDSQM[nspan[0]:nspan[1]] == "nextID=500;")
bumped = sqm_splice.set_next_id(IDSQM, 512)
check("nextID is rewritten", sqm_splice.item_id_provider(bumped)[0] == 512)
check("the marker provider is untouched", "class MarkerIDProvider{nextID=9;}" in bumped)

idb = map_codegen.build_layer("AP_MAPDATA", ents, nid, 1)
allids = [int(x) for x in re.findall(r"id=(\d+);", idb)]
check("generated ids start at nextID and are contiguous",
      sorted(allids) == [nid, nid + 1, nid + 2])   # the layer's own id is emitted after its children
check("every generated id is below the bumped nextID",
      max(allids) < nid + 1 + len(ents))

# --- every Object needs a class Attributes, even an empty one --------------------------
# Measured: the shipped sqm has it on 4260 of 4260 objects (31 empty), and a file 3DEN wrote
# itself has it on 4261 of 4261 (32 empty). Omitting it on rows with no init made 3DEN refuse
# the scenario -- a bare "error when loading" with nothing in the RPT.
plain = [{"cls": "Land_A_F", "world": (1.0, 2.0, 3.0), "dir": (0.0, 1.0, 0.0),
          "up": (0.0, 0.0, 1.0), "init": "", "desc": ""}]
ablock = map_codegen.build_layer("AP_MAPDATA", plain, 700, 1)
anode = sqm_read._parse_text("class Mission{class Entities{items=1;\n" + ablock + "};};")
aobjs = [n for n in sqm_read.walk(anode) if n["props"].get("dataType") == "Object"]
check("an init-less object still gets a class Attributes",
      "Attributes" in aobjs[0]["subs"])
check("that Attributes is empty", not aobjs[0]["subs"]["Attributes"]["props"])
alayers = [n for n in sqm_read.walk(anode) if n["props"].get("dataType") == "Layer"]
check("the layer carries atlOffset like the designer's 34 do",
      "atlOffset" in alayers[0]["props"])

# --- custom .p3d placements ------------------------------------------------------------
# Model rows come from the table now (read_p3d_db). The parts that do not need a database:
# the model name <-> mission path pair the AP_P3D= token rides on, and the anchor reader
# carrying the table id back out of the edit mission (that id is what map_push diffs on).
check("model_name strips dir and extension",
      map_codegen.model_name("custom_p3ds\\Bank.p3d") == "Bank"
      and map_codegen.model_name("custom_p3ds/Skyscraper30_r12.p3d") == "Skyscraper30_r12")
check("model_path is its inverse", map_codegen.model_path("Bank") == "custom_p3ds\\Bank.p3d")

p3d = [{"cls": map_codegen.ANCHOR_CLASS, "world": (8512.527, 3765.0, 0.0), "dir": (0.0, 1.0, 0.0),
        "up": (0.0, 0.0, 1.0), "init": "", "desc": "AP_ID=9565|AP_P3D=BridgeStraight|AP_SCALE=1.5"}]
pblock2 = map_codegen.build_layer("AP_CUSTOM_P3D", p3d, 900000, 8)
fd, ptmp = tempfile.mkstemp(suffix=".sqm")
os.write(fd, ("class Mission{class Entities{items=1;\n" + pblock2 + "};};").encode())
os.close(fd)
anchors = map_codegen.read_p3d_anchors(ptmp)
check("an anchor is found by its AP_P3D token, wherever it sits", len(anchors) == 1)
check("the anchor carries its table id", anchors[0]["ap_id"] == 9565)
check("the anchor keeps model and scale in its description",
      anchors[0]["desc"] == "AP_ID=9565|AP_P3D=BridgeStraight|AP_SCALE=1.5")
check("the anchor's position round-trips",
      all(abs(a - b) < 1e-3 for a, b in zip(anchors[0]["world"], p3d[0]["world"])))
layer_back = map_codegen.read_layer(ptmp, "AP_CUSTOM_P3D")
check("read_layer sees the same anchor with the same id", layer_back[0]["ap_id"] == 9565)
os.unlink(ptmp)

# apply is retired: it must refuse loudly, not write anything
try:
    map_codegen.apply()
    check("apply is retired", False)
except SystemExit as e:
    check("apply is retired", "apply is retired: use push" in str(e))

print("\n%d failure(s)" % len(FAILS))
sys.exit(1 if FAILS else 0)
