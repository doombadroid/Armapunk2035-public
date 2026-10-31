params[["_item", "", [""]]];
// VEHICLE recipes -- the Factory's whole catalogue now.
//
// This table used to hold 161: every weapon, vest, optic and magazine the three Factory stations
// minted. The owner cut the Factory back to vehicles only on 2026-08-22 and the other 136 moved to
// the Fabricator. Their exact ingredient lists were snapshotted to scratchpad/fab/factory_snapshot.json
// BEFORE the cut and are carried over verbatim by scratchpad/gen_fab_catalogue.py, so nothing was
// rebalanced in the move -- only relocated.
//
// NO CASH. Twelve of these charged $2,500-$45,000 on top of their materials. Production costs
// materials and time now, never money (owner 2026-08-21), so each cash line became Iron Ingots at
// that item's own sell value (270 each), read from fn_virtItemCfg rather than typed here. The
// Mohawk went from $42,000 + parts to +156 ingots -- past the 96 carry cap, which makes building
// an aircraft a truck job. That is the intended shape: time and logistics are the price.
//
// THE DEEP COPY IS LOAD-BEARING. fn_craftRecipe.sqf mutates the returned row in place to apply the
// turf discount; a bare reference to the cached row would make that discount permanent and
// compounding -- an unbounded materials dupe.
if (isNil "AP_recipeMap") then {AP_recipeMap = createHashMapFromArray [
        ["B_G_Offroad_01_F", [["AP_inv_ironore", 10], ["AP_inv_oilp", 1]]],
        ["B_G_Offroad_01_armed_F", [["AP_inv_diamondf", 20], ["AP_inv_iron_r", 30], ["AP_inv_oilp", 10], ["AP_inv_rubber", 10]]],
        ["B_Heli_Light_01_F", [["AP_inv_rubber", 6], ["AP_inv_glass", 4], ["AP_inv_diamondc", 20], ["AP_inv_oilp", 20], ["AP_inv_iron_r", 19]]],   // +19 ingots replace $5,000 cash
        ["B_MRAP_01_F", [["AP_inv_diamondf", 15], ["AP_inv_glass", 10], ["AP_inv_iron_r", 10], ["AP_inv_oilp", 10], ["AP_inv_rubber", 10]]],
        // RESOURCE RIGS (traded system 2026-08-27): capital goods, priced above the
        // big trucks -- a mobile extractor is a business, not a runabout. Sentinel
        // keys, not classnames: both rigs ARE flatbeds and the recipe table keys by
        // output, so the sentinel is what keeps them distinct. fn_craftRecipe
        // resolves them through APS_fnc_rigSRV "craft".
        ["rig_extractor", [["AP_inv_iron_r", 140], ["AP_inv_copper_r", 35], ["AP_inv_oilp", 25], ["AP_inv_rubber", 12], ["AP_inv_glass", 6]]],
        ["rig_processor", [["AP_inv_iron_r", 170], ["AP_inv_copper_r", 55], ["AP_inv_oilp", 20], ["AP_inv_rubber", 10], ["AP_inv_glass", 14]]],
        ["B_Truck_01_box_F", [["AP_inv_iron_r", 86], ["AP_inv_oilp", 10], ["AP_inv_rubber", 8]]],   // +56 ingots replace $15,000 cash
        ["B_Truck_01_transport_F", [["AP_inv_iron_r", 56], ["AP_inv_oilp", 10], ["AP_inv_rubber", 6]]],   // +26 ingots replace $7,000 cash
        ["C_Boat_Civil_01_F", [["AP_inv_ironore", 8], ["AP_inv_turtle", 1]]],
        ["C_Boat_Civil_01_rescue_F", [["AP_inv_ironore", 8], ["AP_inv_turtle", 1]]],
        ["C_Hatchback_01_F", [["AP_inv_iron_r", 5], ["AP_inv_rubber", 4], ["AP_inv_oilp", 2]]],
        ["C_Hatchback_01_sport_F", [["AP_inv_rubber", 4], ["AP_inv_iron_r", 8], ["AP_inv_oilp", 4]]],
        ["C_Heli_Light_01_civil_F", [["AP_inv_rubber", 6], ["AP_inv_glass", 4], ["AP_inv_oilp", 10], ["AP_inv_iron_r", 93]]],   // +93 ingots replace $25,000 cash
        ["C_Offroad_01_F", [["AP_inv_iron_r", 5], ["AP_inv_rubber", 4], ["AP_inv_oilp", 2]]],
        ["C_SUV_01_F", [["AP_inv_iron_r", 5], ["AP_inv_rubber", 4], ["AP_inv_oilp", 2]]],
        ["C_Van_01_box_F", [["AP_inv_rubber", 4], ["AP_inv_iron_r", 15], ["AP_inv_oilp", 8]]],
        ["C_Van_01_transport_F", [["AP_inv_rubber", 4], ["AP_inv_iron_r", 13], ["AP_inv_oilp", 8]]],
        ["I_C_Offroad_02_LMG_F", [["AP_inv_diamondf", 1], ["AP_inv_iron_r", 47], ["AP_inv_oilp", 5], ["AP_inv_rubber", 2]]],   // +37 ingots replace $10,000 cash
        ["I_Heli_Transport_02_F", [["AP_inv_diamondf", 1], ["AP_inv_glass", 7], ["AP_inv_rubber", 10], ["AP_inv_oilp", 20], ["AP_inv_iron_r", 156]]],   // +156 ingots replace $42,000 cash
        ["I_Heli_light_03_unarmed_F", [["AP_inv_diamondf", 1], ["AP_inv_glass", 5], ["AP_inv_diamondc", 20], ["AP_inv_oilp", 10], ["AP_inv_rubber", 10], ["AP_inv_iron_r", 81]]],   // +81 ingots replace $22,000 cash
        ["I_Truck_02_covered_F", [["AP_inv_iron_r", 44], ["AP_inv_oilp", 10], ["AP_inv_rubber", 6]]],   // +19 ingots replace $5,000 cash
        ["I_Truck_02_transport_F", [["AP_inv_iron_r", 34], ["AP_inv_oilp", 10], ["AP_inv_rubber", 4]]],   // +9 ingots replace $2,500 cash
        ["O_Heli_Light_02_unarmed_F", [["AP_inv_diamondf", 1], ["AP_inv_glass", 10], ["AP_inv_diamondc", 20], ["AP_inv_oilp", 10], ["AP_inv_rubber", 10], ["AP_inv_iron_r", 93]]],   // +93 ingots replace $25,000 cash
        ["O_Heli_Transport_04_F", [["AP_inv_diamondf", 1], ["AP_inv_glass", 7], ["AP_inv_diamondc", 20], ["AP_inv_oilp", 10], ["AP_inv_rubber", 10], ["AP_inv_iron_r", 167]]],   // +167 ingots replace $45,000 cash
        ["O_Heli_Transport_04_bench_F", [["AP_inv_diamondf", 1], ["AP_inv_glass", 7], ["AP_inv_diamondc", 20], ["AP_inv_oilp", 10], ["AP_inv_rubber", 10], ["AP_inv_iron_r", 119]]],   // +119 ingots replace $32,000 cash
        ["O_LSV_02_armed_F", [["AP_inv_diamondf", 20], ["AP_inv_iron_r", 30], ["AP_inv_oilp", 10], ["AP_inv_rubber", 10]]],
        ["O_MRAP_02_F", [["AP_inv_diamondf", 20], ["AP_inv_glass", 10], ["AP_inv_iron_r", 10], ["AP_inv_oilp", 5], ["AP_inv_rubber", 20]]]
];};

+(AP_recipeMap getOrDefault [_item, []])
