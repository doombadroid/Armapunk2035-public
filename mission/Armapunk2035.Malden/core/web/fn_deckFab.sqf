/*
    AP_fnc_deckFab -- the deck's FABRICATOR app (approved mock deck-fabricator).

    Replaces dialog 1810 as the front door (the native stays as the
    AP_deckApps=false fallback). Same trust split as the native client: every
    number here is ADVISORY -- APS_fnc_fabSRV re-reads recipe, level, schematic,
    tier cap and proximity from its own copies and refuses on its own terms.

    ["data"]            payload for the "fab" channel
    ["queue", key, qty] consume materials client-side, send intent (fabQueue port)
    ["collect"]         ask for the finished jobs in this machine
    ["buy", key]        schematic purchase -- APS_fnc_fabGrantSRV charges ND itself
    ["burn", key]       schematic -> tradeable shard (page arms the click)

    The recipe list rides ONE push: 579 rows with parts and have-counts is a few
    hundred KB of JSON once per open, against a page that would otherwise make
    579 calls. Have-counts go stale the moment a queue consumes materials, so
    every verb that moves items pushes a rebuilt payload behind its answer.
*/
params [["_verb", "", [""]], ["_a", "", [""]], ["_b", 0, [0]]];

private _no   = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes  = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };
private _anchor = missionNamespace getVariable ["AP_fabAnchor", objNull];
if (isNull _anchor) then { _anchor = call AP_fnc_fabNear; AP_fabAnchor = _anchor; };

private _nameOf = {
    params ["_key"];
    private _isVirt = (["getItemRow", _key] call AP_fnc_virtItemCfg) isNotEqualTo [];
    if (_isVirt) exitWith { ["getName", _key] call AP_fnc_virtItemCfg };
    private _n = [configFile >> "CfgWeapons" >> _key] call BIS_fnc_displayName;
    if (_n isEqualTo "") then { _n = [configFile >> "CfgVehicles" >> _key] call BIS_fnc_displayName; };
    if (_n isEqualTo "") then { _n = [configFile >> "CfgMagazines" >> _key] call BIS_fnc_displayName; };
    if (_n isEqualTo "") then { _key } else { _n }
};

