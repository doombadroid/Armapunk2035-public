#!/usr/bin/env python3
"""Generate 3DEN Custom Compositions for everything placeable: buildings, NPCs, spawn pads.

WHY COMPOSITIONS: 3DEN's asset browser is built from configFile, and the custom buildings are raw
.p3d files inside the mission -- no addon class, so no asset-browser entry without a mod on every
editing machine. Custom Compositions get there with none: plain files under
Documents/Arma 3/compositions/, shown under Compositions > Custom, dragged in like any asset, and
attribute values (init, description) are saved with them. Folders copy to another machine or
publish to the Workshop, which is what makes delegating map work practical.

Three families, display-named for humans (folders keep stable slugs):

  MAD Building - <name>       one anchor per custom .p3d model+scale in use (from the data)
  MAD NPC - <role>            every NPC role: 23 derived from the live array, plus the Altis
                              catalogue validated against THIS mission's own switch statements
  MAD Spawn Pad - <kind>      car_spawn / air_spawn / boat_spawn convention markers

Vehicle NPCs ship with an EMPTY spawns list and pads embedded in the composition: since
npcs/fn_nearSpawns.sqf, an empty list means "use the nearby car_spawn/air_spawn/boat_spawn
markers", so a dragged-in garage wires itself. Only non-spawn site args (turf name, chop-shop
town, delivery-point id) still say SETME, and apply refuses to accept one left unedited.

    ~/pysqf-venv/bin/python tools/make_compositions.py            # write them all
    ~/pysqf-venv/bin/python tools/make_compositions.py --list     # show what would be written
(the building list is read from map_objects, so this needs the venv's psycopg)
"""
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_codegen as MC

COMP_DIR = os.environ.get(
    "AP_COMPOSITIONS",
    os.path.expanduser("~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/"
                       "steamuser/Documents/Arma 3/compositions"))
AUTHOR = "Doomba"

# Tall generated towers position by their AUTOCENTERED model centre: give their
# composition anchors a vertical offset of halfHeight-0.15, so a composition
# dropped on the terrain lands the building's BASE on the ground.
TOWER_ALT = {"skyscraper30_r12": 58.310}   # Skyscraper20 dropped from the PBO 2026-09-04 (mapdb)
# ap_garage_5f_r3 (6.875) was removed 2026-09-04 with the parking garage. The GARAGES
# list below is UNRELATED -- those are the vehicle-dealership NPC compositions.

# ------------------------------------------------------------------ display names
LABELS = {
    "shops_civ": "Shop - Convenience", "shops_genstore": "Shop - General Store",
    "shops_gun": "Shop - Gun Store", "shops_market": "Shop - Market",
    "shops_diamond": "Shop - Diamond Trader", "shops_fishmarket": "Shop - Fish Market",
    "shops_heroin": "Shop - Heroin Dealer", "shops_home": "Shop - Home Store",
    "shops_wongs": "Shop - Wong's Food", "shops_commod": "Shop - Commodities Trader",
    "shops_dive": "Shop - Diving Gear", "shops_laser": "Shop - Laser Gear",
    "shops_medicaldispensary": "Shop - Medical Dispensary", "shops_oil": "Shop - Oil Trader",
    "shops_paintshop": "Shop - Paint Shop", "shops_redburger": "Shop - Red Burger",
    "shops_salt": "Shop - Salt Trader", "shops_tech": "Shop - Tech Store",
    "shops_vig": "Shop - Vigilante Gear", "gasStations": "Shop - Gas Station",
    "civHuntingWeapon": "Shop - Hunting Weapons", "civJewelry": "Shop - Jewelry",
    "civProcessItem_mineral": "Processor - Minerals", "civProcessItem_oil": "Processor - Oil",
    "civProcessItem_timber": "Processor - Timber", "civProcessItem_smashpowder": "Processor - Smash Powder",
    "civProcessItem_marijuana": "Processor - Marijuana",
    "civProcessItem_medmarijuana": "Processor - Medical Marijuana",
    "civProcessItem_blacklace": "Processor - Black Lace", "civProcessItem_oyster": "Processor - Oysters",
    "civProcessItem_salt": "Processor - Salt",
    "civProcessItem_purificationfactory": "Processor - Purification Factory",
    "civProcessItem_scotchHeatPump": "Processor - Scotch Heat Pump",
    "clinics_clinic": "Medic - Clinic", "clinics_clothing": "Medic - Clothing Shop",
    "clinics_hospital": "Medic - Hospital",
    "copShops_general": "Cop - Equipment Shop", "copShops_copdive": "Cop - Dive Shop",
    "copGetBounty": "Cop - Bounty Payout", "applyCop": "Cop - Recruitment Officer",
    "civFactory_blackmarket": "Factory - Black Market",
    "civFactory_vehicles": "Factory - Vehicles", "civFactory_weapons": "Factory - Weapons",
    "civDMV_shops_home": "Civic - DMV + Home Store", "civSkiptracer": "Civic - Skiptracer",
    "courthouse": "Civic - Courthouse", "civExchange": "Civic - Exchange",
    "tourism": "Civic - Tourism Guide", "governor": "Civic - Governor's Aide",
    "prison": "Civic - Prison Clerk", "duelArena": "Civic - Duel Arena",
    "CH7": "Civic - CH7 Reporter", "civConvoy": "Civic - Convoy Contractor",
    "missionDP": "Civic - Delivery Point", "civTimeTrials_gokart": "Civic - Go-Kart Trials",
    "civRebelWeapon": "Rebel - Weapons Dealer",
    "chopshop": "Crime - Chop Shop", "civTurfDealer": "Crime - Turf Dealer",
}


