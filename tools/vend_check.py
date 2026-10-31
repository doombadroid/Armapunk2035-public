#!/usr/bin/env python3
"""vend_check.py -- the twelve vending machines say what they do, and do what they say.

Every machine is a chain of five artifacts that must agree, and nothing in Arma will tell you when
one link breaks: a missing .paa renders as an untextured panel, a mistyped shop slug logs one line
nobody reads, a shop type that no longer exists in its NPC file falls through a `switch` to nothing,
and an `AP_fnc_` call into the npcs/ tree (which is tagged `NPC_`) compiles clean and does nothing
at all. All five failures look identical in game: a machine you can walk up to that offers you
nothing. This checks them offline instead.

    slug -> custom_p3ds/ap_vend_cabinet_r4.p3d      the one cabinet model, binarized
         -> ap_vend_<slug>_{front0,front1,front2,side}_co.paa   the sign art it points at
         -> a case in npcs/fn_vendShop.sqf          the wiring
         -> a VENDING row in make_compositions.py   the composition the owner edits from
         -> the shop it names actually existing      case "<type>" in the NPC file it delegates to

It also holds the ONE piece of duplication in the feature to account. The two REALLY ILL-EAGLE
machines are New-Drachma-only and the ND actions live inside the rebel builders with the cash ones,
so those three addAction lines are transcribed into fn_vendShop rather than delegated. Each is
asserted to appear VERBATIM in the NPC file it was copied from, so editing the rebel shop and
forgetting the machine fails here rather than leaving a black-market stall selling last month's
prices.

    python3 tools/vend_check.py
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
M = os.path.join(REPO, "mission", "Armapunk2035.Malden")

SLUGS = ["synthmeat", "cyberthreads", "lopoint", "carshop", "airshop", "gearshop",
         "illeagle", "illeaglevehicles", "pharma", "reallyilleagle",
         "reallyilleagleweapons", "kabuki"]

# slug -> (npc file, the `case "<type>"` that file must still contain, or None for a no-switch file)
DELEGATES = {
    "synthmeat":        ("npcs/fn_shops.sqf", "market"),
    "cyberthreads":     ("npcs/fn_shops.sqf", "civ"),
    "lopoint":          ("npcs/fn_shops.sqf", "gun"),
    "gearshop":         ("npcs/fn_shops.sqf", "genstore"),
    "pharma":           ("npcs/fn_shops.sqf", "medicaldispensary"),
    "kabuki":           ("npcs/fn_shops.sqf", "tech"),
    "carshop":          ("npcs/fn_civVehicles.sqf", "carShop"),
    "airshop":          ("npcs/fn_civVehicles.sqf", "airshop"),
    "illeaglevehicles": ("npcs/fn_civRebelVehicles.sqf", "air"),
    "illeagle":         ("npcs/fn_civRebelWeapon.sqf", None),   # no switch: one flat action list
}

# The transcribed lines, and the file each was copied from. Compared after whitespace collapse so a
# reindent in the source is not a failure, but any change to a label, function, argument or
# condition is.
TRANSCRIBED = [
    ("npcs/fn_civRebelWeapon.sqf",
     '_act addAction["New Drachma Clothes", AP_fnc_clothingMenu, ["rebcloth", true], 1.5, false, false, "", \'license_civ_rebel && AP_effSide isEqualTo civilian\', 5];'),
    ("npcs/fn_civRebelWeapon.sqf",
     '_act addAction["New Drachma Weapons", AP_fnc_weaponShopMenu, ["rebelwep", true], 1.5, false, false, "", \'license_civ_rebel && AP_effSide isEqualTo civilian\', 5];'),
    ("npcs/fn_civRebelVehicles.sqf",
     '_act addAction["New Drachma Car Shop", AP_fnc_vehicleShopMenu, [\'nd_car\', civilian, _spawns, \'reb\', "LoonyBin New Drachma Vehicles"], 1.5, false, false, "", \'license_civ_rebel && isNull objectParent player\', 5];'),
]

problems = []


def bad(msg):
    problems.append(msg)


def read(rel):
    with open(os.path.join(M, rel), encoding="utf-8", errors="replace") as f:
        return f.read()


def squash(s):
    return re.sub(r"\s+", " ", s).strip()


def main():
    wiring = read("npcs/fn_vendShop.sqf")
    comps = open(os.path.join(REPO, "tools", "make_compositions.py"), encoding="utf-8").read()
    funcs = read("Functions.h")

    # --- the function itself is registered, under the tag its own callers use
    if not re.search(r"class vendShop\s*\{", funcs):
        bad("Functions.h has no `class vendShop` -- NPC_fnc_vendShop does not exist at runtime")

    # --- an AP_fnc_ call into the npcs tree is the silent-nothing bug this feature already hit once
    for m in re.finditer(r"call (AP_fnc_(?:shops|civVehicles|civRebelVehicles|civRebelWeapon|nearSpawns))", wiring):
        bad("fn_vendShop calls %s -- the npcs/ tree is tagged NPC_, so that call does nothing" % m.group(1))

    for slug in SLUGS:
        # --- model: r2 is ONE cabinet for all twelve (the sign is a quad the init hangs on it)
        p3d = os.path.join(M, "custom_p3ds", "ap_vend_cabinet_r4.p3d")
        if not os.path.exists(p3d):
            bad("%s: no cabinet model at custom_p3ds/ap_vend_cabinet_r4.p3d" % slug)
        else:
            with open(p3d, "rb") as f:
                magic = f.read(4)
            if magic != b"ODOL":
                bad("%s: cabinet is %r, not ODOL -- run scratchpad/skyscraper/binarize_mlods.sh"
                    % (slug, magic))

        # --- sign art, both faces
        # the front is three stacked tiles (front0..2) since 2026-09-07, the side one 1x2 quad
        for face in ("front0", "front1", "front2", "side"):
            paa = os.path.join(M, "ap_vend_%s_%s_co.paa" % (slug, face))
            if not os.path.exists(paa):
                bad("%s: missing sign texture ap_vend_%s_%s_co.paa" % (slug, slug, face))
        if os.path.exists(os.path.join(M, "ap_vend_%s_front_co.paa" % slug)):
            bad("%s: stale single-quad front texture ap_vend_%s_front_co.paa still in the mission" % (slug, slug))

        # --- wiring
        if ('case "%s"' % slug) not in wiring:
            bad("%s: no case in npcs/fn_vendShop.sqf -- the machine would log 'unknown shop slug'" % slug)

        # --- composition
        if ('("%s",' % slug) not in comps:
            bad("%s: no VENDING entry in tools/make_compositions.py -- no composition to edit from" % slug)

        # --- the shop it delegates to still exists
        if slug in DELEGATES:
            rel, case = DELEGATES[slug]
            if not os.path.exists(os.path.join(M, rel)):
                bad("%s: delegates to %s, which does not exist" % (slug, rel))
            elif case is not None and ('case "%s"' % case) not in read(rel):
                bad('%s: delegates to %s case "%s", which that file no longer has'
                    % (slug, rel, case))

    # --- the sign slots are GENERATED from the model dump; a missing or hand-edited file is a
    # sign floating somewhere the face is not
    inc = os.path.join(M, "npcs", "vend_signs.inc.sqf")
    if not os.path.exists(inc):
        bad("npcs/vend_signs.inc.sqf missing -- run scratchpad/skyscraper/build_vending.py")
    else:
        txt = read("npcs/vend_signs.inc.sqf")
        if "GENERATED" not in txt or txt.count('["front"') != 1 or txt.count('["side_l"') != 1 or txt.count('["side_r"') != 1:
            bad("npcs/vend_signs.inc.sqf does not carry exactly front/side_l/side_r generated slots")
        if '#include "vend_signs.inc.sqf"' not in wiring:
            bad("fn_vendShop does not #include vend_signs.inc.sqf")

    # --- the one duplication, held to its source
    wsq = squash(wiring)
    for rel, line in TRANSCRIBED:
        src = squash(read(rel).replace("_obj_main", "_act"))
        if squash(line) not in wsq:
            bad("transcribed line missing from fn_vendShop: %s" % line[:70])
        elif squash(line) not in src:
            bad("fn_vendShop's copy has DRIFTED from %s:\n      %s" % (rel, line))

    if problems:
        print("vend_check: %d problem(s)" % len(problems))
        for p in problems:
            print("  FAIL: %s" % p)
        return 1
    print("vend_check: PASS -- %d machines, model + 3 front tiles + 2 side signs + wiring + composition + live shop each"
          % len(SLUGS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
