/*
    AP_fnc_deckGarage -- the deck's GARAGE app (approved mock deck-garage-a).

    The pull/sell/repair/to-gang logic is NOT here: those four natives now take
    the row as a parameter and this function only looks the row up and forwards
    it. One copy of the pull logic, on purpose -- it already exists in three
    near-copies across the codebase and every pad-height fix has had to land in
    all of them.

    ["data"]        payload for the "garage" channel (from AP_garageData)
    ["get", id]     -> fn_vehicleGaragePull  [row]
    ["sell", id]    -> fn_vehicleGarageSell  [row]   (page arm-confirms)
    ["fix", id]     -> fn_vehicleGarageRepairRefuel [row, true]
    ["gang", id]    -> fn_gangGarageAdd      [row, true]
    ["mods", id]    -> closes the deck, opens the NATIVE mod dialog. Interim:
                       the mod tree is its own 135-line screen and gets its own
                       pass; a wrong port here would sell upgrades that do not
                       apply. The deck reopens on the garage when it closes.
*/
params [["_verb", "", [""]], ["_id", -1, [0]], ["_changes", [], [[]]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };

private _rowOf = {
    params ["_id"];
    private _r = AP_garageData param [AP_garageData findIf { (_x select 0) isEqualTo _id }, []];
    if (_r isEqualTo []) exitWith { [] };
    [_r select 2, _r select 7, _r select 8, _r select 9, _r select 10, _r select 11, _r select 12]
};

switch (toLower _verb) do {

case "data": {
    private _rows = [];
    {
        private _class = _x select 2;
        private _info = [_class] call AP_fnc_fetchVehInfo;
        private _wear = _x param [11, [0, 1, 0]];
        private _cfgRow = ["getVehicleRowParsed", "", _class] call AP_fnc_vehicleConfig;
        private _sell = round (_cfgRow param [8, 0]);
        private _shopKeys = _cfgRow param [3, []];
        private _isND = (_shopKeys isEqualType []) && {("nd_car" in _shopKeys) || {"nd_priced" in _shopKeys}};
        private _cap = _info param [12, 0];
        private _fuel = _wear param [1, 1];
        // NOTE: _x inside findIf shadows the outer row -- capture the plate first
        private _plate = _x select 7;
        private _isOut = !((AP_vehicles findIf {
            (_x getVariable ["AP_dbInfo", []] param [1, -1]) isEqualTo _plate }) isEqualTo -1);
        // rigs share the flatbed classname; the DB row's rig_kind is the identity
        private _rigK = format ["%1", _x param [13, ""]];
        private _dispName = switch (_rigK) do {
            case "extractor": {"Resource Extractor (HEMTT)"};
            case "processor": {"Resource Processor (HEMTT)"};
            default {_info param [3, _class]};
        };
        _rows pushBack (createHashMapFromArray [
            ["id", _x select 0], ["class", _class],
            ["name", _dispName], ["pic", _info param [2, ""]],
            ["rig", _rigK],
            ["recall", _x param [14, false]],
            ["plate", format ["%1", _x param [12, _plate]]],
            ["outNow", _isOut],
            ["dmg", round ((_wear param [0, 0]) * 100)],
            ["fuel", round (_fuel * 100)],
            ["sell", _sell], ["nd", _isND],
            ["fixCost", round ((_cap * (1 - _fuel)) * 6 + 150)],
            ["talent", ["talentCheck", "", _class] call AP_fnc_vehicleConfig],
            ["kind", switch (true) do {
                case (_class isKindOf "Air"): {"AIR"};
                case (_class isKindOf "Ship"): {"SEA"};
                default {"LAND"} }]
        ]);
    } forEach AP_garageData;

    // out = spawned right now, from the client's own key ring
    private _out = [];
    {
        private _db = _x getVariable ["AP_dbInfo", []];
        if (_db isNotEqualTo [] && {alive _x}) then {
            _out pushBack (createHashMapFromArray [
                ["name", getText (configFile >> "CfgVehicles" >> (typeOf _x) >> "displayName")],
                ["plate", format ["%1", _db param [1, ""]]],
                ["dist", round (player distance _x)]
            ]);
        };
    } forEach AP_vehicles;

    AP_gang_data params [["_gid", -1, [0]], "", ["_grank", 5, [0]]];
    createHashMapFromArray [
        ["rows", _rows], ["out", _out],
        ["bank", AP_atmcash],
        ["canGang", (_gid isNotEqualTo -1) && {_grank <= 3} && {AP_effSide isEqualTo civilian}],
        ["ready", true]
    ]
};

case "get": {
    private _row = [_id] call _rowOf;
    if (_row isEqualTo []) exitWith { ["That vehicle is not in this garage."] call _no };
    private _talent = ["talentCheck", "", _row select 0] call AP_fnc_vehicleConfig;
    if (_talent isNotEqualTo "") exitWith {
        [format ["You need the %1 talent to pull this.", _talent]] call _no };
    [_row] spawn AP_fnc_vehicleGaragePull;
    ["Pulling -- watch the pad."] call _yes
};

case "sell": {
    private _row = [_id] call _rowOf;
    if (_row isEqualTo []) exitWith { ["That vehicle is not in this garage."] call _no };
    [_row] spawn AP_fnc_vehicleGarageSell;
    ["Sale sent."] call _yes
};

case "fix": {
    private _row = [_id] call _rowOf;
    if (_row isEqualTo []) exitWith { ["That vehicle is not in this garage."] call _no };
    [_row, true] spawn AP_fnc_vehicleGarageRepairRefuel;
    ["Repair sent."] call _yes
};

case "gang": {
    private _row = [_id] call _rowOf;
    if (_row isEqualTo []) exitWith { ["That vehicle is not in this garage."] call _no };
    [_row, true] spawn AP_fnc_gangGarageAdd;
    ["Transfer sent."] call _yes
};

case "recall": {
    private _r = [_id] call _rowOf;
    if (_r isEqualTo []) exitWith { ["no such vehicle"] call _no };
    ["set", _id] remoteExec ["APS_fnc_summonSRV", 2];
    // the server flips the column; refresh the rows so the star moves
    [] spawn { uiSleep 1.2; [[player, "Car"], "APS_fnc_getVehicles", 2] spawn AP_fnc_MP; };
    ["recall vehicle set"] call _yes
};

// ------------------------------------------------------------ MOD BAY ------
// (needstest 2026-08-26) The native hand-over is gone: the bay is a garage tab.
// Slot layout is the shop array the natives juggle: 0-8 = the mods DB slots,
// 9 = colour, 10 = plate, 11 = autopilot (DB mods slot 9). Costs are
// recomputed HERE from the same configs the combos priced from -- including
// the two rules the native combo handler carried: already-fitted is free, and
// MOTORIST waives the autopilot module (value 1) only, never the retrofit.
// One rule is deliberately FIXED rather than ported: the native skin check
// compared the skin id against shop slot 5 (the tracker), so "already fitted"
// skins still cost $2,500 -- here it compares against the colour slot.
case "moddata": {
    private _r = AP_garageData param [AP_garageData findIf { (_x select 0) isEqualTo _id }, []];
    if (_r isEqualTo []) exitWith { createHashMapFromArray [["gone", true]] };
    private _class = _r select 2;
    private _mods = +(_r param [10, [0,0,0,0,0,0,0,0,0]]);
    if (count _mods < 10) then { _mods resize 10; };  // DB slot 9 = autopilot
    private _cfg = call AP_fnc_vehicleModConfig;
    private _slots = [];
    {
        _x params ["_slot", "_mName", "_opts"];
        if (_opts isNotEqualTo []) then {
            private _shopIdx = if (_slot isEqualTo 9) then { 11 } else { _forEachIndex };
            private _curVal = if (_slot isEqualTo 9) then { _mods param [9, 0] } else { _mods param [_forEachIndex, 0] };
            _slots pushBack (createHashMapFromArray [
                ["idx", _shopIdx], ["name", _mName], ["cur", _curVal],
                ["opts", _opts apply { createHashMapFromArray [
                    ["label", _x select 0], ["val", _x select 1], ["cost", _x select 2] ] }]
            ]);
        };
    } forEach _cfg;
    private _sideFlag = switch (AP_effSide) do { case west: {"cop"}; case independent: {"med"}; default {"civ"} };
    private _isCar = _class isKindOf "Car";
    private _isMed = AP_effSide isEqualTo independent;
    createHashMapFromArray [
        ["id", _id], ["class", _class],
        ["slots", _slots],
        ["horns", ([1] call AP_fnc_hornCfg) apply { createHashMapFromArray [
            ["id", _x select 0], ["name", _x select 1], ["cost", _x select 2] ] }],
        ["curHorn", _mods param [3, 0]],
        ["skins", (["modTextures", _class, _sideFlag] call AP_fnc_vehicleTextures) apply { createHashMapFromArray [
            ["id", _x select 0], ["name", _x select 1] ] }],
        ["curSkin", _r param [8, -1]],
        ["plate", format ["%1", _r param [12, ""]]],
        // the native enable matrix, as data: what this vehicle may fit
        ["canCarOnly", _isCar],            // horn / handling / nitrous / plate
        ["canDoors", _class in ["O_T_LSV_02_unarmed_F", "B_T_LSV_01_unarmed_F"]],
        ["canAutopilot", (_class isKindOf "LandVehicle") || {[_class] call AP_fnc_isRotorcraft}],
        ["canSkin", !_isMed], ["canTrunk", !_isMed],
        ["bank", AP_atmcash]
    ]
};

case "modbuy": {
    if (count _changes < 12) exitWith { ["Nothing staged."] call _no };
    private _rIdx = AP_garageData findIf { (_x select 0) isEqualTo _id };
    if (_rIdx isEqualTo -1) exitWith { ["That vehicle is not in this garage."] call _no };
    private _r = AP_garageData select _rIdx;
    private _class = _r select 2;
    private _plate = _r select 7;
    private _mods = +(_r param [10, [0,0,0,0,0,0,0,0,0]]);
    if (count _mods < 10) then { _mods resize 10; };
    private _startShop = (_mods select [0, 9]) + [_r param [8, -1], format ["%1", _r param [12, ""]], _mods param [9, 0]];

    // recompute every cost from config -- the page's total is display only
    private _cfg = call AP_fnc_vehicleModConfig;
    private _cost = 0;
    {
        private _shopIdx = _x;
        private _newVal = _changes select _shopIdx;
        private _oldVal = _startShop select _shopIdx;
        if (!(_newVal isEqualTo _oldVal)) then {
            switch (true) do {
                case (_shopIdx in [0, 1, 2, 4, 5, 6, 7, 8]): {
                    private _opts = (_cfg select _shopIdx) select 2;
                    private _o = _opts select { (_x select 1) isEqualTo _newVal };
                    _cost = _cost + ((_o param [0, ["", 0, 0]]) param [2, 0]);
                };
                case (_shopIdx isEqualTo 3): {
                    private _h = ([1] call AP_fnc_hornCfg) select { (_x select 0) isEqualTo _newVal };
                    _cost = _cost + ((_h param [0, [0, "", 0]]) param [2, 0]);
                };
                case (_shopIdx isEqualTo 9):  { _cost = _cost + 2500 };   // skin
                case (_shopIdx isEqualTo 10): {
                    private _p = format ["%1", _newVal];
                    if (_p isNotEqualTo "") then {
                        if !([_p] call AP_fnc_checkPlate) exitWith { _cost = -999999999 };
                        _cost = _cost + 2500;
                    };
                };
                case (_shopIdx isEqualTo 11): {
                    private _opts9 = (_cfg select 9) select 2;
                    private _o9 = _opts9 select { (_x select 1) isEqualTo _newVal };
                    private _c9 = ((_o9 param [0, ["", 0, 0]]) param [2, 0]);
                    if (201 in AP_side_talents && {_newVal isEqualTo 1}) then { _c9 = 0; };
                    _cost = _cost + _c9;
                };
            };
        };
    } forEach [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    if (_cost < 0) exitWith { ["That plate text is not allowed."] call _no };
    if (_cost isEqualTo 0) exitWith { ["Nothing changed."] call _no };
    if !([_cost] call AP_fnc_debitCard) exitWith { [format ["You cannot afford $%1.", [_cost] call AP_fnc_numberText]] call _no };
    if (_cost >= 3500) then { [6] call AP_fnc_ClupdatePartial; };

    private _updateMods = (_changes select [0, 9]) + [_changes param [11, 0]];
    private _newPlate = format ["%1", _changes select 10];
    if (_newPlate isEqualTo "") then { _newPlate = _startShop select 10; };
    _r set [10, _updateMods];
    _r set [8, _changes select 9];
    _r set [12, _newPlate];
    [[getPlayerUID player, _class, _plate, _updateMods, _changes select 9, _newPlate], "APS_fnc_updateVehicleMods", 2] call AP_fnc_MP;
    [["-VEHMODS-", player, profileName, format ["deck mod bay: %1 (%2) mods %3 skin %4 plate %5 for $%6",
        _class, _plate, _updateMods, _changes select 9, _newPlate, [_cost] call AP_fnc_numberText]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    [format ["Fitted -- $%1.", [_cost] call AP_fnc_numberText]] call _yes
};

default { ["unknown garage verb"] call _no };
};