def label_for(slug):
    if slug in LABELS:
        return LABELS[slug]
    for k, v in LABELS.items():          # derived slugs like civDMV_shops_home match exactly;
        if slug.startswith(k + "_"):     # site-suffixed ones fall back to their base label
            return v
    return slug.replace("_", " ").title()


# ------------------------------------------------------------------ writer
def write_comp(folder_slug, display, items):
    """One composition: `items` = dicts of kind 'anchor' (NPC/building) or 'marker' (pad)."""
    d = os.path.join(COMP_DIR, folder_slug)
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, "header.sqe"), "w").write(
        'version=54;\nname=%s;\nauthor="%s";\ncategory="EdSubcat_Default";\n'
        'requiredAddons[]=\n{\n};\n' % (MC._q(display), AUTHOR))
    t = "\t"
    out = ["version=54;\ncenter[]={0,0,0};\nclass items\n{\n",
           "%sitems=%d;\n" % (t, len(items))]
    for i, it in enumerate(items):
        x, y = it.get("off", (0, 0))
        alt = it.get("alt", 0)
        out.append("%sclass Item%d\n%s{\n" % (t, i, t))
        if it["kind"] == "marker":
            out.append('%sdataType="Marker";\n' % (t * 2))
            out.append("%sposition[]={%g,%g,%g};\n" % (t * 2, x, alt, y))
            out.append('%sname=%s;\n' % (t * 2, MC._q(it["name"])))
            out.append('%stype="Empty";\n' % (t * 2))
            out.append("%sangle=0;\n" % (t * 2))
        else:
            out.append('%sdataType="Object";\n' % (t * 2))
            out.append("%sclass PositionInfo\n%s{\n%sposition[]={%g,%g,%g};\n%s};\n"
                       % (t * 2, t * 2, t * 3, x, alt, y, t * 2))
            out.append('%sside="Empty";\n' % (t * 2))
            out.append("%sclass Attributes\n%s{\n" % (t * 2, t * 2))
            if it.get("init"):
                out.append("%sinit=%s;\n" % (t * 3, MC._q(it["init"])))
            if it.get("desc"):
                out.append("%sdescription=%s;\n" % (t * 3, MC._q(it["desc"])))
            out.append("%s};\n" % (t * 2))
            out.append('%stype=%s;\n' % (t * 2, MC._q(it.get("cls", MC.ANCHOR_CLASS))))
        out.append("%sid=%d;\n" % (t * 2, i + 1))
        out.append("%s};\n" % t)
    out.append("};\n")
    open(os.path.join(d, "composition.sqe"), "w").write("".join(out))
    return folder_slug


