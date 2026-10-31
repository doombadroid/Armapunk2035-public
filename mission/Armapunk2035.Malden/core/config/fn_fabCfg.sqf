params [["_mode", "", [""]], ["_key", "", ["", 0]]];
/*
    fn_fabCfg.sqf  (AP_fnc_fabCfg)  -- the 3D printer's recipe table and tuning tables.

        ["getRecipe", "<outputClass>"] call AP_fnc_fabCfg  -> [level, parts, flags] or []
        ["hasRecipe", "<outputClass>"] call AP_fnc_fabCfg  -> bool
        ["getAll"]                     call AP_fnc_fabCfg  -> every recipe key
        ["duration",  "<outputClass>"] call AP_fnc_fabCfg  -> seconds for ONE unit, tier 1
        ["xpFor",     <level>]         call AP_fnc_fabCfg  -> prints needed to leave that level
        ["backbone"]                   call AP_fnc_fabCfg  -> [<itemKey>, <ndTenThousandthsPerUnit>]
        ["tier",      <1..3>]          call AP_fnc_fabCfg  -> [jobSlots, speedMult, maxRecipeLevel]

    A RECIPE IS THREE FIELDS, and the key IS the output class. Nothing fn_virtItemCfg already knows
    is repeated here -- no display name, no weight, no icon, no price -- which is what keeps a row
    small enough that hundreds of them stay maintainable.

        <outputClass> -> [ <level 1..20>, [[<AP_inv_var>, <qty>], ...], [<flags>] ]

    An ingredient that is itself a key in this table is a sub-recipe for free: the tree is
    arbitrarily deep with no extra syntax, and AP_fnc_fabFee walks it. Flags: "noSchematic" means
    the recipe needs no schematic to print (the intermediates tier). That flag lives on the ROW on
    purpose -- the system this was ported from kept its free-recipe list as a separate hardcoded
    array, and the two had already drifted apart by one entry.

    NO CURRENCY MAY APPEAR IN A PARTS LIST. Production costs materials and time, never money (owner
    2026-08-21); money enters the feature only when buying a schematic, in New Drachma. An
    "AP_cash" entry here would be a design violation, not a balance choice -- tools/fab_check.py
    asserts their absence.

    THE DEEP COPY IS LOAD-BEARING, same as fn_recipeDetail.sqf: callers walk and may rewrite a
    returned parts list, and handing out a bare reference to the cached row would make any such
    edit permanent and compounding. `+` deep-copies sub-arrays too.

    HashMap keys are CASE-SENSITIVE (BIKI getOrDefault). Classnames keep their exact engine case --
    a one-letter case slip here is invisible at runtime and simply makes the recipe unreachable,
    which is exactly how the ported system ended up with 39 recipes no player could ever craft.
*/

