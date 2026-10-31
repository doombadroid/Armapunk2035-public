/*
    AP_fnc_deckTrunk -- the deck's TRUNK app (approved mock deck-trunk-b, the
    queue-and-commit alternate).

    Transfer logic is NOT here: fn_takeInventory / fn_storeInventory now take
    item + qty as parameters and this only forwards, one move at a time, in the
    order the player queued them. VIRTUAL ONLY, which is what the native trunk
    dialog is for vehicles anyway ("Physical inventory via this method is not
    allowed on vehicles" -- fn_refreshInventory:3); gear goes through Arma's own
    inventory as it always has.

    ["data"]                 payload for the "trunk" channel
    ["batch", [[dir,item,qty],...]]  commit the queue: dir "take"|"store"
*/
params [["_verb", "", [""]], ["_moves", [], [[]]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };
private _veh = missionNamespace getVariable ["AP_trunk_vehicle", objNull];

switch (toLower _verb) do {

case "data": {
    if (isNull _veh || {!alive _veh}) exitWith { createHashMapFromArray [["gone", true], ["why", "no vehicle"]] };
    private _isHouse = _veh isKindOf "House_F";
    (_veh getVariable ["AP_vinv", [[], 0]]) params [["_tItems", []], ["_tWeight", 0]];
    private _trunk = _tItems apply { createHashMapFromArray [
        ["id", _x select 0],
        ["name", ["getName", _x select 0] call AP_fnc_virtItemCfg],
        ["qty", _x select 1],
        ["w", ["getItemWeight", _x select 0] call AP_fnc_virtItemCfg]
    ] };
    private _mine = [];
    {
        private _q = missionNamespace getVariable [format ["AP_inv_%1", _x], 0];
        if (_q isEqualType 0 && {_q > 0}) then {
            _mine pushBack (createHashMapFromArray [
                ["id", _x], ["name", ["getName", _x] call AP_fnc_virtItemCfg],
                ["qty", _q], ["w", ["getItemWeight", _x] call AP_fnc_virtItemCfg]
            ]);
        };
    } forEach ([2] call AP_fnc_virtItemCfg);
    // HOUSES (needstest): the physical wing rides too -- the native dialog served
    // it for houses (only VEHICLES are barred from physical via this method).
    private _phys = [];
    private _pyW = 0; private _pyMax = 0;
    if (_isHouse) then {
        (_veh getVariable ["AP_pinv", [[], 0]]) params [["_pItems", []], ["_pW", 0]];
        _pyW = _pW;
        _pyMax = _veh getVariable ["AP_phys_cap", 100];
        _phys = _pItems apply { createHashMapFromArray [
            ["id", _x select 0],
            ["name", ([_x select 0] call AP_fnc_fetchCfgDetails) param [1, _x select 0]],
            ["qty", _x select 1]
        ] };
    };
    private _tMax = ([_veh, true] call AP_fnc_vehicleWeight) param [0, 0];
    createHashMapFromArray [
        ["veh", if (_isHouse) then { format ["House Storage - %1", getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName")] }
                else { getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName") }],
        ["house", _isHouse],
        ["trunk", _trunk], ["tW", _tWeight], ["tMax", _tMax],
        ["phys", _phys], ["pyW", _pyW], ["pyMax", _pyMax],
        ["mine", _mine],
        ["pW", missionNamespace getVariable ["AP_carryWeight", 0]],
        ["pMax", missionNamespace getVariable ["AP_maxWeight", 0]]
    ]
};

case "batch": {
    if (isNull _veh || {!alive _veh}) exitWith { ["The vehicle is gone."] call _no };
    if !(missionNamespace getVariable ["AP_trunkDeckOpen", false]) exitWith { ["The trunk session ended -- reopen it."] call _no };
    if (_moves isEqualTo []) exitWith { ["Nothing queued."] call _no };
    if (count _moves > 24) exitWith { ["Too many moves in one batch."] call _no };
    private _done = 0;
    {
        _x params [["_dir", "", [""]], ["_item", "", [""]], ["_qty", 0, [0]], ["_virt", true, [true]]];
        // physical moves are HOUSES only -- the native rule
        // (fn_refreshInventory:3) bars vehicles from physical via this method
        if (!_virt && {!(_veh isKindOf "House_F")}) then { _virt = true; };
        if (_item isNotEqualTo "" && {_qty > 0} && {_qty <= 10000}) then {
            AP_is_virtual = _virt;   // the natives read this global, same as the dialog toggle
            // The natives' PHYSICAL branches take their quantity ceiling from TrunkMenu's
            // listbox (lbValue[4502/4503]). There is no dialog 4500 behind the deck, so that
            // read returned 0, the clamp set the quantity to 0, and `for "_i" from 1 to 0` ran
            // zero iterations -- every physical move from this app was a silent no-op. Pass the
            // ceiling explicitly (2026-09-05); -1 is "not supplied", which is what the virtual
            // branches want since they never consult it.
            private _max = -1;
            if (!_virt) then {
                _max = if (_dir isEqualTo "take") then {
                    private _pinv = (_veh getVariable ["AP_pinv", [[], 0]]) param [0, []];
                    private _pi = _pinv findIf { (_x param [0, ""]) isEqualTo _item };
                    if (_pi < 0) then { 0 } else { (_pinv select _pi) param [1, 0] }
                } else {
                    private _t = call AP_fnc_physTally;
                    private _ti = _t findIf { (_x param [0, ""]) isEqualTo _item };
                    if (_ti < 0) then { 0 } else { (_t select _ti) param [1, 0] }
                };
            };
            // qty travels as the STRING the natives expect from ctrlText
            if (_dir isEqualTo "take") then {
                [_item, str _qty, _max] call AP_fnc_takeInventory;
            } else {
                [_item, str _qty, _max] call AP_fnc_storeInventory;
            };
            _done = _done + 1;
        };
    } forEach _moves;
    AP_is_virtual = true;
    // one refresh for the whole batch -- the parametrized natives each called
    // AP_fnc_refreshInventory themselves, which already pushes the deck channel,
    // so the last one has repainted us; this is the belt to those braces.
    [_veh, true] call AP_fnc_refreshInventory;
    [format ["%1 move(s) committed.", _done]] call _yes
};

// the page left the trunk view: drop the session flag so the watchdog in
// fn_openInventory releases AP_activeTrunk on its next tick
case "left": {
    AP_trunkDeckOpen = false;
    ["closed"] call _yes
};

default { ["unknown trunk verb"] call _no };
};