def npc_item(cls, init, off=(0, 0)):
    return {"kind": "anchor", "cls": MC.ANCHOR_CLASS, "init": init,
            "desc": "AP_NPC=%s" % cls, "off": off}


def pad(prefix, off):
    return {"kind": "marker", "name": prefix + "_1", "off": off}


# ------------------------------------------------------------------ catalogues
SNAPSHOT = os.path.join(MC.REPO, "deploy", "map_snapshot", "map_objects.sqf")


def derived_roles():
    """(slug, class, init, count) per distinct init already placed -- read from the committed
    snapshot of map_objects (mapdb.md D7), so this needs no database."""
    import mapdata_rows
    rows = [r for r in mapdata_rows.read(SNAPSHOT).rows if r.cls and MC.is_person(r.cls)]
    by_init = collections.defaultdict(list)
    for r in rows:
        by_init[r.init].append(r.cls)
    out = []
    for init, classes in sorted(by_init.items()):
        fns = re.findall(r"NPC_fnc_(\w+)", init)
        args = [a for a in re.findall(r"'([^']+)'", init) if not a.startswith("STAND")]
        slug = "_".join(fns + args) or "custom"
        out.append((slug, collections.Counter(classes).most_common(1)[0][0], init, len(classes)))
    return out


def _switch_cases(fname):
    src = open(os.path.join(MC.MISSION, "npcs", fname)).read()
    return set(re.findall(r'case "([^"]+)"', src))


def altis_roles():
    """Roles from the Altis catalogue not yet on Malden, validated against THIS mission's own
    switch statements so a pruned resource can never become a broken shop composition."""
    have = {slug for slug, _, _, _ in derived_roles()}
    out = []

    def add(slug, cls, init):
        if slug not in have:
            out.append((slug, cls, init))

    for a in sorted(_switch_cases("fn_shops.sqf")):
        add("shops_%s" % a, "C_man_shorts_3_F",
            "[_this,'STAND_U1','%s'] call NPC_fnc_shops;" % a)
    for a in sorted(_switch_cases("fn_civProcessItem.sqf")):
        add("civProcessItem_%s" % a, "C_man_1",
            "[_this,'STAND_U1','%s'] call NPC_fnc_civProcessItem;" % a)
    for a in sorted(_switch_cases("fn_clinics.sqf")):
        add("clinics_%s" % a, "C_man_polo_2_F",
            "[_this,'STAND_U1','%s'] call NPC_fnc_clinics;" % a)
    for a in sorted(_switch_cases("fn_civFactory.sqf")):
        add("civFactory_%s" % a, "C_man_polo_5_F",
            "[_this,'STAND_U1','%s'] call NPC_fnc_civFactory;" % a)
    for slug, fn in [("civExchange", "civExchange"), ("tourism", "tourism"),
                     ("governor", "governor"), ("prison", "prison"),
                     ("duelArena", "duelArena"), ("CH7", "CH7"), ("applyCop", "applyCop"),
                     ("civConvoy", "civConvoy"), ("civHuntingWeapon", "civHuntingWeapon")]:
        add(slug, "C_man_1", "[_this,'STAND_U1'] call NPC_fnc_%s;" % fn)
    add("civTimeTrials_gokart", "C_man_shorts_1_F",
        "[_this,'STAND_U1','gokart'] call NPC_fnc_civTimeTrials;")
    # site args that are NOT spawn markers stay SETME -- apply refuses them un-edited
    add("civTurfDealer", "C_man_polo_6_F",
        "[_this,'STAND_U1','SETME'] call NPC_fnc_civTurfDealer;")
    add("missionDP", "C_man_1", "[_this,'STAND_U1','SETME'] call NPC_fnc_missionDP;")
    add("chopshop", "C_man_shorts_3_F",
        "[_this,[],'STAND_U1','SETME'] call NPC_fnc_chopshop;")
    return out