// The catalogue is HAND-AUTHORED rows plus the generated block in fn_fabGen.sqf (551 recipes from
// the migrated Factory catalogue and the shop tables). They are separate files on purpose: a
// generated block living inside a hand-edited one is a block somebody edits and then loses on the
// next regeneration, with no error. Hand rows WIN on a key collision -- if a generated recipe ever
// duplicates one tuned here, the tuning is what survives.
//
// ALL THREE TABLES LIVE IN localNamespace (audit 2026-09-26, r2items). APS_fnc_fabSRV prices, gates, times and
// REFUNDS a print from these rows (the refund hands back the recipe's parts list), fabGrantSRV/fabFee price a
// schematic from them, and a client publicVariable overwrites a missionNamespace global on the server too -- a
// forged AP_fabMap row was an arbitrary-item mint. The network cannot write localNamespace.
if (isNil {localNamespace getVariable "AP_fabMap"}) then {localNamespace setVariable ["AP_fabMap", createHashMapFromArray (((call AP_fnc_fabGen) select 0) + [

    // ---- intermediates: the spine. No schematic needed; these are the tier every other recipe
    // draws on, and each one is built from materials the existing gather -> process chain already
    // produces, which is what wires the printer into the map rather than beside it.
    //
    // EVERY COMPOSITE CONTAINS FILAMENT, AND THAT IS THE DESIGN, NOT FLAVOUR. filament is the
    // backbone AP_fnc_fabFee counts, so a schematic's price is only meaningful if the backbone
    // actually nests -- if composites were built from raws alone the recursive walk would return
    // the same number as reading the top-level parts list, and the resolver would be dead weight.
    // Because they nest, a MAR-10 that lists 34 filament really contains 71, and its schematic is
    // priced on the 71.
    ["polymer_pellet",  [ 1, [["AP_inv_oilp", 3], ["AP_inv_sand", 2]], ["noSchematic"]]],
    ["filament",        [ 1, [["AP_inv_polymer_pellet", 1]], ["noSchematic"]]],
    ["optic_blank",     [ 4, [["AP_inv_glass", 4], ["AP_inv_sand", 2], ["AP_inv_filament", 1]], ["noSchematic"]]],
    ["circuit_lamina",  [ 5, [["AP_inv_copper_r", 3], ["AP_inv_glass", 2], ["AP_inv_filament", 2]], ["noSchematic"]]],
    ["carbon_weave",    [ 6, [["AP_inv_oilp", 8], ["AP_inv_redshift", 4], ["AP_inv_filament", 3]], ["noSchematic"]]],
    ["nanofoam",        [ 7, [["AP_inv_polymer_pellet", 4], ["AP_inv_redshift", 2], ["AP_inv_filament", 4]], ["noSchematic"]]],
    ["ballistic_plate", [ 9, [["AP_inv_iron_r", 6], ["AP_inv_carbon_weave", 2], ["AP_inv_filament", 6]], ["noSchematic"]]],

    // ---- lower receivers. THE ONLY GUN PART THE PRINTER MAKES. A weapon is assembled at a
    // gunsmith bench from one of these plus the rest of its materials and its schematic, so the
    // printer's level gates which weapon CLASSES a player can supply and the bench gates the
    // specific gun. No schematic on these: the receiver is feedstock, and gating both halves of a
    // two-stage chain behind schematics would mean finding two to build one rifle.
    ["lower_pistol",    [ 4, [["AP_inv_filament", 10], ["AP_inv_iron_r", 2]], ["noSchematic"]]],
    ["lower_smg",       [ 8, [["AP_inv_filament", 18], ["AP_inv_iron_r", 4], ["AP_inv_circuit_lamina", 1]], ["noSchematic"]]],
    ["lower_rifle",     [13, [["AP_inv_filament", 34], ["AP_inv_iron_r", 6], ["AP_inv_carbon_weave", 2]], ["noSchematic"]]],
    ["lower_heavy",     [18, [["AP_inv_filament", 60], ["AP_inv_iron_r", 10], ["AP_inv_carbon_weave", 4], ["AP_inv_ballistic_plate", 1]], ["noSchematic"]]],

    // ---- the bench itself is printed, like the printers are
    ["gunsmith_bench",  [10, [["AP_inv_filament", 30], ["AP_inv_iron_r", 20], ["AP_inv_circuit_lamina", 2]], ["noSchematic"]]],

    // ---- the printers themselves. The i3 needs no schematic on purpose: it is the bootstrap, and
    // a machine you cannot build without already owning a machine is a dead economy. The CoreXY is
    // schematic-gated and is the single biggest capital purchase in the tier.
    ["printer_i3",      [ 3, [["AP_inv_filament", 12], ["AP_inv_circuit_lamina", 2],
                              ["AP_inv_iron_r", 4]], ["noSchematic"]]],
    ["printer_corexy",  [12, [["AP_inv_filament", 40], ["AP_inv_circuit_lamina", 6],
                              ["AP_inv_carbon_weave", 4], ["AP_inv_nanofoam", 2],
                              ["AP_inv_iron_r", 8]], []]],

    // ---- utility, the low band. Cheap, fast, and the reason levels 1-8 are reachable at all.
    ["ToolKit",             [ 1, [["AP_inv_filament", 4], ["AP_inv_iron_r", 2]], []]],
    ["FirstAidKit",         [ 2, [["AP_inv_filament", 3], ["AP_inv_polymer_pellet", 2]], []]],
    ["ItemGPS",             [ 5, [["AP_inv_filament", 6], ["AP_inv_circuit_lamina", 2]], []]],
    ["Binocular",           [ 6, [["AP_inv_filament", 8], ["AP_inv_optic_blank", 2]], []]],
    ["NVGoggles",           [ 8, [["AP_inv_filament", 14], ["AP_inv_optic_blank", 3], ["AP_inv_circuit_lamina", 2]], []]],
    ["Rangefinder",         [10, [["AP_inv_filament", 20], ["AP_inv_optic_blank", 4], ["AP_inv_circuit_lamina", 3]], []]],

    // ---- optics. Deliberately the long-range tier: the Factory already mints ACO / Holosight /
    // Arco / DMS and the two systems must never mint the same class (tools/fab_check.py asserts
    // it). When the Factory is cut back to vehicles only and its 136 non-vehicle recipes migrate
    // here, those short-range optics arrive with them.
    ["optic_SOS",           [12, [["AP_inv_filament", 22], ["AP_inv_optic_blank", 5], ["AP_inv_circuit_lamina", 2]], []]],
    ["optic_LRPS",          [15, [["AP_inv_filament", 30], ["AP_inv_optic_blank", 7], ["AP_inv_circuit_lamina", 3]], []]],
    ["optic_NVS",           [17, [["AP_inv_filament", 36], ["AP_inv_optic_blank", 6], ["AP_inv_circuit_lamina", 5]], []]],

    // ---- carried gear. Backpacks and headgear are categories the Factory does not touch at all,
    // which makes them safe ground for P0.
    ["B_Kitbag_cbr",        [ 4, [["AP_inv_filament", 8], ["AP_inv_carbon_weave", 1]], []]],
    ["B_Carryall_cbr",      [11, [["AP_inv_filament", 18], ["AP_inv_carbon_weave", 3], ["AP_inv_nanofoam", 1]], []]],
    ["H_HelmetB",           [13, [["AP_inv_filament", 24], ["AP_inv_ballistic_plate", 1], ["AP_inv_nanofoam", 2]], []]],

    // ---- the two weapons 3dprint.md pulled from the rebel armory on 2026-06-13 specifically so
    // they could come back as printables. The _plb3dPrint filter in fn_weaponShopCfg.sqf STAYS in
    // place (option 2 of that doc), so fabrication is their only source.
    //
    // "bench" flag: weapons are ASSEMBLED at a gunsmith bench, never printed. Each carries exactly
    // one printed lower receiver -- that is the whole printed part of a gun -- plus its materials
    // and its schematic. Both of these are heavy weapons, so both take lower_heavy, which the
    // printer only makes at level 18.
    ["srifle_DMR_02_F",     [16, [["AP_inv_lower_heavy", 1], ["AP_inv_ballistic_plate", 2], ["AP_inv_optic_blank", 1], ["AP_inv_carbon_weave", 4]], ["bench"]]],
    ["MMG_02_F",            [18, [["AP_inv_lower_heavy", 1], ["AP_inv_ballistic_plate", 4], ["AP_inv_carbon_weave", 6], ["AP_inv_circuit_lamina", 2]], ["bench"]]]
])];};