switch (toLower _verb) do {

case "data": {
    if (isNull _anchor) exitWith { createHashMapFromArray [["gone", true]] };
    private _tier = _anchor getVariable ["AP_fabTier", 1];
    private _tcfg = ["tier", _tier] call AP_fnc_fabCfg;
    private _kind = _tcfg param [6, "printer"];
    private _cap  = _tcfg param [2, 10];
    private _speed = _tcfg param [1, 1];
    private _lvl  = missionNamespace getVariable ["AP_fabLevel", 1];
    private _known = missionNamespace getVariable ["AP_fabSchem", []];
    private _free = missionNamespace getVariable ["AP_fabFreeBuild", false];

    private _rows = [];
    {
        private _key = _x;
        private _row = ["getRecipe", _key] call AP_fnc_fabCfg;
        _row params ["_rl", "_parts", "_flags"];
        private _rk = if ("bench" in _flags) then {"bench"} else {"printer"};
        if (_rk isEqualTo _kind) then {
            private _knows = ("noSchematic" in _flags) || {_key in _known};
            if (_free || _knows) then {
                _rows pushBack (createHashMapFromArray [
                    ["key", _key], ["name", [_key] call _nameOf], ["lvl", _rl],
                    ["parts", _parts apply { [
                        ["getName", (_x select 0) select [7]] call AP_fnc_virtItemCfg,
                        _x select 1,
                        missionNamespace getVariable [(_x select 0), 0]
                    ] }],
                    ["secs", (["duration", _key] call AP_fnc_fabCfg) / _speed],
                    ["fee", ([_key] call AP_fnc_fabFee) param [0, 0]],
                    ["known", _knows], ["burnable", _key in _known]
                ]);
            };
        };
    } forEach (["getAll"] call AP_fnc_fabCfg);

    // schematic vendor: everything sold for this machine kind that is not known
    private _shop = [];
    {
        private _srow = ["get", _x] call AP_fnc_fabSchemCfg;
        private _rflags = (["getRecipe", _x] call AP_fnc_fabCfg) param [2, []];
        private _rk2 = if ("bench" in _rflags) then {"bench"} else {"printer"};
        if (_rk2 isEqualTo _kind && {"shop" in (_srow select 1)} && {!(_x in _known)}) then {
            _shop pushBack (createHashMapFromArray [
                ["key", _x], ["name", [_x] call _nameOf],
                ["lvl", (["getRecipe", _x] call AP_fnc_fabCfg) param [0, 1]],
                ["price", ([_x] call AP_fnc_fabFee) param [1, "?"]],
                ["rarity", _srow select 2]
            ]);
        };
    } forEach (["getAll"] call AP_fnc_fabSchemCfg);

    private _jobs = [];
    private _myId = _anchor getVariable ["AP_fabId", -1];
    private _all = missionNamespace getVariable ["AP_fabJobs", []];
    private _me = _all param [_all findIf { (_x select 0) isEqualTo _myId }, []];
    {
        _x params ["_jid", "_recipe", "_qty", "_remain", "_ready"];
        _jobs pushBack (createHashMapFromArray [
            ["id", _jid], ["name", [_recipe] call _nameOf], ["qty", _qty],
            ["remain", _remain], ["ready", _ready]
        ]);
    } forEach (_me param [3, []]);

    createHashMapFromArray [
        ["machine", _tcfg param [5, "Fabricator"]], ["kind", _kind],
        ["cap", _cap], ["slots", _me param [2, 1]],
        ["lv", _lvl], ["xp", missionNamespace getVariable ["AP_fabXp", 0]],
        ["xpNext", ["xpFor", _lvl] call AP_fnc_fabCfg],
        ["free", _free], ["nd", AP_nd toFixed 4],
        ["recipes", _rows], ["shop", _shop], ["jobs", _jobs],
        ["ready", missionNamespace getVariable ["AP_fabListReady", false]]
    ]
};

case "queue": {
    if (isNull _anchor) exitWith { ["No fabricator here."] call _no };
    if ((player distance _anchor) > 6) exitWith { ["Stand at the fabricator."] call _no };
    private _key = _a;
    private _qty = (_b max 1) min 20;
    private _row = ["getRecipe", _key] call AP_fnc_fabCfg;
    if (_row isEqualTo []) exitWith { ["No such recipe."] call _no };
    _row params ["", "_parts", ""];
    if (missionNamespace getVariable ["AP_fabFreeBuild", false]) exitWith {
        [["queue", [player, _anchor getVariable ["AP_fabId", -1], _key, _qty]], "APS_fnc_fabSRV", 2] spawn AP_fnc_MP;
        ["Queued (free build)."] call _yes
    };
    // Check EVERYTHING before removing ANYTHING (fabQueue's rule, kept verbatim)
    private _short = _parts findIf { (missionNamespace getVariable [(_x select 0), 0]) < ((_x select 1) * _qty) };
    if (_short != -1) exitWith {
        [format ["Not enough %1.", ["getName", ((_parts select _short) select 0) select [7]] call AP_fnc_virtItemCfg]] call _no };
    private _taken = [];
    private _ok = true;
    {
        _x params ["_var", "_n"];
        private _item = _var select [7];
        if (_ok) then {
            if ([false, _item, _n * _qty] call AP_fnc_handleInv) then { _taken pushBack [_item, _n * _qty]; }
            else { _ok = false; };
        };
    } forEach _parts;
    if (!_ok) exitWith {
        { [true, _x select 0, _x select 1] call AP_fnc_handleInv; } forEach _taken;
        ["The fabricator could not take those materials. Nothing was consumed."] call _no
    };
    [["queue", [player, _anchor getVariable ["AP_fabId", -1], _key, _qty]], "APS_fnc_fabSRV", 2] spawn AP_fnc_MP;
    ["Loaded. The machine reports back in a moment."] call _yes
};

case "collect": {
    if (isNull _anchor) exitWith { ["No fabricator here."] call _no };
    if ((player distance _anchor) > 6) exitWith { ["Stand at the fabricator."] call _no };
    [["collect", [player, _anchor getVariable ["AP_fabId", -1]]], "APS_fnc_fabSRV", 2] spawn AP_fnc_MP;
    ["Collecting..."] call _yes
};

case "buy": {
    [["buy", [player, _a]], "APS_fnc_fabGrantSRV", 2] spawn AP_fnc_MP;
    ["Purchase sent."] call _yes
};

case "burn": {
    if !(_a in (missionNamespace getVariable ["AP_fabSchem", []])) exitWith {
        ["You do not hold that schematic."] call _no };
    // verb is "burn" -- "shard" is the USE of a shard, and sending it here would
    // try to redeem a shard the player does not hold instead of burning
    [["burn", [player, _a]], "APS_fnc_fabGrantSRV", 2] spawn AP_fnc_MP;
    ["Burn sent -- you forget the schematic, the shard lands in your inventory."] call _yes
};

default { ["unknown fab verb"] call _no };
};