# vehicle NPCs: empty spawns list = self-wiring via nearby convention markers; each ships with
# its own pads embedded so a single drag places a WORKING garage
GARAGES = [
    # (slug suffix, label, fn, type, class, pads)
    ("garage_carShop", "Garage - Cars + Shop", "civVehicles", "carShop",
     "C_man_shorts_1_F", [("car_spawn", (6, 0)), ("car_spawn", (12, 0))]),
    ("garage_truckShop", "Garage - Trucks + Shop", "civVehicles", "truckShop",
     "C_man_1", [("car_spawn", (8, 0)), ("car_spawn", (16, 0))]),
    ("garage_mechanic", "Garage - Mechanic", "civVehicles", "mechanic",
     "C_man_shorts_3_F", [("car_spawn", (6, 0)), ("car_spawn", (12, 0))]),
    ("garage_groundGarage", "Garage - Ground Retrieval", "civVehicles", "groundGarage",
     "C_man_polo_1_F", [("car_spawn", (6, 0)), ("car_spawn", (12, 0))]),
    ("garage_heliGarage", "Garage - Helicopters", "civVehicles", "heliGarage",
     "C_man_polo_3_F", [("air_spawn", (18, 0))]),
    ("garage_airshop", "Garage - Aircraft + Shop", "civVehicles", "airshop",
     "C_man_polo_5_F", [("air_spawn", (18, 0)), ("car_spawn", (6, 0))]),
    ("garage_groundAir", "Garage - Ground + Air", "civVehicles", "groundAir",
     "C_man_polo_6_F", [("car_spawn", (6, 0)), ("car_spawn", (12, 0)), ("air_spawn", (22, 0))]),
    ("garage_boat", "Garage - Boats", "civVehicles", "boat",
     "C_man_shorts_2_F", [("boat_spawn", (15, 0))]),
    ("garage_boatGround", "Garage - Boats + Ground", "civVehicles", "boatGround",
     "C_man_shorts_2_F", [("boat_spawn", (15, 0)), ("car_spawn", (6, 0))]),
    ("garage_gokart", "Garage - Go-Karts", "civVehicles", "gokart",
     "C_man_1", [("car_spawn", (5, 0)), ("car_spawn", (9, 0))]),
    ("garage_RV", "Garage - RVs", "civVehicles", "RV",
     "C_man_1", [("car_spawn", (8, 0)), ("car_spawn", (16, 0))]),
    ("garage_vigi", "Garage - Vigilante", "civVehicles", "vigi",
     "C_man_polo_4_F", [("car_spawn", (6, 0)), ("air_spawn", (18, 0))]),
    ("garage_gov", "Garage - Governor", "civVehicles", "gov",
     "C_man_polo_4_F", [("car_spawn", (6, 0))]),
    ("cop_garage_ground", "Cop Garage - Ground", "copVehicles", "ground",
     "B_Captain_Jay_F", [("car_spawn", (6, 0)), ("car_spawn", (12, 0))]),
    ("cop_garage_air", "Cop Garage - Air", "copVehicles", "air",
     "B_Captain_Jay_F", [("air_spawn", (18, 0))]),
    ("cop_garage_airground", "Cop Garage - Ground + Air", "copVehicles", "airground",
     "B_Captain_Jay_F", [("car_spawn", (6, 0)), ("air_spawn", (20, 0))]),
    ("cop_garage_sea", "Cop Garage - Boats", "copVehicles", "sea",
     "B_Captain_Jay_F", [("boat_spawn", (15, 0))]),
    ("cop_garage_srt", "Cop Garage - SRT", "copVehicles", "srt",
     "B_Captain_Jay_F", [("car_spawn", (6, 0)), ("air_spawn", (20, 0))]),
    ("med_garage_ground", "Medic Garage - Ground", "medVehicles", "ground",
     "C_man_polo_2_F", [("car_spawn", (6, 0)), ("car_spawn", (12, 0))]),
    ("med_garage_air", "Medic Garage - Air", "medVehicles", "air",
     "C_man_polo_2_F", [("air_spawn", (18, 0))]),
    ("med_garage_boat", "Medic Garage - Boats", "medVehicles", "boat",
     "C_man_polo_2_F", [("boat_spawn", (15, 0))]),
    ("rebel_vehicles_air", "Rebel - Vehicles (Air)", "civRebelVehicles", "air",
     "O_Soldier_unarmed_F", [("car_spawn", (6, 0)), ("air_spawn", (20, 0))]),
    ("rebel_vehicles_ground", "Rebel - Vehicles (Ground)", "civRebelVehicles", "ground",
     "O_Soldier_unarmed_F", [("car_spawn", (6, 0)), ("car_spawn", (12, 0))]),
]