// Print duration in seconds for ONE unit at tier 1, keyed by the recipe's engine category. A table
// beats a per-recipe `time` field: one place to tune, and a new recipe gets a sane default with no
// authoring. The tier speed multiplier divides this; the job's finish_at is computed server-side.
if (isNil {localNamespace getVariable "AP_fabDurations"}) then {localNamespace setVariable ["AP_fabDurations", createHashMapFromArray [
    ["intermediate",  60],
    ["utility",      180],
    ["optic",        300],
    ["vest",         600],
    ["weapon",      1800]
]];};

// Qualifying prints needed to LEAVE each level (the level +/-1 window decides what qualifies).
// Summed, this is ~450 prints to reach 20. The system this was ported from needed 1,590, which is
// far too steep for this server -- these numbers are expected to move after the first playtest.
if (isNil {localNamespace getVariable "AP_fabXpCurve"}) then {localNamespace setVariable ["AP_fabXpCurve", createHashMapFromArray [
    [ 1,  8], [ 2, 10], [ 3, 12], [ 4, 14], [ 5, 16], [ 6, 18], [ 7, 20], [ 8, 22], [ 9, 24], [10, 26],
    [11, 28], [12, 30], [13, 32], [14, 34], [15, 36], [16, 38], [17, 40], [18, 42], [19, 44], [20,  0]
]];};
private _fabMap = localNamespace getVariable "AP_fabMap";

