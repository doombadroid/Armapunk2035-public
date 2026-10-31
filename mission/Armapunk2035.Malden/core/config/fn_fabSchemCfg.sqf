params [["_mode", "", [""]], ["_key", "", ["", 0]]];
/*
    fn_fabSchemCfg.sqf  (AP_fnc_fabSchemCfg)  -- how a printer recipe is unlocked.

        ["get",     "<recipeKey>"] call AP_fnc_fabSchemCfg  -> [dropchance, sources, rarity] or []
        ["getAll"]                 call AP_fnc_fabSchemCfg  -> every gated recipe key
        ["pool",    "<source>"]    call AP_fnc_fabSchemCfg  -> keys droppable from that source
        ["rarity",  "<rarity>"]    call AP_fnc_fabSchemCfg  -> keys of that rarity
        ["shard",   "<itemKey>"]   call AP_fnc_fabSchemCfg  -> the rarity a shard item rolls

    A ROW IS THREE FIELDS:

        <recipeKey> -> [ <dropchance 1-in-N>, [<source>, ...], "<rarity>" ]

    RARITY IS A FIELD. In the system this was ported from it was not: the shop sorted its three
    blueprint tiers by STRING-MATCHING THE ICON PATH, one .paa per tier, which worked and was the
    most fragile load-bearing decision in the whole design -- renaming an icon silently
    reclassified a quarter of the blueprint economy. It costs one key to never have that problem.

    SOURCES are plain strings, not the ASCII-codepoints-in-a-digit-string trick the original used
    ("dropplace" = "123", tested with `49 in toArray`). Same property -- a designer changes where
    something drops by editing one field, with no code change -- and it can be read aloud.

    THE POOL IS PICKED UNIFORMLY, THEN THE ROW'S OWN RARITY IS ROLLED. So a rare schematic is not
    rarer to be *picked* than a common one; it is rarer because it then fails its own 1-in-N check.
    That is worth knowing before tuning: the chance of getting ANY schematic from one action is the
    mean of 1/dropchance across the pool, not the best entry in it.

    Every gated recipe MUST have a row here and every row MUST name a real recipe --
    tools/fab_check.py asserts the bijection both ways, case-exactly. The ported system shipped 39
    recipes nothing could unlock and one blueprint for a recipe that did not exist, and both are
    invisible at runtime.
*/

// Hand-authored rows plus the generated block, exactly as fn_fabCfg does it. Hand rows win.
// Both tables live in localNamespace, as fn_fabCfg's do (audit r2items): APS_fnc_fabGrantSRV rolls, prices and
// grants schematics from them, and a client publicVariable overwrites a missionNamespace global on the server too.
if (isNil {localNamespace getVariable "AP_fabSchemMap"}) then {localNamespace setVariable ["AP_fabSchemMap", createHashMapFromArray (((call AP_fnc_fabGen) select 1) + [
    // ---- common: the early ladder. Cheap to find, cheap to buy, and the reason a new player has
    // something to chase before they can afford anything else.
    ["ToolKit",         [ 25, ["gather", "mine", "shop"], "common"]],
    ["FirstAidKit",     [ 25, ["gather", "mine", "shop"], "common"]],
    ["B_Kitbag_cbr",    [ 40, ["gather", "mine", "shop"], "common"]],
    ["ItemGPS",         [ 50, ["gather", "mine", "shop"], "common"]],
    ["Binocular",       [ 50, ["gather", "mine", "shop"], "common"]],
    ["NVGoggles",       [ 70, ["gather", "mine", "shop"], "common"]],

    // ---- rare
    ["Rangefinder",     [110, ["mine", "shop", "quest"], "rare"]],
    ["B_Carryall_cbr",  [ 90, ["gather", "mine", "shop"], "rare"]],
    ["optic_SOS",       [130, ["mine", "shop", "heist"], "rare"]],
    ["H_HelmetB",       [140, ["mine", "shop", "heist"], "rare"]],
    ["optic_LRPS",      [180, ["shop", "heist", "quest"], "rare"]],
    // The CoreXY is the single biggest unlock in the tier -- it is the machine that prints the top
    // half of the catalogue -- so it is deliberately not a field drop.
    ["printer_corexy",  [200, ["shop", "quest"], "rare"]],

    // ---- epic: group content and the vendor, never a gather roll.
    ["optic_NVS",       [260, ["shop", "heist"], "epic"]],
    ["srifle_DMR_02_F", [320, ["shop", "heist"], "epic"]],
    ["MMG_02_F",        [400, ["shop", "heist"], "epic"]]
])];};

// Which rarity each shard item rolls from. The shards are the tradeable form of a schematic --
// account state cannot be listed on the Exchange, but an item can.
if (isNil {localNamespace getVariable "AP_fabShardMap"}) then {localNamespace setVariable ["AP_fabShardMap", createHashMapFromArray [
    ["shard", "common"], ["shard_rare", "rare"], ["shard_epic", "epic"]
]];};
private _schemMap = localNamespace getVariable "AP_fabSchemMap";

private _return = switch (_mode) do {

    case "get":     { +(_schemMap getOrDefault [_key, []]) };

    case "getAll":  { +(keys _schemMap) };

    // forEach over a HashMap binds _x to the VALUE and _y to the KEY -- the opposite way round from
    // every array forEach in this codebase, and silently so: reading _x as the key here yields an
    // array where a string is expected, `_key in (_y select 1)` indexes a string, and both pools
    // come back empty. An empty pool is not an error, it is simply a faucet that never drops, so
    // this would have looked like unlucky RNG rather than a bug.
    case "pool":    {
        private _out = [];
        { if (_key in (_x select 1)) then { _out pushBack _y }; } forEach _schemMap;
        _out sort true;          // deterministic order: selectRandom over a set that reorders
        _out                     // between machines is a desync waiting to be debugged
    };

    case "rarity":  {
        private _out = [];
        { if ((_x select 2) isEqualTo _key) then { _out pushBack _y }; } forEach _schemMap;
        _out sort true;
        _out
    };

    case "shard":   { (localNamespace getVariable "AP_fabShardMap") getOrDefault [_key, ""] };

    default {[]};
};

_return