# always-on store/area lights: the init both forces the lamp on around the clock and makes the
# loader create a REAL local object -- an init-less lamp row becomes a simple object, which
# cannot emit light at all
LIGHTS = [
    ("light_industrial", "Light - Industrial Wall Lamp", "Land_LampIndustrial_01_F"),
    ("light_industrial2", "Light - Industrial Arm Lamp", "Land_LampIndustrial_02_F"),
    ("light_portable_double", "Light - Portable Double", "Land_PortableLight_double_F"),
    ("light_portable_single", "Light - Portable Single", "Land_PortableLight_single_F"),
    ("light_halogen", "Light - Halogen Flood", "Land_LampHalogen_F"),
    ("light_street", "Light - Street Lamp", "Land_LampStreet_F"),
    ("light_street_small", "Light - Street Lamp Small", "Land_LampStreet_small_F"),
    ("light_decor", "Light - Decorative Lamp", "Land_LampDecor_F"),
    ("light_harbour", "Light - Harbour Lamp", "Land_LampHarbour_F"),
]

SPAWN_PADS = [
    ("spawn_car", "Spawn Pad - Car", "car_spawn"),
    ("spawn_air", "Spawn Pad - Air", "air_spawn"),
    ("spawn_boat", "Spawn Pad - Boat", "boat_spawn"),
]


# ---------------------------------------------------------------- vending machines
# The twelve shop machines from the vending handoff (scratchpad/skyscraper/ARMA3_HANDOFF_VENDING.md).
#
# ONE ROW EACH, model AND init together. fn_createVehicleLocal's custom-.p3d branch runs the row's
# init code after it spawns the simple object, so a machine needs no companion anchor: the model IS
# the thing the shop actions hang on. That is why these are emitted here rather than falling out of
# the building loop above, which emits models with no init.
#
# THE FOUR VEHICLE MACHINES CARRY PADS, exactly like the garage compositions and for the same
# reason: NPC_fnc_nearSpawns resolves an empty spawns list against nearby car_spawn/air_spawn
# markers at init time, so a machine dragged anywhere works as soon as its pads come with it.
# The other eight need none -- pads on a clothing shop would be clutter that spawns nothing.
#
# Offsets are metres from the anchor, matching the GARAGES table's convention above.
VENDING = [
    # (slug, display name from the handoff's table, pads)
    ("synthmeat",             "Synth-Meat Market",                 []),
    ("cyberthreads",          "Cyberthreads",                      []),
    ("lopoint",               "Lo-Point Firearms",                 []),
    ("carshop",               "Grounded Motors",                   [("car_spawn", (6, 0)), ("car_spawn", (12, 0))]),
    ("airshop",               "Grounded Aviation",                 [("air_spawn", (18, 0)), ("car_spawn", (6, 0))]),
    ("gearshop",              "Pack Rat Surplus",                  []),
    ("illeagle",              "Ill-Eagle Firearms & Gear",         []),
    ("illeaglevehicles",      "Ill-Eagle Vehicles",                [("car_spawn", (6, 0)), ("car_spawn", (12, 0)), ("air_spawn", (22, 0))]),
    ("pharma",                "Hard Reset Pharma",                 []),
    ("reallyilleagle",        "Really Ill-Eagle Vehicles (ND)",    [("car_spawn", (6, 0)), ("car_spawn", (12, 0))]),
    ("reallyilleagleweapons", "Really Ill-Eagle Firearms (ND)",    []),
    ("kabuki",                "Kabuki Electronics",                []),
]
VEND_MODEL = "custom_p3ds\\ap_vend_cabinet_r4.p3d"   # r2: ONE cabinet for all twelve; the sign is a UserTexture quad the init hangs on it (fn_vendShop)