// Category is DERIVED from the engine config, not stored on the row. That is the whole point of a
// category-keyed duration table: a recipe added tomorrow gets a sane time with nothing authored.
// Anything that is not an engine class is an intermediate -- those are our own virtual items.
private _catOf = {
    params [["_k", "", [""]]];
    if (!isClass (configFile >> "CfgWeapons" >> _k)) exitWith {"intermediate"};
    if ((_k select [0, 6]) isEqualTo "optic_") exitWith {"optic"};
    if (_k isKindOf ["Rifle", configFile >> "CfgWeapons"]
        || {_k isKindOf ["Pistol", configFile >> "CfgWeapons"]}) exitWith {"weapon"};
    // Vests carry ItemInfo type 701; uniforms 801, backpacks are CfgVehicles. 701 is the only one
    // this table needs to separate out today.
    if (getNumber (configFile >> "CfgWeapons" >> _k >> "ItemInfo" >> "type") isEqualTo 701) exitWith {"vest"};
    "utility"
};

private _return = switch (_mode) do {

    case "getRecipe": { +(_fabMap getOrDefault [_key, []]) };

    case "hasRecipe": { _key in _fabMap };

    case "getAll":    { +(keys _fabMap) };

    case "duration":  {
        private _row = _fabMap getOrDefault [_key, []];
        if (_row isEqualTo []) exitWith {0};
        (localNamespace getVariable "AP_fabDurations") getOrDefault [([_key] call _catOf), 180]
    };

    // _key is a LEVEL here, not a classname.
    case "xpFor":     { (localNamespace getVariable "AP_fabXpCurve") getOrDefault [_key, 0] };

    // [<backbone item key>, <ND ten-thousandths charged per recursive unit>]. Both are config, not
    // constants buried in the resolver -- the system this came from hardcoded its multiplier and
    // silently stopped tracking the shop the day that shop's price changed. Ten-thousandths, and
    // an integer, because ND is DECIMAL(20,4) and SQF floats must never touch the ledger.
    case "backbone":  { ["filament", 500] };

    // [jobSlots, speedMult, maxLevel, itemKey, model, displayName, kind, collides, halfHeight]
    //
    // Two PRINTER tiers plus the bench. The printers differ by slots, speed and level cap -- a
    // third printer tier was dropped because a tier whose only difference is a stat line is a tier
    // players cannot see, and there are two printer models.
    //
    // The BENCH is a third machine rather than a third tier: it takes "bench" recipes (weapons)
    // and a printer takes everything else, which is what makes the two-stage chain a chain. It
    // shares the whole place / queue / collect / pickup path because its lifecycle is identical.
    // `collides` is true only for it. Both printer tiers now draw the F770 (one 2.2 m machine in
    // six parts, custom_p3ds\fab_parts_data.sqf; its body has one collision box) but keep the
    // proximity interaction they always had, so one targeting path serves every machine. The p3d
    // column is the parts BASENAME for the F770 (fabModel resolves _body_r1 etc. from the data
    // file) and the lift column is informational for it -- the data file's measured half-height
    // is what fabModel uses.
    case "tier":      {
        switch (_key) do {
            case 2: {[3, 2.0, 20, "printer_corexy", "ap_printer_f770", "CoreXY Fabricator", "printer", false, 0.9075]};
            case 3: {[1, 1.0, 20, "gunsmith_bench", "ap_gunsmith_bench_r2", "Gunsmith Bench", "bench", true, 0.9463]};
            default {[1, 1.0, 10, "printer_i3", "ap_printer_f770", "i3 Fabricator", "printer", false, 0.9075]};
        }
    };

    case "tierCount": { 3 };

    // Which machine a recipe belongs on. Weapons carry the "bench" flag; everything else prints.
    case "machineFor": {
        private _row = _fabMap getOrDefault [_key, []];
        if (_row isEqualTo []) exitWith {""};
        if ("bench" in (_row select 2)) then {"bench"} else {"printer"}
    };

    default {[]};
};

_return