def main():
    listing = "--list" in sys.argv
    if not listing and not os.path.isdir(COMP_DIR):
        sys.exit("composition folder not found: %s\n(set AP_COMPOSITIONS if yours differs)"
                 % COMP_DIR)
    written = 0

    def emit(folder, display, items):
        nonlocal written
        if listing:
            print("   %-42s %s" % (display, folder))
        else:
            write_comp(folder, display, items)
            written += 1
            print("   %s" % display)

    print("== buildings ==")
    seen = {}
    for e in MC.read_p3d_db():     # the table's model rows; needs ~/pysqf-venv/bin/python (psycopg)
        toks = MC._tokens(e["desc"])
        model = next(t[len("AP_P3D="):] for t in toks if t.startswith("AP_P3D="))
        scale = next((t[len("AP_SCALE="):] for t in toks if t.startswith("AP_SCALE=")), "1")
        seen[(model, scale)] = seen.get((model, scale), 0) + 1
    # every TOWER_ALT model gets a composition even with zero current
    # placements -- these are the drop-to-place buildings, and the owner
    # deletes/re-places them freely (a deleted placement must not delete
    # the composition that would put it back)
    for model in TOWER_ALT:
        seen.setdefault((model, "1"), 0)
    for (model, scale), n in sorted(seen.items()):
        folder = "MAD_%s" % model if scale == "1" else \
            "MAD_%s_s%s" % (model, scale.replace(".", "_"))
        label = "MAD Building - %s" % model + ("" if scale == "1" else " (x%s)" % scale)
        emit(folder, label, [{"kind": "anchor", "cls": MC.ANCHOR_CLASS,
                              "alt": TOWER_ALT.get(model, 0),
                              "desc": "AP_P3D=%s|AP_SCALE=%s" % (model, scale)}])

    print("== NPC roles (from the live array) ==")
    for slug, cls, init, n in derived_roles():
        emit("MAD_NPC_%s" % slug, "MAD NPC - %s" % label_for(slug), [npc_item(cls, init)])

    print("== NPC roles (Altis catalogue, validated against this mission) ==")
    for slug, cls, init in altis_roles():
        emit("MAD_NPC_%s" % slug, "MAD NPC - %s" % label_for(slug), [npc_item(cls, init)])

    print("== vehicle NPCs (self-wiring, pads included) ==")
    for slug, label, fn, typ, cls, pads in GARAGES:
        if typ is None:
            init = "[_this,[],'STAND_U1'] call NPC_fnc_%s;" % fn
        else:
            init = "[_this,[],'STAND_U1','%s'] call NPC_fnc_%s;" % (typ, fn)
        items = [npc_item(cls, init)] + [pad(p, off) for p, off in pads]
        emit("MAD_NPC_%s" % slug, "MAD %s" % label, items)

    print("== vending machines (model + shop wiring in one row) ==")
    for slug, display, pads in VENDING:
        init = "[_this,'%s'] call NPC_fnc_vendShop;" % slug
        items = [{"kind": "anchor", "cls": MC.ANCHOR_CLASS, "alt": 0, "init": init,
                  "desc": "AP_P3D=%s|AP_SCALE=1" % VEND_MODEL}]
        items += [pad(pfx, off) for pfx, off in pads]
        emit("MAD_VEND_%s" % slug, "MAD Vending - %s" % display, items)

    print("== lights (always on) ==")
    for folder, label, cls in LIGHTS:
        emit("MAD_%s" % folder, "MAD %s" % label,
             [{"kind": "anchor", "cls": cls, "init": "_this switchLight 'ON';", "desc": ""}])

    print("== spawn pads ==")
    for folder, label, prefix in SPAWN_PADS:
        emit("MAD_%s" % folder, "MAD %s" % label, [pad(prefix, (0, 0))])

    if not listing:
        print("\nwrote %d compositions to %s" % (written, COMP_DIR))
        print("Restart Arma, then: Asset Browser -> Compositions -> Custom")


if __name__ == "__main__":
    main()
